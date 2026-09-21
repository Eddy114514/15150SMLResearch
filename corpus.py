"""Extract fixed-format contract comments from SML source."""

import re


def extract_contract(source_text, contract_id):
    """Read the marked comment from the project's fixed source format."""
    pattern = rf"\(\*\s*@contract\s+{re.escape(contract_id)}\s.*?\*\)"
    match = re.search(pattern, source_text, re.DOTALL)
    if match is None:
        raise ValueError(f"contract not found: {contract_id}")
    return match.group(0)
