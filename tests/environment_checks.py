"""Exercise the environment doctor without real compilers or model requests."""
import argparse
from contextlib import contextmanager, redirect_stdout
import http.server
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "setup"))
import check_environment as doctor


class RecordingReport:
    def __init__(self):
        self.failures = 0
        self.items = []

    def add(self, status, name, detail, fix=None):
        self.failures += status == "FAIL"
        self.items.append((status, name, detail, fix))


def selection(**overrides):
    options = dict(offline=False, all_local_models=False, model=None)
    options.update(overrides)
    return argparse.Namespace(**options)


@contextmanager
def ollama_fixture(routes):
    requests = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append((self.command, self.path))
            body, truncated = routes[self.path]
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body) + (20 if truncated else 0)))
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
            self.close_connection = True

        def log_message(self, *_args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}", requests
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


class SelectionChecks(unittest.TestCase):
    def setUp(self):
        self.config = {
            "model": "root-default:q4",
            "benchmark": {"models": {
                "local": {"name": "installed:q8"},
                "api": {"name": "remote", "provider": "openai"},
            }},
        }

    def test_default_uses_root_model_without_requiring_all_benchmark_models(self):
        self.assertEqual(doctor.select_models(self.config, selection()),
                         [("default", {"name": "root-default:q4", "provider": "ollama"})])

    def test_explicit_labels_deduplicate_and_all_local_excludes_api(self):
        self.assertEqual([label for label, _ in doctor.select_models(
            self.config, selection(model=["api", "local", "api"]))], ["api", "local"])
        self.assertEqual([label for label, _ in doctor.select_models(
            self.config, selection(all_local_models=True))], ["local"])

    def test_unknown_label_is_not_silently_treated_as_a_model_name(self):
        with self.assertRaises(KeyError):
            doctor.select_models(self.config, selection(model=["typo"]))

    def test_offline_skips_model_selection(self):
        self.assertEqual(doctor.select_models({}, selection(offline=True)), [])

    @unittest.skipUnless(Path("/bin/bash").is_file(), "requires a Unix shell")
    def test_shell_launcher_reports_missing_python(self):
        result = subprocess.run(["/bin/bash", str(ROOT / "setup/check_environment.sh")],
                                env={"PATH": ""}, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1)
        self.assertIn("[FAIL] Python: python3 is not on PATH", result.stderr)

    def test_offline_main_never_contacts_server_or_requires_api_keys(self):
        report_config = dict(self.config, manifest="tasks/manifest.json")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "config.json").write_text(json.dumps(report_config), encoding="utf-8")
            with patch.object(doctor, "ROOT", root), \
                    patch.object(sys, "argv", ["check_environment.py", "--offline"]), \
                    patch.object(doctor.platform, "system", return_value="Linux"), \
                    patch.object(doctor, "check_tools", return_value={"sml": True, "git": True}), \
                    patch.object(doctor, "check_sources"), \
                    patch.object(doctor, "check_qcheck", return_value=True), \
                    patch.object(doctor, "check_sml"), \
                    patch.object(doctor, "get_json", side_effect=AssertionError("unexpected network")) as request, \
                    patch.dict(os.environ, {}, clear=True), redirect_stdout(io.StringIO()):
                self.assertEqual(doctor.main(), 0)
                request.assert_not_called()


