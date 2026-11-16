#!/usr/bin/env python3
"""Check deployment prerequisites without installing software or running models."""
import argparse
import http.client
import json
import math
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ("make -C vendor/qcheck -f Makefile.nj -B "
             "src/QCheckVersion.sml src/GENERATOR_SIG-nj.sml")
GENERATED = ("src/QCheckVersion.sml", "src/GENERATOR_SIG-nj.sml", "src/RandGen-nj.sml")
API_KEYS = {"openai": "OPENAI_API_KEY", "deepseek": "DEEPSEEK_API_KEY"}


class Report:
    def __init__(self):
        self.failures = 0

    def add(self, status, name, detail, fix=None):
        self.failures += status == "FAIL"
        print(f"[{status}] {name}: {detail}", flush=True)
        if fix:
            print(f"       Fix (from repository root): {fix}", flush=True)


def command(args, *, cwd=ROOT, timeout=30, input=None):
    return subprocess.run(args, cwd=cwd, input=input, text=True, errors="replace",
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)


def check_tools(report, timeout):
    available = {}
    for name, args in (("git", ["--version"]), ("make", ["--version"]),
                       ("perl", ["-e", "print $^V"]), ("sml", None)):
        path = shutil.which(name)
        available[name] = bool(path)
        if not path:
            report.add("FAIL", name, "not on PATH", f"Install {name}; see README.md.")
        elif args is None:
            report.add("PASS", name, path)
        else:
            try:
                result = command([path, *args], timeout=timeout)
                available[name] = result.returncode == 0
                lines = result.stdout.strip().splitlines()
                report.add("PASS" if available[name] else "FAIL", name,
                           (lines[0] if lines else path) + f" (exit {result.returncode})")
            except (OSError, subprocess.TimeoutExpired) as exc:
                available[name] = False
                report.add("FAIL", name, str(exc))
    return available


def check_sources(report, config):
    manifest = ROOT / config["manifest"]
    cases = json.loads(manifest.read_text(encoding="utf-8"))["cases"]
    required = [ROOT / "tasks/contracts.json", ROOT / "interfaces/index.json",
                ROOT / "prompts/translate.txt", ROOT / "prompts/repair.txt"]
    required.extend(manifest.parent / case["source"] for case in cases)
    homework = set()
    for cm in (ROOT / "tasks").rglob("*.cm"):
        if ".cm" in cm.relative_to(ROOT).parts:
            continue
        for name in re.findall(r"(?m)^\s*(\S*15150HW/\S+)\s*$", cm.read_text(encoding="utf-8")):
            homework.add((cm.parent / name).resolve())
    required.extend(homework)
    missing = [str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)
               for path in required if not path.is_file()]
    if not (ROOT / "15150HW").is_dir():
        missing.append("15150HW/")
    report.add("FAIL" if missing else "PASS", "Project sources",
               "missing: " + ", ".join(missing) if missing else
               f"{len(cases)} manifest entries; {len(homework)} homework CM dependencies present",
               "Restore the missing tracked files from Git." if missing else None)


def check_qcheck(report, tools, timeout):
    folder = ROOT / "vendor/qcheck"
    if not (folder / "qcheck.cm").is_file():
        report.add("FAIL", "QCheck", "submodule sources missing",
                   "git submodule update --init --recursive")
        return False
    if tools["git"]:
        try:
            entry = command(["git", "ls-files", "--stage", "--", "vendor/qcheck"],
                            timeout=timeout).stdout.split()
            head = command(["git", "-C", str(folder), "rev-parse", "HEAD"], timeout=timeout)
            if len(entry) >= 2 and entry[0] == "160000" and head.returncode == 0:
                matches = head.stdout.strip() == entry[1]
                report.add("PASS" if matches else "FAIL", "QCheck revision",
                           head.stdout.strip() + (" (matches gitlink)" if matches else " (differs from gitlink)"),
                           None if matches else "git submodule update --init --recursive")
            else:
                report.add("WARN", "QCheck revision", "Git pin could not be verified in this source copy")
        except (OSError, subprocess.TimeoutExpired) as exc:
            report.add("FAIL", "QCheck revision", str(exc))
    missing = [name for name in GENERATED if not (folder / name).is_file()]
    report.add("FAIL" if missing else "PASS", "QCheck generated files",
               ", ".join(missing) + " missing" if missing else "present",
               BOOTSTRAP if missing else None)
    return not missing


