"""Thin launcher for the compiled cronjob."""
import importlib.util
from pathlib import Path


def _impl():
    folder = Path(__file__).resolve().parent
    matches = sorted(folder.glob("cronjob_impl*.so"))
    if not matches:
        raise SystemExit("compiled cronjob is missing")
    spec = importlib.util.spec_from_file_location("cronjob_impl", matches[0])
    if spec is None or spec.loader is None:
        raise SystemExit("compiled cronjob could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    _impl().run()
