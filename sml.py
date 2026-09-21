"""Generate and run the fixed SML contract compiler and QCheck adapter."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent

PREFIX = "@@SMLPBT@@"
_SHOW = {"int": "Runner.int", "bool": "Runner.bool",
         "int list": "Runner.list Runner.int", "int * int list": "Runner.pair",
         "int list list": "Runner.list (Runner.list Runner.int)",
         "int list * int": "Runner.listIntPair",
         "int list option": "Runner.option (Runner.list Runner.int)"}


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


def _cm(path, files, exports=None, libraries=()):
    header = "Group is" if exports is None else "Library\n  " + "\n  ".join(exports) + "\nis"
    return _write(path, header + "\n  $/basis.cm\n" +
                  "".join("  " + library + "\n" for library in libraries) +
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
    success = json.dumps({"status": "compiled", "stage": "predicate", "compile_ok": True})
    failure = json.dumps({"status": "compile_error", "stage": "predicate", "compile_ok": False})
    program = (
        f'val ok = CM.make {_str(cm)};\n'
        f'val message = if ok then {_str(success)} else {_str(failure)};\n'
        f'val _ = print ("\\n" ^ {_str(PREFIX)} ^ message ^ "\\n");\n'
        'val _ = OS.Process.exit OS.Process.success;\n')
    result = run_sml(program, workdir, timeout, "predicate")
    # Only an error reported in the generated file is eligible for model repair.
    if result["status"] == "compile_error" and path.name + ":" not in result["diagnostics"]:
        raise RuntimeError(result["diagnostics"])
    result["contract_path"] = str(path)
    return result


def execute(case, contract_path, source, workdir, *,
            seed, valid_target, max_attempts, timeout):
    target = _write(workdir / "Target.sml", "structure Target = struct\n" + source +
                    f'\nfun run (input : {case["input_type"]}) : {case["output_type"]} = {case["entrypoint"]} input\nend\n')
    input_show, output_show = _SHOW[case["input_type"]], _SHOW[case["output_type"]]
    generator = {"int": "Generators.ints", "int_list": "Generators.lists",
                 "int_list_pair": "Generators.pairs",
                 "list_int_pair": "Generators.listIntPairs",
                 "int_list_list": "Generators.listLists"}[case["generator"]]
    options = f"seed={seed}, count={max_attempts}"
    if case["generator"] in ("int_list", "int_list_pair", "list_int_pair"):
        sort_lists = case.get("generator_options", {}).get("sort_lists", False)
        options += ", sortLists=" + str(sort_lists).lower()
    driver = _write(workdir / "driver.sml", 'structure Driver = struct\nfun main () = let\n'
        f'  val inputs = {generator} {{{options}}}\n'
        f'  val _ = Runner.writeInputs ({_str(workdir / "inputs.json")}, {input_show}, inputs)\n'
        'in Runner.run {requires=Contract.requires, ensures=Contract.ensures, target=Target.run,\n'
        f'showInput={input_show}, showOutput={output_show}, inputs=inputs, validTarget={valid_target}}}\n'
        'end\nend\n')
    cm = _cm(workdir / "runtime.cm", [ROOT / "vendor/qcheck/qcheck.cm", ROOT / "sml/Spec.sml",
              ROOT / "sml/Generators.sml", ROOT / "sml/Runner.sml", contract_path, target, driver],
              libraries=["$/smlnj-lib.cm"])
    program = (f'val _ = if CM.make {_str(cm)} then () else OS.Process.exit OS.Process.failure;\n'
               'val _ = Driver.main ();\n'
               'val _ = OS.Process.exit OS.Process.success;\n')
    main = _write(workdir / "main.sml", program)
    result = run_sml(program, workdir, timeout, "execution")
    result["main_path"] = str(main)
    return result
