"""Generate and run the fixed SML contract compiler and QCheck adapter."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

import corpus

ROOT = Path(__file__).resolve().parent

PREFIX = "@@SMLPBT@@"
_SHOW = {"int": "Runner.int", "bool": "Runner.bool",
         "int list": "Runner.list Runner.int",
         "int * int list": "Runner.pair (Runner.int, Runner.list Runner.int)",
         "int list list": "Runner.list (Runner.list Runner.int)",
         "int list * int": "Runner.pair (Runner.list Runner.int, Runner.int)",
         "int list option": "Runner.option (Runner.list Runner.int)"}


def _str(value):
    # SML uses decimal byte escapes, not JSON Unicode escapes.
    return '"' + ''.join(chr(byte) if 32 <= byte < 127 and byte not in (34, 92)
                         else "\\" + str(byte).zfill(3)
                         for byte in str(value).encode("utf-8")) + '"'


def _write(path, content):
    path.write_text(content, encoding="utf-8")
    return path


def _runtime_source(paths):
    """Join explicitly ordered runtime files without importing them into predicates."""
    if isinstance(paths, str):
        paths = [paths]
    return "\n".join((ROOT / path).read_text(encoding="utf-8") for path in paths)


def _data_source(case):
    """Give built-in distributions and explicit adapters the same Data interface."""
    adapter = case.get("data_adapter")
    if adapter is not None:
        return _runtime_source(adapter["file"]) + f'\nstructure Data = {adapter["structure"]}\n'
    sort_lists = str(case.get("generator_options", {}).get("sort_lists", False)).lower()
    lists = f"Generators.randomList {sort_lists}"
    pairs = f"QCheck.Gen.zip (Generators.intGen, {lists})"
    swap = "(fn (x, xs) => (xs, x))"
    generator, edges = {
        "int": ("Generators.intGen", "Generators.intEdges"),
        "int_list": (lists, "Generators.listEdges"),
        "int_list_pair": (pairs, "Generators.pairEdges"),
        "list_int_pair": (f"QCheck.Gen.map {swap} ({pairs})",
                          f"List.map {swap} Generators.pairEdges"),
        "int_list_list": ("Generators.listListGen", "Generators.listListEdges"),
    }[case["generator"]]
    return ("structure Data = struct\n"
            f"  val genInput = {generator}\n  val edges = {edges}\n"
            f'  val showInput = {_SHOW[case["input_type"]]}\n'
            f'  val showOutput = {_SHOW[case["output_type"]]}\nend\n')


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


def contract_module(case):
    """Stable SML identifiers for concrete manifest cases, independent of paths."""
    return "Contract_" + hashlib.sha256(case["id"].encode()).hexdigest()[:16] + "Fn"


def _helper_parameters(helpers):
    return "".join(f'    val {helper["binding_name"]} : {helper["signature"]}\n'
                   for helper in helpers)


def _compile_predicate(case, path, workdir, timeout, helpers, checks=()):
    module = contract_module(case)
    # Helpers may require shared types even when the caller's types do not.
    support = list(dict.fromkeys((ROOT / item["support_cm"]).resolve()
                   for item in [case, *helpers] if item.get("support_cm")))
    # CM prunes unexported, unreferenced compilation units. Export the manual
    # check functor too so its type ascription is actually elaborated.
    exports = [f"functor {module}"] + ([f"functor {module}Check"] if checks else [])
    cm = _cm(workdir / "predicate.cm", support + [ROOT / "sml/Spec.cm", path, *checks], exports)
    success = json.dumps({"status": "compiled", "stage": "predicate", "compile_ok": True})
    failure = json.dumps({"status": "compile_error", "stage": "predicate", "compile_ok": False})
    program = (
        f'val ok = CM.make {_str(cm)};\n'
        f'val message = if ok then {_str(success)} else {_str(failure)};\n'
        f'val _ = print ("\\n" ^ {_str(PREFIX)} ^ message ^ "\\n");\n'
        'val _ = OS.Process.exit OS.Process.success;\n')
    result = run_sml(program, workdir, timeout, "predicate")
    result.update(contract_path=str(path), predicate_cm=str(cm), module_name=module)
    return result


def compile_contract(case, requires_expr, ensures_expr, workdir, *, attempt, timeout,
                     helpers=()):
    """Compile with shared support, never the target or its data adapter."""
    filename = "initial_contract.sml" if attempt == 0 else "repaired_contract.sml"
    input_type, output_type, pattern = case["input_type"], case["output_type"], case["input_pattern"]
    module = contract_module(case)
    parameters = _helper_parameters(helpers)
    declarations = (f"functor {module} (Helpers : sig\n{parameters}end) = struct\n"
                    f"  type input = {input_type}\n  type output = {output_type}\n")
    predicate_line = declarations.count("\n") + 1
    path = _write(workdir / filename, declarations +
        f"  fun requires (input : input) : bool = let val {pattern} = input in ({requires_expr}) end\n"
        f"  fun ensures (input : input) (result : output) : bool = let val {pattern} = input in ({ensures_expr}) end\nend\n")
    result = _compile_predicate(case, path, workdir, timeout, helpers)
    # Task type declarations and support-library failures are configuration errors.
    # Only errors in generated predicate bodies can use the one model repair.
    if result["status"] == "compile_error":
        errors = re.findall(r"(?m)^(.+?):(\d+)[^\n]*\bError:", result["diagnostics"])
        if not errors or any(Path(file).name != filename or int(line) < predicate_line
                             for file, line in errors):
            raise RuntimeError(result["diagnostics"])
    return result


def compile_manual_contract(case, source_text, workdir, *, timeout, helpers=()):
    """Compile a snapshotted ManualContract functor without Target or model repair."""
    source_text = corpus.manual_text_for_case(source_text, case["id"])
    module = contract_module(case)
    renamed, count = re.subn(r"(?m)^(\s*functor\s+)ManualContract\b",
                             lambda match: match[1] + module, source_text)
    if count != 1:
        raise ValueError(f"Case {case['id']}: contract_file must declare one functor ManualContract")
    path = _write(workdir / "manual_contract.sml", renamed)
    # Type-check the public contract and admitted helper environment without
    # instantiating it with student functions or loading any runtime adapter.
    check = _write(workdir / "contract_check.sml",
        f"functor {module}Check (Helpers : sig\n{_helper_parameters(helpers)}end) = struct\n"
        "  structure Checked : sig\n"
        f"    type input = {case['input_type']}\n"
        f"    type output = {case['output_type']}\n"
        "    val requires : input -> bool\n"
        "    val ensures : input -> output -> bool\n"
        f"  end = {module} (Helpers)\nend\n")
    return _compile_predicate(case, path, workdir, timeout, helpers, [check])


def execute(case, contract_path, source, workdir, *,
            seed, valid_target, max_attempts, timeout, helpers=(), dependencies=()):
    source, _ = corpus.split_task_file(source)
    wrapper_files = []
    if "target_wrapper" in case:
        wrapper_source = _runtime_source(case["target_wrapper"])
        wrapper_files = [_write(workdir / "target_wrapper.sml", wrapper_source)]
    run_declaration = "" if wrapper_files else \
        f'\nfun run (input : {case["input_type"]}) : {case["output_type"]} = ({case["entrypoint"]}) input\n'
    target = _write(workdir / "Target.sml", "structure Target = struct\n" + source +
                    "\n" + run_declaration + "end\n")
    # Each library was compiled without Target. Only these runtime instances can
    # see real functions, guarded by the corresponding admitted helper requires.
    instances = []
    libraries = []
    for dependency in [*dependencies, {"case": case, "contract_path": contract_path,
                                      "helpers": helpers}]:
        module = contract_module(dependency["case"])
        arguments = []
        for helper in dependency["helpers"]:
            checked = contract_module({"id": helper["case_id"]}) + "Result"
            arguments.append(
                f'  fun {helper["binding_name"]} (input : {helper["input_type"]}) : {helper["output_type"]} =\n'
                f'    if {checked}.requires input then (Target.{helper["entrypoint"]}) input\n'
                f'    else raise Spec.DependencyDomainViolation {_str(helper["callable_name"])}\n')
        instances.append(f"structure {module}Result = {module} (struct\n" +
                         "".join(arguments) + "end)\n")
        libraries.append(Path(dependency["contract_path"]).parent / "predicate.cm")
    wiring = _write(workdir / "bindings.sml", "".join(instances) +
                    f"structure Contract = {contract_module(case)}Result\n")
    target_entry = "TargetAdapter.run" if wrapper_files else "Target.run"
    driver = _write(workdir / "driver.sml", 'structure Driver = struct\n'
        'val inputGenerator : Contract.input QCheck.Gen.gen = Data.genInput\n'
        'val inputEdges : Contract.input list = Data.edges\n'
        'val showInput : Contract.input -> string = Data.showInput\n'
        'val showOutput : Contract.output -> string = Data.showOutput\n'
        'fun main () = let\n'
        f'  val inputs = Generators.sample inputEdges inputGenerator {{seed={seed}, count={max_attempts}}}\n'
        f'  val _ = Runner.writeInputs ({_str(workdir / "inputs.json")}, showInput, inputs)\n'
        f'in Runner.run {{requires=Contract.requires, ensures=Contract.ensures, target={target_entry},\n'
        f'showInput=showInput, showOutput=showOutput, inputs=inputs, validTarget={valid_target}}}\n'
        'end\nend\n')
    support = list(dict.fromkeys((ROOT / item["case"]["support_cm"]).resolve()
                                for item in [*dependencies, {"case": case}]
                                if item["case"].get("support_cm")))
    data = _write(workdir / "data_adapter.sml", _data_source(case))
    cm = _cm(workdir / "runtime.cm", support + libraries + [ROOT / "vendor/qcheck/qcheck.cm", ROOT / "sml/Spec.cm",
              ROOT / "sml/Generators.sml", ROOT / "sml/Runner.sml", target] + wrapper_files +
              [wiring, data, driver],
              libraries=["$/smlnj-lib.cm"])
    program = (f'val _ = if CM.make {_str(cm)} then () else OS.Process.exit OS.Process.failure;\n'
               'val _ = Driver.main ();\n'
               'val _ = OS.Process.exit OS.Process.success;\n')
    main = _write(workdir / "main.sml", program)
    result = run_sml(program, workdir, timeout, "execution")
    result["main_path"] = str(main)
    return result
