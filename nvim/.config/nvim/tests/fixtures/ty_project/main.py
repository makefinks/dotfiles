from pathlib import Path


def collect_paths(root: Path) -> list[str]:
    return [str(path) for path in root.iterdir()]
