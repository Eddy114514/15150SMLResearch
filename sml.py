"""Generate and run the fixed SML contract compiler and QCheck adapter."""
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
EVALUATIONS = ROOT / "tasks/hw/evaluation"

PREFIX = "@@SMLPBT@@"


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
    """Load the task's runtime data adapter and expose its Data interface."""
    adapter = case["data_adapter"]
    return _runtime_source(adapter["file"]) + f'\nstructure Data = {adapter["structure"]}\n'


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
    except (StopIteration, json.JSONDecodeError) as exc:
        print(diagnostics, file=sys.stderr)
        raise RuntimeError(f"SML {phase} did not produce a valid completion record; see {workdir / 'log.txt'}") from exc
    result.update(elapsed_seconds=time.monotonic() - started, diagnostics=diagnostics)
    return result


def _cm(path, files, exports=None, libraries=()):
    header = "Group is" if exports is None else "Library\n  " + "\n  ".join(exports) + "\nis"
    return _write(path, header + "\n  $/basis.cm\n" +
                  "".join("  " + library + "\n" for library in libraries) +
                  "".join("  " + _str(Path(f).resolve()) + "\n" for f in files))


def _link_and_run(workdir, files, *, cm_name, main_name, timeout, phase):
    """Link the ordered runtime files and invoke their shared Driver entrypoint."""
    cm = _cm(workdir / cm_name, files, libraries=["$/smlnj-lib.cm"])
    program = (f'val _ = if CM.make {_str(cm)} then () else OS.Process.exit OS.Process.failure;\n'
               'val _ = Driver.main ();\n'
               'val _ = OS.Process.exit OS.Process.success;\n')
    _write(workdir / main_name, program)
    return run_sml(program, workdir, timeout, phase)


def contract_module(case, role=""):
    """Stable SML identifiers for concrete manifest cases, independent of paths."""
    return f"Contract_{role}_{case['id']}Fn"


def _helper_parameters(helpers):
    return "".join(f'    val {helper["binding_name"]} : {helper["signature"]}\n'
                   for helper in helpers)


def _compile_predicate(case, path, workdir, timeout, helpers, role=""):
    module = contract_module(case, role)
    # Helpers may require shared types even when the caller's types do not.
    support = list(dict.fromkeys(path for item in [case, *helpers]
                                for path in item["_context"]["support_libraries"]))
    cm = _cm(workdir / "predicate.cm", support + [ROOT / "sml/Spec.cm", path],
             [f"functor {module}"])
    success = json.dumps({"status": "compiled", "stage": "predicate"})
    failure = json.dumps({"status": "compile_error", "stage": "predicate"})
    program = (
        f'val ok = CM.make {_str(cm)};\n'
        f'val message = if ok then {_str(success)} else {_str(failure)};\n'
        f'val _ = print ("\\n" ^ {_str(PREFIX)} ^ message ^ "\\n");\n'
        'val _ = OS.Process.exit OS.Process.success;\n')
    result = run_sml(program, workdir, timeout, "predicate")
    result.update(contract_path=str(path), module_name=module)
    return result


def compile_contract(case, requires_expr, ensures_expr, workdir, *, attempt, timeout,
                     helpers=(), role=""):
    """Compile with shared support, never the target or its data adapter."""
    filename = "initial_contract.sml" if attempt == 0 else "repaired_contract.sml"
    input_type, output_type, pattern = case["input_type"], case["output_type"], case["input_pattern"]
    module = contract_module(case, role)
    parameters = _helper_parameters(helpers)
    declarations = (f"functor {module} (Helpers : sig\n{parameters}end) = struct\n"
                    f"  type input = {input_type}\n  type output = {output_type}\n")
    path = _write(workdir / filename, declarations +
        f"  fun requires (input : input) : bool = let val {pattern} = input in ({requires_expr}) end\n"
        f"  fun ensures (input : input) (result : output) : bool = let val {pattern} = input in ({ensures_expr}) end\nend\n")
    return _compile_predicate(case, path, workdir, timeout, helpers, role=role)


def compile_manual_contract(case, source_text, workdir, *, timeout, helpers=(), role=""):
    """Compile the selected ManualContract section without Target or model repair."""
    module = contract_module(case, role)
    renamed = re.sub(r"(?m)^(\s*functor\s+)ManualContract\b",
                     lambda match: match[1] + module, source_text)
    path = _write(workdir / "manual_contract.sml", renamed)
    return _compile_predicate(case, path, workdir, timeout, helpers, role=role)


