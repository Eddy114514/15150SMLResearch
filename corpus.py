"""Read contract comments and plan their explicit same-file helper references."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FIELDS = ("entrypoint", "input_type", "output_type", "input_pattern")
_NAME = r"[A-Za-z][A-Za-z0-9_']*(?:\.[A-Za-z][A-Za-z0-9_']*)*"
_TOKEN = re.compile(rf"(?<![A-Za-z0-9_'.]){_NAME}(?![A-Za-z0-9_'])")
_TASK_MARKER = re.compile(
    r"(?m)^[ \t]*\(\*[ \t]*@(solution|manual)\b([^\r\n]*?)\*\)[ \t]*(?:\r?\n|$)")


def split_task_file(text):
    """Split reserved, standalone task markers without parsing SML.

    Return the unchanged text and None for legacy files. A combined file has
    one @solution followed by one or more @manual CASE_ID blocks. A provenance
    preamble stays in the full snapshot, outside the runtime solution slice.
    """
    markers = list(_TASK_MARKER.finditer(text))
    if not markers:
        return text, None
    if markers[0][1] != "solution" or markers[0][2].strip():
        raise ValueError("Combined SML file must begin its sections with (* @solution *)")
    if len(markers) < 2:
        raise ValueError("Combined SML file must contain at least one (* @manual CASE_ID *) section")
    solution = text[markers[0].end():markers[1].start()]
    manuals = {}
    for index, marker in enumerate(markers[1:], start=1):
        ident = marker[2].strip()
        if marker[1] != "manual" or not ident or re.search(r"\s", ident):
            raise ValueError("After @solution, every section must be (* @manual CASE_ID *)")
        if ident in manuals:
            raise ValueError(f"Duplicate manual section: {ident}")
        end = markers[index + 1].start() if index + 1 < len(markers) else len(text)
        manuals[ident] = text[marker.end():end]
    return solution, manuals


def manual_text_for_case(text, case_id):
    """Select a combined file's case block, or keep a standalone contract."""
    _, sections = split_task_file(text)
    if sections is None:
        return text
    if case_id not in sections:
        raise ValueError(f"Manual section not found: {case_id}")
    return sections[case_id]


def extract_contract(source_text, contract_id):
    """Read the marked comment from the project's fixed source format."""
    pattern = rf"\(\*\s*@contract\s+{re.escape(contract_id)}\s.*?\*\)"
    match = re.search(pattern, source_text, re.DOTALL)
    if match is None:
        raise ValueError(f"contract not found: {contract_id}")
    return match.group(0)


def _parts(contract):
    """Separate signature names from REQUIRES/ENSURES in a contract comment."""
    names, body = [], []
    section = None
    for raw in contract[2:-2].splitlines():
        line = raw.strip().removeprefix("*").lstrip()
        label = re.match(r"([A-Z][A-Z_ ]*):\s*(.*)", line)
        if label:
            section = label[1]
            if section in ("REQUIRES", "ENSURES"):
                body.append(label[2])
        elif section in ("REQUIRES", "ENSURES"):
            body.append(line)
        elif section is None:
            signature = re.match(rf"({_NAME})\s*:", line)
            if signature:
                names.append(signature[1])
    return names, "\n".join(body)


