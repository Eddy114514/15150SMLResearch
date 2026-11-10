#!/usr/bin/env python3
"""Package the current working files and selected Ollama models for Colab."""
import argparse
import json
from pathlib import Path
import shutil
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = "15150SMLResearch"
SOURCE_DIRS = ("15150HW", "benchmark", "docs", "interfaces", "prompts", "sequence",
               "sml", "tasks", "tests", "vendor")
EXCLUDED_DIRS = {".git", ".cm", "__pycache__", ".ipynb_checkpoints", "prepared"}


def source_files():
    """Include working sources and dependencies, without generated run artifacts."""
    yield from sorted(ROOT.glob("*.py"))
    for name in ("config.json", "README.md", ".gitignore", ".gitmodules",
                 "setup/colab.ipynb", "setup/export_colab.py"):
        yield ROOT / name
    for name in SOURCE_DIRS:
        for path in sorted((ROOT / name).rglob("*")):
            relative = path.relative_to(ROOT)
            if EXCLUDED_DIRS.intersection(relative.parts) or path.is_symlink():
                continue
            if path.is_file() and path.suffix not in {".pyc", ".log"}:
                yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="new output directory")
    parser.add_argument("--model", action="append", dest="models",
                        help="configured Ollama label; repeat to select models (default: all Ollama entries)")
    parser.add_argument("--ollama-version", default="0.34.2", help="official Ollama release (default: 0.34.2)")
    args = parser.parse_args()
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    configured = config["benchmark"]["models"]
    labels = args.models or [label for label, item in configured.items()
                            if item.get("provider", "ollama") == "ollama"]
    models = {label: configured[label] for label in labels}
    output = args.output.resolve()
    output.mkdir(parents=True)
    archive_name = WORKSPACE + "-colab.tar.gz"
    settings = {
        "models": models,
        "ollama_version": args.ollama_version,
        "ollama_release_url": ("https://github.com/ollama/ollama/releases/download/v"
                               + args.ollama_version + "/ollama-linux-amd64.tar.zst"),
    }
    with tempfile.TemporaryDirectory(prefix="colab-export-") as temporary:
        staging = Path(temporary) / WORKSPACE
        for path in source_files():
            destination = staging / path.relative_to(ROOT)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
        (staging / "colab.json").write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
        with tarfile.open(output / archive_name, "w:gz") as archive:
            archive.add(staging, arcname=WORKSPACE)
        shutil.copyfile(staging / "setup/colab.ipynb", output / "colab.ipynb")
        shutil.copyfile(staging / "docs/COLAB.md", output / "README.md")
    print(json.dumps({"archive": str(output / archive_name),
                      "notebook": str(output / "colab.ipynb"), "models": list(models)}, indent=2))


if __name__ == "__main__":
    main()
