"""Read contract comments and plan their explicit same-file helper references."""

import re
from pathlib import Path

FIELDS = ("entrypoint", "input_type", "output_type", "input_pattern")
_NAME = r"[A-Za-z][A-Za-z0-9_']*(?:\.[A-Za-z][A-Za-z0-9_']*)*"
_TOKEN = re.compile(rf"(?<![A-Za-z0-9_'.]){_NAME}(?![A-Za-z0-9_'])")


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
    sources, state, stack = {}, {}, []

    def source_info(path):
        if path not in sources:
            text = path.read_text(encoding="utf-8")
            contracts, declarations, aliases = {}, {}, {}
            for match in re.finditer(r"\(\*\s*@contract\s+(\S+)\s.*?\*\)", text, re.DOTALL):
                contract_id, contract = match[1], match[0]
                names, body = _parts(contract)
                contracts[contract_id] = (contract, names, body)
                for name in names:
                    declarations.setdefault(name, []).append(contract_id)
            for case in by_source[path]:
                names = list(contracts.get(case["contract_id"], (None, [], None))[1])
                if case["id"] in bindings:
                    names.append(case["entrypoint"])
                for name in dict.fromkeys(names):
                    aliases.setdefault(name, []).append(case["id"])
            sources[path] = (text, contracts, declarations, aliases)
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
        text, contracts, declarations, aliases = source_info(paths[ident])
        node = {"case": case, "source_text": text, "contract": None,
                "dependencies": [], "helpers": []}
        result["nodes"][ident] = node
        state[ident] = "active"
        stack.append(ident)
        if case["contract_id"] not in contracts:
            result["errors"].setdefault(ident, []).append({
                "code": "missing_contract", "message": f"Case {ident}: contract {case['contract_id']!r} not found in {paths[ident]}"})
        else:
            contract, names, body = contracts[case["contract_id"]]
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
                    if dependency not in bindings or any(
                            not isinstance(helper.get(key), str) or not helper[key].strip()
                            or re.search(r"(?<![A-Za-z0-9_'])(?:''|')[A-Za-z]", helper[key])
                            for key in ("input_type", "output_type")):
                        error = {"code": "unsupported_helper_signature", "name": name, "dependency": dependency,
                                 "message": f"Case {ident}: helper {name!r} ({dependency}) needs a plain callable entrypoint and concrete input/output types; an adapted lambda does not establish the original function signature"}
                    else:
                        helper_contract = contracts.get(helper["contract_id"], (None, [], None))[0]
                        binding = bindings[dependency]
                        node["helpers"].append({
                            "case_id": dependency, "binding_name": binding,
                            "callable_name": "Helpers." + binding, "entrypoint": helper["entrypoint"],
                            "input_type": helper["input_type"], "output_type": helper["output_type"],
                            "signature": f"({helper['input_type']}) -> ({helper['output_type']})",
                            "contract": helper_contract,
                            **({"support_cm": helper["support_cm"]} if helper.get("support_cm") else {})})
                    visit(dependency)
                if error:
                    result["errors"].setdefault(ident, []).append(error)
        stack.pop()
        state[ident] = "done"
        result["order"].append(ident)

    for ident in result["roots"]:
        visit(ident)
    return result
