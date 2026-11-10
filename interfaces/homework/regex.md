Shared regexp datatype:
datatype RegexCase.regex = Zero | One | Char of char | Plus of RegexCase.regex * RegexCase.regex | Times of RegexCase.regex * RegexCase.regex | Star of RegexCase.regex | Both of RegexCase.regex * RegexCase.regex
Qualify constructors with RegexCase. Zero is empty language; One epsilon; Plus union; Times concatenation; Star Kleene star; Both intersection using the same consumed prefix.
- RegexCase.nullable : RegexCase.regex -> bool. Whether epsilon belongs to the language. No preconditions.
- RegexCase.standard : RegexCase.regex -> bool. Recursively requires every Star body to exclude epsilon. No preconditions.
- RegexModel.validMatch : RegexCase.regex * char list * bool list -> bool. Standard regexp and continuation table length >= text length + 1. Extra table entries are unused, not invalid. No preconditions.
- RegexModel.positions : RegexCase.regex -> char list -> int list. Set of consumed-prefix lengths accepted by the expression, beginning at position 0. Finite fixed-point semantics; even nullable Star terminates. Output order unspecified.
- RegexModel.matches : RegexCase.regex * char list * bool list -> bool. Some accepted consumed-prefix length indexes a true table entry. Requires table length >= text length + 1.
- RegexModel.accepts : RegexCase.regex * string -> bool. Whether the entire string is in the language; no preconditions.
For adapted match inputs (regexp,text,table), table[i] is the continuation result after consuming i chars (suffix length |text|-i). The adapter builds that continuation; it does not use arbitrary functions. The existing independent language model never invokes Target.match.