def _target_files(case, source, workdir):
    """Wrap the selected student solution and its runtime-only observation adapters."""
    wrapper_files = []
    if "target_wrapper" in case:
        wrapper_source = _runtime_source(case["target_wrapper"])
        wrapper_files = [_write(workdir / "target_wrapper.sml", wrapper_source)]
    run_declaration = "" if wrapper_files else \
        f'\nfun run (input : {case["input_type"]}) : {case["output_type"]} = ({case["entrypoint"]}) input\n'
    target = _write(workdir / "Target.sml", "structure Target = struct\n" + source +
                    "\n" + run_declaration + "end\n")
    return [target, *wrapper_files], "TargetAdapter.run" if wrapper_files else "Target.run"


def _contract_instances(contracts):
    # Each library was compiled without Target. Only these runtime instances can
    # see real functions, guarded by the corresponding admitted helper requires.
    instances = []
    libraries = []
    for dependency in contracts:
        module = dependency.get("module_name") or contract_module(
            dependency["case"], dependency.get("role", ""))
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
    return "".join(instances), list(dict.fromkeys(libraries))


def _runtime_support(cases):
    return list(dict.fromkeys(path for case in cases
                              for path in case["_context"]["runtime_support_libraries"]))


def execute(case, contract_path, source, workdir, *,
            seed, valid_target, max_attempts, timeout, helpers=(), dependencies=(), role=""):
    target_files, target_entry = _target_files(case, source, workdir)
    instances, libraries = _contract_instances(
        [*dependencies, {"case": case, "contract_path": contract_path,
                         "helpers": helpers, "role": role}])
    wiring = _write(workdir / "bindings.sml", instances +
                    f"structure Contract = {contract_module(case, role)}Result\n")
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
    support = _runtime_support([item["case"] for item in dependencies] + [case])
    data = _write(workdir / "data_adapter.sml", _data_source(case))
    return _link_and_run(workdir, support + libraries + [ROOT / "vendor/qcheck/qcheck.cm", ROOT / "sml/Spec.cm",
              ROOT / "sml/Generators.sml", ROOT / "sml/Runner.sml"] + target_files +
              [wiring, data, driver],
              cm_name="runtime.cm", main_name="main.sml", timeout=timeout, phase="execution")


def evaluate_semantics(case, compiled, workdir, *, timeout, source="",
                       helpers=(), dependencies=(), contradiction=False):
    """Score the supplied predicates directly against fresh fixed-label values."""
    fixtures_path = EVALUATIONS / f"{case['id']}.sml"
    workdir.mkdir(parents=True, exist_ok=True)
    contracts = [*dependencies, {"case": case, **compiled, "helpers": helpers}]
    instances, libraries = _contract_instances(contracts)
    instances += f'structure Contract = {compiled["module_name"]}Result\n'
    target_files, support = [], case["_context"]["support_libraries"]
    if helpers:
        target_files, _ = _target_files(case, source, workdir)
        support = _runtime_support([item["case"] for item in dependencies] + [case])
    wiring = _write(workdir / "semantic_bindings.sml", instances)
    data = _write(workdir / "data_adapter.sml", _data_source(case))
    fixtures = _write(workdir / "evaluation.sml", Path(fixtures_path).read_text(encoding="utf-8"))
    ensures_cases = ("List.map (fn (label,make,_) => (label,make,false)) Evaluation.ensuresCases"
                     if contradiction else "Evaluation.ensuresCases")
    driver = _write(workdir / "semantic_driver.sml", 'structure Driver = struct\n'
        'fun main () = SemanticEvaluation.run {\n'
        '  requires=Contract.requires, ensures=Contract.ensures,\n'
        f'  requiresCases=Evaluation.requiresCases, ensuresCases={ensures_cases},\n'
        '  showInput=Data.showInput, showOutput=Data.showOutput'
        '\n}\nend\n')
    return _link_and_run(workdir, support + libraries +
        [ROOT / "vendor/qcheck/qcheck.cm", ROOT / "sml/Spec.cm",
         ROOT / "sml/Generators.sml", ROOT / "sml/Runner.sml",
         ROOT / "sml/SemanticEvaluation.sml"] + target_files + [wiring, data, fixtures, driver],
        cm_name="semantic.cm", main_name="semantic_main.sml", timeout=timeout, phase="semantic")