def check_sml(report, qcheck_ready, timeout):
    """Compile in a disposable copy, so the checkout keeps its original caches."""
    with tempfile.TemporaryDirectory(prefix="sml-environment-") as directory:
        temporary = Path(directory)
        program = ('val basis = CM.make "$/basis.cm" andalso CM.make "$/smlnj-lib.cm";\n'
                   'val _ = if basis then print "\\nENV_BASIS_OK\\n" '
                   'else OS.Process.exit OS.Process.failure;\n')
        if qcheck_ready:
            shutil.copytree(ROOT / "vendor/qcheck", temporary / "qcheck",
                            ignore=shutil.ignore_patterns(".git", ".cm", "__pycache__"))
            # Check the installed generated SML, including architecture compatibility.
            # Disable regeneration only in this disposable CM file, so make cannot
            # repair a stale adapter and hide a problem in the real checkout.
            cm = temporary / "qcheck/qcheck.cm"
            text = cm.read_text(encoding="utf-8")
            for name in GENERATED:
                text = re.sub(re.escape(name) + r"\s+: make[^\n]*", name, text)
            cm.write_text(text, encoding="utf-8")
            program += ('val qcheck = CM.make "qcheck/qcheck.cm";\n'
                        'val _ = if qcheck then print "\\nENV_QCHECK_OK\\n" '
                        'else OS.Process.exit OS.Process.failure;\n')
        program += 'val _ = OS.Process.exit OS.Process.success;\n'
        try:
            result = command(["sml"], cwd=temporary, input=program, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            report.add("FAIL", "SML compilation", str(exc), "Check sml, or increase --timeout.")
            return
        lines = result.stdout.splitlines()
        banner = next((line for line in lines if "Standard ML of New Jersey" in line), "SML/NJ banner missing")
        basis_ok = "ENV_BASIS_OK" in lines and "Standard ML of New Jersey" in banner
        report.add("PASS" if basis_ok else "FAIL", "SML/NJ + Basis + smlnj-lib", banner)
        qcheck_ok = "ENV_QCHECK_OK" in lines and result.returncode == 0
        if qcheck_ready:
            report.add("PASS" if qcheck_ok else "FAIL", "QCheck compilation",
                       "compiled in temporary copy" if qcheck_ok else "compilation failed", BOOTSTRAP if not qcheck_ok else None)
        else:
            report.add("SKIP", "QCheck compilation", "restore/generate QCheck files first")
        if not basis_ok or (qcheck_ready and not qcheck_ok):
            print("\n".join("       " + line for line in lines[-30:]))


def select_models(config, args):
    configured = config.get("models", {})
    if args.offline:
        return []
    if args.all_local_models:
        selected = [(label, item) for label, item in configured.items()
                    if item.get("provider", "ollama") == "ollama"]
        if not selected:
            raise ValueError("No Ollama models configured in models")
        return selected
    if args.model:
        return [(label, configured[label]) for label in dict.fromkeys(args.model)]
    return [("default", {"name": config["model"], "provider": config.get("provider", "ollama")})]


def get_json(url, timeout):
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.load(response)


def check_models(report, config, selected, timeout):
    local = []
    for label, item in selected:
        provider = item.get("provider", "ollama")
        name = item["name"]
        if not isinstance(name, str) or not name.strip():
            raise ValueError(f"Invalid model name for {label}")
        if provider == "ollama":
            local.append((label, name))
        elif provider in API_KEYS:
            key = API_KEYS[provider]
            present = bool(os.environ.get(key, "").strip())
            report.add("PASS" if present else "FAIL", label,
                       f"{key} configured; access not tested" if present else f"{key} missing",
                       None if present else f"Set {key} in your shell environment.")
        else:
            report.add("FAIL", label, f"unknown provider: {provider}")
    if not local:
        report.add("SKIP", "Ollama", "no local model selected")
        return
    cli = shutil.which("ollama")
    report.add("PASS" if cli else "WARN", "Ollama CLI",
               cli or "not on PATH; the configured HTTP server can still be used")
    url = config["ollama_url"].rstrip("/")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("ollama_url must be an HTTP(S) URL without embedded credentials")
    try:
        version = get_json(url + "/api/version", timeout)
        tags = get_json(url + "/api/tags", timeout)
        if not isinstance(version.get("version"), str) or not version["version"]:
            raise ValueError("missing server version")
        if not isinstance(tags.get("models"), list):
            raise ValueError("missing models list")
        names = {item["name"] for item in tags["models"]}
        if any(not isinstance(name, str) for name in names):
            raise ValueError("invalid model name in server response")
    except (OSError, ValueError, KeyError, TypeError, AttributeError,
            urllib.error.URLError, http.client.HTTPException) as exc:
        report.add("FAIL", "Ollama API", f"{url}: {exc}",
                   "Start Ollama (ollama serve or the app), or correct config.json ollama_url.")
        return
    report.add("PASS", "Ollama API", f"{url}; version {version['version']}")
    for label, name in local:
        # Ollama omits ':latest' in user requests but returns it in the inventory.
        canonical = name if ":" in name.rsplit("/", 1)[-1] else name + ":latest"
        present = name in names or canonical in names
        report.add("PASS" if present else "FAIL", f"Model {label}",
                   name + (" installed" if present else " missing"),
                   None if present else f"On the Ollama server, run: ollama pull {shlex.quote(name)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--offline", action="store_true", help="skip all model/server/key checks")
    selection.add_argument("--model", action="append", help="configured model label; repeat to select models")
    selection.add_argument("--all-local-models", action="store_true", help="check all configured Ollama models")
    parser.add_argument("--timeout", type=float, default=60, help="compiler/tool timeout in seconds (default: 60)")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be a positive finite number")
    report = Report()
    print(f"Environment check: {platform.system()} {platform.machine()} | {ROOT}")
    if sys.version_info < (3, 10):
        report.add("FAIL", "Python", platform.python_version(), "Install Python 3.10 or newer (supported baseline).")
        return 1
    report.add("PASS", "Python", f"{platform.python_version()} ({sys.executable}); standard library only")
    report.add("PASS" if platform.system() in ("Linux", "Darwin") else "FAIL", "Platform",
               platform.platform(), "On Windows, run inside WSL2." if platform.system() == "Windows" else None)
    tools = check_tools(report, args.timeout)
    try:
        config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
        selected = select_models(config, args)
        check_sources(report, config)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        report.add("FAIL", "Configuration/sources", str(exc), "Check config.json, selected labels and tracked files.")
        config, selected = None, []
    try:
        ready = check_qcheck(report, tools, args.timeout)
        if tools["sml"]:
            check_sml(report, ready, args.timeout)
        else:
            report.add("SKIP", "SML compilation", "install SML/NJ first")
    except OSError as exc:
        report.add("FAIL", "QCheck/SML files", str(exc))
    if config is not None:
        try:
            check_models(report, config, selected, min(args.timeout, 5))
        except (ValueError, KeyError, TypeError, AttributeError) as exc:
            report.add("FAIL", "Model configuration", str(exc))
    print(f"\n{report.failures} failed check(s). No installs, downloads, or model inference performed.")
    print("Model inventory checks do not verify GPU use, memory capacity, or generation/API access.")
    return 1 if report.failures else 0


if __name__ == "__main__":
    sys.exit(main())
