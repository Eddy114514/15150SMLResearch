"""Extract fixed-format contract comments and generate bounded input samples."""

import random
import re


def extract_contract(source_text, contract_id):
    """Read the marked comment from the project's fixed source format."""
    pattern = rf"\(\*\s*@contract\s+{re.escape(contract_id)}\s.*?\*\)"
    match = re.search(pattern, source_text, re.DOTALL)
    if match is None:
        raise ValueError(f"contract not found: {contract_id}")
    return match.group(0)


def generate_corpus(case, seed, count, min_int, max_int):
    """Fixed edge cases followed by Python Random(seed) bounded samples."""
    low, high = max(-100, min_int), min(100, max_int)
    rng = random.Random(seed)
    generator = case["generator"]
    sort_lists = case.get("generator_options", {}).get("sort_lists", False)
    lists = [[], [0], [1], [-1], [1, 1], [1, 2, 3], [3, 2, 1],
             [-3, 0, 2], [0, 0, 0], [-1, -1, 2, 2], [2, -1, 2, -1]]
    lists = [[max(min_int, min(max_int, item)) for item in xs] for xs in lists]
    if generator == "int":
        values = [0, 1, -1, min_int, max_int, low, high]
    elif generator == "int_list":
        values = lists
    elif generator == "int_list_pair":
        values = [[0, []], [1, []], [0, [0]], [1, [1]], [2, [1]],
                  [1, [1, 1]], [2, [1, 2, 3]], [2, [3, 2, 1]],
                  [0, [-3, 0, 2]], [-1, [-1, -1, 2, 2]], [2, [2, -1, 2, -1]]]
        values = [[max(min_int, min(max_int, x)),
                   [max(min_int, min(max_int, item)) for item in xs]]
                  for x, xs in values]
    else:
        raise ValueError(f"unsupported generator: {generator!r}")
    while len(values) < count:
        if generator == "int":
            values.append(rng.randint(low, high))
        else:
            xs = [rng.randint(low, high) for _ in range(rng.randint(0, 20))]
            if sort_lists:
                xs.sort()
            values.append(xs if generator == "int_list" else [rng.randint(low, high), xs])
    return values[:count]