def plan(cases, roots, tasks_dir):
    """Return one source snapshot and dependency-first order for selected roots."""
    cases_by_id = {case["id"]: case for case in cases}
    if len(cases_by_id) != len(cases):
        raise ValueError("Duplicate case IDs in manifest")
    by_source, paths, bindings = {}, {}, {}
    reserved = {case["entrypoint"] for case in cases
                if re.fullmatch(_NAME, case["entrypoint"]) and "." not in case["entrypoint"]}
    for case in cases:
        ident, entrypoint = case["id"], case["entrypoint"]
        path = (Path(tasks_dir) / case["source"]).resolve()
        paths[ident] = path
        by_source.setdefault(path, []).append(case)
        if re.fullmatch(_NAME, entrypoint):
            binding = entrypoint
            if "." in entrypoint:
                binding = "helper_" + entrypoint.replace(".", "_")
                while binding in reserved:
                    binding = "helper_" + binding
                reserved.add(binding)
            bindings[ident] = binding

    result = {"order": [], "nodes": {}, "errors": {},
              "roots": list(dict.fromkeys(case["id"] for case in roots))}
    sources, file_texts, manual_cases, state, stack = {}, {}, {}, {}, []

    def read_snapshot(path):
        if path not in file_texts:
            file_texts[path] = path.read_text(encoding="utf-8")
        return file_texts[path]

    def source_info(path):
        if path not in sources:
            snapshot = read_snapshot(path)
            text, _ = split_task_file(snapshot)
            contract_texts = [text]
            for case in by_source[path]:
                if "contract_file" not in case:
                    continue
                filename = case["contract_file"]
                if not isinstance(filename, str) or not filename.strip():
                    raise ValueError(f"Case {case['id']}: contract_file must name an SML file")
                contract_path = (ROOT / filename).resolve()
                manual_snapshot = read_snapshot(contract_path)
                _, sections = split_task_file(manual_snapshot)
                if contract_path == path and sections is None:
                    raise ValueError(f"Case {case['id']}: shared source and contract_file require @solution/@manual sections")
                manual_text = manual_text_for_case(manual_snapshot, case["id"])
                contract = extract_contract(manual_text, case["contract_id"])
                names, body = _parts(contract)
                manual_cases[case["id"]] = {
                    "path": str(contract_path), "text": manual_text,
                    "snapshot_text": manual_snapshot,
                    "section": case["id"] if sections is not None else None,
                    "contract": (contract, names, body)}
                contract_texts.append(manual_text)
            contracts, declarations, aliases = {}, {}, {}
            for index, contract_text in enumerate(contract_texts):
                for match in re.finditer(r"\(\*\s*@contract\s+(\S+)\s.*?\*\)", contract_text, re.DOTALL):
                    contract_id, contract = match[1], match[0]
                    names, body = _parts(contract)
                    # External contracts enrich dependency names, but must not
                    # replace a model case's original source contract.
                    if index == 0:
                        contracts[contract_id] = (contract, names, body)
                    for name in names:
                        declarations.setdefault(name, []).append(contract_id)
            for case in by_source[path]:
                entry = manual_cases[case["id"]]["contract"] if case["id"] in manual_cases else \
                    contracts.get(case["contract_id"], (None, [], None))
                names = list(entry[1])
                if case["id"] in bindings:
                    names.append(case["entrypoint"])
                for name in dict.fromkeys(names):
                    aliases.setdefault(name, []).append(case["id"])
            sources[path] = (text, snapshot, contracts, declarations, aliases)
        return sources[path]

    def visit(ident):
        if state.get(ident) == "done":
            return
        if state.get(ident) == "active":
            cycle = stack[stack.index(ident):] + [ident]
            for member in cycle[:-1]:
                result["errors"].setdefault(member, []).append({
                    "code": "cyclic_dependency", "message": "Contract dependency cycle: " + " -> ".join(cycle),
                    "path": cycle})
            return
        case = cases_by_id[ident]
        text, snapshot, contracts, declarations, aliases = source_info(paths[ident])
        node = {"case": case, "source_text": text, "source_snapshot_text": snapshot, "contract": None,
                "dependencies": [], "helpers": []}
        if ident in manual_cases:
            node.update(manual_text=manual_cases[ident]["text"],
                        manual_path=manual_cases[ident]["path"],
                        manual_snapshot_text=manual_cases[ident]["snapshot_text"],
                        manual_section=manual_cases[ident]["section"])
        result["nodes"][ident] = node
        state[ident] = "active"
        stack.append(ident)
        if ident not in manual_cases and case["contract_id"] not in contracts:
            result["errors"].setdefault(ident, []).append({
                "code": "missing_contract", "message": f"Case {ident}: contract {case['contract_id']!r} not found in {paths[ident]}"})
        else:
            contract, names, body = manual_cases[ident]["contract"] if ident in manual_cases else \
                contracts[case["contract_id"]]
            node["contract"] = contract
            own_names = set(names)
            if ident in bindings:
                own_names.add(case["entrypoint"])
            own_names.update(name for name, candidates in aliases.items()
                             if any(cases_by_id[other]["entrypoint"] == case["entrypoint"]
                                    for other in candidates))
            for name in dict.fromkeys(_TOKEN.findall(body)):
                if name in own_names or name not in declarations and name not in aliases:
                    continue
                candidates = aliases.get(name, [])
                error = None
                if not candidates:
                    error = {"code": "missing_helper_case", "name": name,
                             "contract_ids": declarations[name],
                             "message": f"Case {ident}: referenced helper {name!r} has a same-file contract but no registered case"}
                elif len(candidates) > 1:
                    error = {"code": "ambiguous_helper_instance", "name": name, "candidates": candidates,
                             "message": f"Case {ident}: helper {name!r} has multiple case instances: {', '.join(candidates)}"}
                else:
                    dependency = candidates[0]
                    if dependency in node["dependencies"]:
                        continue
                    node["dependencies"].append(dependency)
                    helper = cases_by_id[dependency]
                    if "contract_file" in case and "contract_file" not in helper:
                        error = {"code": "manual_helper_requires_contract", "name": name,
                                 "dependency": dependency,
                                 "message": f"Case {ident}: manual contract helper {name!r} ({dependency}) must provide contract_file; model translation is disabled for manual dependencies"}
                    elif dependency not in bindings or "target_wrapper" in helper or any(
                            not isinstance(helper.get(key), str) or not helper[key].strip()
                            or re.search(r"(?<![A-Za-z0-9_'])(?:''|')[A-Za-z]", helper[key])
                            for key in ("input_type", "output_type")):
                        error = {"code": "unsupported_helper_signature", "name": name, "dependency": dependency,
                                 "message": f"Case {ident}: helper {name!r} ({dependency}) needs a plain callable entrypoint and concrete input/output types; a lambda or runtime wrapper does not establish the original function signature"}
                    else:
                        helper_contract = manual_cases[dependency]["contract"][0] if dependency in manual_cases else \
                            contracts.get(helper["contract_id"], (None, [], None))[0]
                        binding = bindings[dependency]
                        node["helpers"].append({
                            "case_id": dependency, "binding_name": binding,
                            "callable_name": "Helpers." + binding, "entrypoint": helper["entrypoint"],
                            "input_type": helper["input_type"], "output_type": helper["output_type"],
                            "signature": f"({helper['input_type']}) -> ({helper['output_type']})",
                            "contract": helper_contract,
                            **({"support_cm": helper["support_cm"]} if helper.get("support_cm") else {})})
                    # An unavailable manual dependency is recorded, not scheduled
                    # through the model route. Explicit model roots still run.
                    if not ("contract_file" in case and "contract_file" not in helper):
                        visit(dependency)
                if error:
                    result["errors"].setdefault(ident, []).append(error)
        stack.pop()
        state[ident] = "done"
        result["order"].append(ident)

    for ident in result["roots"]:
        visit(ident)
    return result
