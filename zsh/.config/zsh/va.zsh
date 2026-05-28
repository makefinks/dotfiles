va() {
  emulate -L zsh
  setopt pipefail

  if ! command -v fzf >/dev/null 2>&1; then
    print -u2 "va: fzf is required"
    return 1
  fi

  local search_root current_dir dir name candidate venv_path selected selected_row label active_marker python_version package_count site_packages sort_key relative_path parent_dir display_row
  local -a venv_names raw_candidates candidates rows
  local -A seen

  venv_names=(.venv venv .env env)
  current_dir="${PWD:A}"
  search_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  [[ -n "$search_root" ]] || search_root="$current_dir"
  search_root="${search_root:A}"

  dir="$current_dir"
  while true; do
    for name in "${venv_names[@]}"; do
      raw_candidates+=("$dir/$name")
    done

    [[ "$dir" == / ]] && break
    dir="${dir:h}"
  done

  if command -v fd >/dev/null 2>&1; then
    while IFS= read -r candidate; do
      raw_candidates+=("$candidate")
    done < <(fd -H -t d --max-depth 5 '^(\.venv|venv|\.env|env)$' "$search_root" 2>/dev/null)
  else
    while IFS= read -r candidate; do
      raw_candidates+=("$candidate")
    done < <(find "$search_root" -maxdepth 5 -type d \( -name .venv -o -name venv -o -name .env -o -name env \) 2>/dev/null)
  fi

  for candidate in "${raw_candidates[@]}"; do
    venv_path="${candidate:A}"

    [[ -f "$venv_path/bin/activate" ]] || continue
    [[ -z "${seen[$venv_path]}" ]] || continue

    candidates+=("$venv_path")
    seen[$venv_path]=1
  done

  if (( ${#candidates[@]} == 0 )); then
    print -u2 "va: no virtualenvs found near $current_dir"
    return 1
  fi

  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == "$current_dir"/* ]]; then
      label="./${candidate#$current_dir/}"
    elif [[ "$candidate" == "$search_root"/* ]]; then
      label="${candidate#$search_root/}"
    else
      label="$candidate"
    fi

    active_marker=""
    [[ -n "$VIRTUAL_ENV" && "${VIRTUAL_ENV:A}" == "$candidate" ]] && active_marker="[active]"

    python_version="$("$candidate/bin/python" --version 2>/dev/null)"
    python_version="${python_version#Python }"
    python_version="${python_version%% *}"
    [[ -n "$python_version" ]] || python_version="unknown"

    package_count="-"
    site_packages="$("$candidate/bin/python" -c 'import site; paths = site.getsitepackages(); print(paths[0] if paths else "")' 2>/dev/null)"
    if [[ -n "$site_packages" && -d "$site_packages" ]]; then
      package_count="$(find "$site_packages" -maxdepth 1 \( -name "*.dist-info" -o -name "*.egg-info" \) | wc -l | tr -d " ")"
    fi

    parent_dir="${candidate:h}"
    if [[ "$current_dir" == "$parent_dir" || "$current_dir" == "$parent_dir"/* ]]; then
      relative_path="${current_dir#$parent_dir}"
      sort_key="$(printf '0-%08d-%s' ${#relative_path} "$label")"
    elif [[ "$candidate" == "$current_dir" || "$candidate" == "$current_dir"/* ]]; then
      relative_path="${candidate#$current_dir}"
      sort_key="$(printf '1-%08d-%s' ${#relative_path} "$label")"
    elif [[ "$candidate" == "$search_root"/* ]]; then
      relative_path="${candidate#$search_root/}"
      sort_key="$(printf '2-%08d-%s' ${#relative_path} "$label")"
    else
      sort_key="$(printf '3-%08d-%s' ${#candidate} "$label")"
    fi

    display_row="$(printf '%-56s  %-18s  %4s pkgs  %s' "$label" "$python_version" "$package_count" "$active_marker")"
    rows+=("$sort_key"$'\t'"$display_row"$'\t'"$candidate")
  done

  selected_row="$(printf '%s\n' "${rows[@]}" | sort -t $'\t' -k1,1 | fzf \
    --prompt='venv> ' \
    --height=40% \
    --layout=reverse \
    --delimiter=$'\t' \
    --with-nth=2 \
    --preview='venv_path=$(printf "%s" {} | cut -f3); printf "%s\n\n" "$venv_path"; "$venv_path/bin/python" --version 2>/dev/null; site_packages=$("$venv_path/bin/python" -c "import site; paths = site.getsitepackages(); print(paths[0] if paths else \"\")" 2>/dev/null); if [ -n "$site_packages" ] && [ -d "$site_packages" ]; then count=$(find "$site_packages" -maxdepth 1 \( -name "*.dist-info" -o -name "*.egg-info" \) | wc -l | tr -d " "); printf "Packages: %s\n" "$count"; fi; test -f "$venv_path/pyvenv.cfg" && printf "\n" && sed -n "1,80p" "$venv_path/pyvenv.cfg"')"

  [[ -n "$selected_row" ]] || return 1

  selected="${selected_row#*$'\t'}"
  selected="${selected#*$'\t'}"
  selected="${selected%%$'\t'*}"
  source "$selected/bin/activate"
  print "Activated: $selected"
}