class CompilerChecks(unittest.TestCase):
    def test_missing_generated_qcheck_files_fail_without_running_make(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "vendor/qcheck"
            folder.mkdir(parents=True)
            (folder / "qcheck.cm").write_text("Library is\n", encoding="utf-8")
            report = RecordingReport()
            with patch.object(doctor, "ROOT", root), patch.object(doctor, "command") as execute:
                self.assertFalse(doctor.check_qcheck(report, {"git": False}, 1))
            execute.assert_not_called()
            self.assertEqual(report.failures, 1)
            for generated in doctor.GENERATED:
                self.assertIn(generated, report.items[-1][2])
            self.assertEqual(report.items[-1][3], doctor.BOOTSTRAP)

    def test_sml_zero_exit_without_success_marker_is_failure(self):
        report = RecordingReport()
        result = subprocess.CompletedProcess(["sml"], 0,
            "Standard ML of New Jersey v110.79\nError: unbound structure CM\n")
        with patch.object(doctor, "command", return_value=result), redirect_stdout(io.StringIO()):
            doctor.check_sml(report, False, 1)
        self.assertEqual(report.failures, 1)
        self.assertIn(("SKIP", "QCheck compilation"), [(s, n) for s, n, _, _ in report.items])

    def test_qcheck_smoke_is_disposable_and_nonzero_exit_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "vendor/qcheck"
            (folder / "src").mkdir(parents=True)
            original = "Library is\n" + "".join(name + " : make (-f Makefile.nj)\n"
                                                       for name in doctor.GENERATED)
            (folder / "qcheck.cm").write_text(original, encoding="utf-8")
            for name in doctor.GENERATED:
                (folder / name).write_text("(* unchanged SML *)\n", encoding="utf-8")

            def fake_sml(_args, *, cwd, input, timeout):
                self.assertNotEqual(cwd, root)
                temporary_cm = (cwd / "qcheck/qcheck.cm").read_text(encoding="utf-8")
                self.assertNotIn(": make", temporary_cm)
                for name in doctor.GENERATED:
                    self.assertEqual((cwd / "qcheck" / name).read_text(), "(* unchanged SML *)\n")
                return subprocess.CompletedProcess(["sml"], 1,
                    "Standard ML of New Jersey v110.79\nENV_BASIS_OK\nENV_QCHECK_OK\n")

            report = RecordingReport()
            with patch.object(doctor, "ROOT", root), \
                    patch.object(doctor, "command", side_effect=fake_sml), redirect_stdout(io.StringIO()):
                doctor.check_sml(report, True, 1)
            self.assertGreater(report.failures, 0)
            self.assertEqual((folder / "qcheck.cm").read_text(), original)


class ModelChecks(unittest.TestCase):
    selected = [("local", {"name": "tiny"})]

    def run_check(self, url="http://127.0.0.1:11434", selected=None):
        report = RecordingReport()
        doctor.check_models(report, {"ollama_url": url},
                            self.selected if selected is None else selected, 1)
        return report

    def test_missing_cli_is_optional_when_inventory_contains_model(self):
        with ollama_fixture({
                "/api/version": (b'{"version":"test"}', False),
                "/api/tags": (b'{"models":[{"name":"tiny:latest"}]}', False),
        }) as (url, requests), patch.object(doctor.shutil, "which", return_value=None):
            report = self.run_check(url)
        self.assertEqual(report.failures, 0)
        self.assertIn(("WARN", "Ollama CLI"), [(s, n) for s, n, _, _ in report.items])
        self.assertEqual(requests, [("GET", "/api/version"), ("GET", "/api/tags")])

    def test_missing_model_fails_even_when_cli_and_server_exist(self):
        with patch.object(doctor.shutil, "which", return_value="/usr/bin/ollama"), \
                patch.object(doctor, "get_json", side_effect=[{"version": "test"}, {"models": []}]):
            report = self.run_check()
        self.assertEqual(report.failures, 1)
        self.assertEqual(report.items[-1][0:2], ("FAIL", "Model local"))

    def test_unreachable_server_is_a_reported_failure(self):
        with patch.object(doctor.shutil, "which", return_value=None), \
                patch.object(doctor, "get_json", side_effect=urllib.error.URLError("connection refused")):
            report = self.run_check()
        self.assertEqual(report.failures, 1)
        self.assertEqual(report.items[-1][0:2], ("FAIL", "Ollama API"))

    def test_invalid_response_shapes_fail(self):
        for version, tags in [([], {}), ({"version": "test"}, []),
                              ({"version": "test"}, {"models": [{}]}),
                              ({"version": "test"}, {"models": [{"name": []}]})]:
            with self.subTest(version=version, tags=tags), \
                    patch.object(doctor.shutil, "which", return_value=None), \
                    patch.object(doctor, "get_json", side_effect=[version, tags]):
                self.assertEqual(self.run_check().failures, 1)

    def test_malformed_json_is_a_reported_failure(self):
        with ollama_fixture({"/api/version": (b"not json", False)}) as (url, _), \
                patch.object(doctor.shutil, "which", return_value=None):
            report = self.run_check(url)
        self.assertEqual(report.failures, 1)
        self.assertEqual(report.items[-1][0:2], ("FAIL", "Ollama API"))

    def test_truncated_http_body_is_a_reported_failure(self):
        with ollama_fixture({"/api/version": (b'{"version":"test"}', True)}) as (url, _), \
                patch.object(doctor.shutil, "which", return_value=None):
            report = self.run_check(url)
        self.assertEqual(report.failures, 1)
        self.assertEqual(report.items[-1][0:2], ("FAIL", "Ollama API"))

    def test_api_key_presence_does_not_contact_provider_or_expose_key(self):
        secret = "test-secret-must-stay-hidden"
        with patch.dict(os.environ, {"OPENAI_API_KEY": secret}, clear=True), \
                patch.object(doctor, "get_json", side_effect=AssertionError("unexpected network")) as request:
            report = self.run_check(selected=[("api", {"provider": "openai", "name": "remote"})])
        self.assertEqual(report.failures, 0)
        self.assertNotIn(secret, repr(report.items))
        self.assertIn("access not tested", report.items[0][2])
        request.assert_not_called()

    def test_missing_api_key_and_unknown_provider_fail_without_network(self):
        with patch.dict(os.environ, {}, clear=True), \
                patch.object(doctor, "get_json", side_effect=AssertionError("unexpected network")) as request:
            report = self.run_check(selected=[
                ("api", {"provider": "openai", "name": "remote"}),
                ("invalid", {"provider": "not-a-provider", "name": "remote"}),
            ])
        self.assertEqual(report.failures, 2)
        request.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
