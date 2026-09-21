"""Generate and run the fixed SML contract compiler and QCheck adapter."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent

PREFIX = "@@SMLPBT@@"
_TYPE = {"int": ("Runner.readInt", "Runner.int"),
         "bool": (None, "Runner.bool"),
         "int list": ("Runner.readList", "Runner.list Runner.int"),
         "int * int list": ("Runner.readPair", "Runner.pair")}


def _str(value):
    # SML uses decimal byte escapes, not JSON Unicode escapes.
    return '"' + ''.join(chr(byte) if 32 <= byte < 127 and byte not in (34, 92)
                         else "\\" + str(byte).zfill(3)
                         for byte in str(value).encode("utf-8")) + '"'


def _write(path, content):
    path.write_text(content, encoding="utf-8")
    return path


def log(workdir, phase, diagnostics):
    with (workdir / "log.txt").open("a", encoding="utf-8") as handle:
        handle.write(f"\n=== {phase} ===\n{diagnostics}\n")


def run_sml(program, workdir, timeout, phase):
    """Read the compiler or runner's completion record; only timeouts are results."""
    started = time.monotonic()
    try:
        process = subprocess.run(["sml"], input=program.encode(), capture_output=True,
                                 cwd=ROOT, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        diagnostics = ((exc.stdout or b"") + (exc.stderr or b"")).decode("utf-8", errors="replace")
        log(workdir, phase, diagnostics)
        return {"status": "timeout", "stage": phase, "exception": str(exc),
                "elapsed_seconds": time.monotonic() - started, "diagnostics": diagnostics}
    diagnostics = (process.stdout + process.stderr).decode("utf-8")
    log(workdir, phase, diagnostics)
    if process.returncode:
        print(diagnostics, file=sys.stderr)
        process.check_returncode()
    try:
        result = json.loads(next(line.split(PREFIX, 1)[1]
                                 for line in diagnostics.splitlines() if PREFIX in line))
    except (StopIteration, json.JSONDecodeError):
        print(diagnostics, file=sys.stderr)
        raise
    result.update(elapsed_seconds=time.monotonic() - started, diagnostics=diagnostics)
    return result


def _cm(path, files, exports=None):
    header = "Group is" if exports is None else "Library\n  " + "\n  ".join(exports) + "\nis"
    return _write(path, header + "\n  $/basis.cm\n" +
                  "".join("  " + _str(Path(f).resolve()) + "\n" for f in files))


def compile_contract(case, requires_expr, ensures_expr, workdir, *, attempt, timeout):
    """Fresh CM library: Basis + Spec + generated predicates, never the target."""
    filename = "initial_contract.sml" if attempt == 0 else "repaired_contract.sml"
    input_type, output_type, pattern = case["input_type"], case["output_type"], case["input_pattern"]
    path = _write(workdir / filename,
        f"structure Contract = struct\n  type input = {input_type}\n  type output = {output_type}\n"
        f"  fun requires (input : input) : bool = let val {pattern} = input in ({requires_expr}) end\n"
        f"  fun ensures (input : input) (result : output) : bool = let val {pattern} = input in ({ensures_expr}) end\nend\n")
    cm = _cm(workdir / "predicate.cm", [ROOT / "sml/Spec.sml", path], ["structure Contract"])
    success = '{"status":"compiled","stage":"predicate","compile_ok":true'
    failure = json.dumps({"status": "compile_error", "stage": "predicate", "compile_ok": False})
    program = (
        f'val ok = CM.make {_str(cm)};\n'
        'fun number n = String.translate '
        '(fn #"~" => "-" | c => str c) (Int.toString n);\n'
        f'val message = if ok then {_str(success)} ^ ",\\"min_int\\":" ^ number (valOf Int.minInt) ^ '
        '",\\"max_int\\":" ^ number (valOf Int.maxInt) ^ "}" '
        f'else {_str(failure)};\n'
        f'val _ = print ("\\n" ^ {_str(PREFIX)} ^ message ^ "\\n");\n'
        'val _ = OS.Process.exit OS.Process.success;\n')
    result = run_sml(program, workdir, timeout, "predicate")
    # Only an error reported in the generated file is eligible for model repair.
    if result["status"] == "compile_error" and path.name + ":" not in result["diagnostics"]:
        raise RuntimeError(result["diagnostics"])
    result["contract_path"] = str(path)
    return result


def execute(case, contract_path, source, inputs, workdir, *,
            valid_target, max_attempts, timeout):
    # Valid JSON with one complete input per line for the small SML reader.
    input_path = _write(workdir / "inputs.json", "[\n" + ",\n".join(
        "  " + json.dumps(value, separators=(",", ":")) for value in inputs) + "\n]\n")
    target = _write(workdir / "Target.sml", "structure Target = struct\n" + source +
                    f'\nfun run (input : {case["input_type"]}) : {case["output_type"]} = {case["entrypoint"]} input\nend\n')
    input_read, input_show = _TYPE[case["input_type"]]
    output_show = _TYPE[case["output_type"]][1]
    driver = _write(workdir / "driver.sml", 'structure Driver = struct\nfun main () =\n'
        'Runner.run {requires=Contract.requires, ensures=Contract.ensures, target=Target.run,\n'
        f'readInput={input_read}, showInput={input_show}, showOutput={output_show},\n'
        f'corpusPath={_str(input_path)}, validTarget={valid_target}, maxAttempts={max_attempts}}}\nend\n')
    cm = _cm(workdir / "runtime.cm", [ROOT / "vendor/qcheck/qcheck.cm", ROOT / "sml/Spec.sml",
              ROOT / "sml/Runner.sml", contract_path, target, driver])
    program = (f'val _ = if CM.make {_str(cm)} then () else OS.Process.exit OS.Process.failure;\n'
               'val _ = Driver.main ();\n'
               'val _ = OS.Process.exit OS.Process.success;\n')
    main = _write(workdir / "main.sml", program)
    result = run_sml(program, workdir, timeout, "execution")
    result["main_path"] = str(main)
    return result

