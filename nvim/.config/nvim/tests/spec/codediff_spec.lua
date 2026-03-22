local h = require "tests.helpers.codediff"

local original_cwd
local repo
local echo_capture

local function create_two_modified_files_repo()
  repo = h.create_temp_git_repo()
  repo.write_file("alpha.lua", { "return 'alpha'" })
  repo.write_file("beta.lua", { "return 'beta'" })
  repo.git_ok({ "add", "." })
  repo.git_ok({ "commit", "-m", "initial" })
  repo.write_file("alpha.lua", { "return 'alpha modified'" })
  repo.write_file("beta.lua", { "return 'beta modified'" })
  return repo
end

local function create_two_staged_files_repo()
  repo = create_two_modified_files_repo()
  repo.git_ok({ "add", "alpha.lua", "beta.lua" })
  return repo
end

describe("local CodeDiff workflow", function()
  before_each(function()
    original_cwd = vim.fn.getcwd()
    h.reset_editor()
    echo_capture = h.capture_echoes()
  end)

  after_each(function()
    if echo_capture then
      echo_capture.restore()
      echo_capture = nil
    end

    vim.fn.chdir(original_cwd)
    h.reset_editor()
    vim.wait(200)

    if repo then
      repo.cleanup()
      repo = nil
    end
  end)

  it("stages from hidden diff buffers and reopens with refreshed explorer state", function()
    local actions = require "plugins.git.codediff.actions"

    repo = create_two_modified_files_repo()
    local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

    h.wait_for(function()
      return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "unstaged"
    end, 10000, "CodeDiff did not select alpha.lua in the unstaged group")

    h.set_explorer_hidden(tabpage, true)
    h.focus_modified_window(tabpage)
    actions.stage_entry(h.get_codediff_lifecycle, tabpage)

    h.wait_for(function()
      local status_result = explorer.status_result
      return explorer.current_file_path == "beta.lua"
        and explorer.current_file_group == "unstaged"
        and h.status_has_path(status_result, "staged", "alpha.lua")
        and not h.status_has_path(status_result, "unstaged", "alpha.lua")
        and h.status_has_path(status_result, "unstaged", "beta.lua")
    end, 15000, "Hidden stage_entry did not refresh CodeDiff state")

    h.set_explorer_hidden(tabpage, false)

    assert.is_not_nil(h.find_tree_entry(explorer, "alpha.lua", "staged"))
    assert.is_nil(h.find_tree_entry(explorer, "alpha.lua", "unstaged"))
    assert.is_not_nil(h.find_tree_entry(explorer, "beta.lua", "unstaged"))
  end)

  it("unstages from hidden diff buffers and reopens with refreshed explorer state", function()
    local actions = require "plugins.git.codediff.actions"

    repo = create_two_staged_files_repo()
    local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

    h.wait_for(function()
      return explorer.current_file_path == "alpha.lua" and explorer.current_file_group == "staged"
    end, 10000, "CodeDiff did not select alpha.lua in the staged group")

    h.set_explorer_hidden(tabpage, true)
    h.focus_modified_window(tabpage)
    actions.unstage_entry(h.get_codediff_lifecycle, tabpage)

    h.wait_for(function()
      local status_result = explorer.status_result
      return explorer.current_file_path == "beta.lua"
        and explorer.current_file_group == "staged"
        and h.status_has_path(status_result, "unstaged", "alpha.lua")
        and not h.status_has_path(status_result, "staged", "alpha.lua")
        and h.status_has_path(status_result, "staged", "beta.lua")
    end, 15000, "Hidden unstage_entry did not refresh CodeDiff state")

    h.set_explorer_hidden(tabpage, false)

    assert.is_not_nil(h.find_tree_entry(explorer, "alpha.lua", "unstaged"))
    assert.is_nil(h.find_tree_entry(explorer, "alpha.lua", "staged"))
    assert.is_not_nil(h.find_tree_entry(explorer, "beta.lua", "staged"))
  end)

  it("echoes the current CodeDiff file position during navigation", function()
    repo = create_two_modified_files_repo()

    local tabpage, _, explorer = h.open_status_explorer(repo, "alpha.lua", { hide_untracked = true })

    h.wait_for(function()
      return require("plugins.git.codediff.view").get_file_position(tabpage) == "1/2"
    end, 10000, "Initial CodeDiff file position was not available")

    h.wait_for(function()
      return echo_capture.contains("1/2 files")
    end, 10000, "Initial CodeDiff file position message was not echoed")

    assert.is_true(require("codediff").next_file())

    h.wait_for(function()
      return explorer.current_file_path == "beta.lua" and explorer.current_file_group == "unstaged"
    end, 10000, "CodeDiff did not navigate to beta.lua")

    h.wait_for(function()
      return echo_capture.contains("2/2 files")
    end, 10000, "Updated CodeDiff file position message was not echoed")
  end)
end)
