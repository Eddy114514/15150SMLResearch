Shared finite descriptions:
datatype CpsCase.tree = Tip of int | Fork of CpsCase.tree * CpsCase.tree
datatype CpsCase.predicate = Any | Even | Positive | Equals of int
datatype CpsCase.equality = Exact | Parity
Qualify constructors with CpsCase.
- CpsCase.test : CpsCase.predicate -> int -> bool. Any accepts all, Even even integers, Positive >0, Equals its stored value. Total; no preconditions.
- CpsCase.equivalent : CpsCase.equality -> int * int -> bool. Exact equality or same parity; both total equivalence relations.
- CpsModel.leaves : CpsCase.tree -> int list. Left-to-right leaf values, repetitions retained. No preconditions.
- CpsModel.distinct : ('a * 'a -> bool) -> 'a list -> bool. Pairwise distinct under the supplied total equivalence relation.
- CpsModel.classes : ('a * 'a -> bool) -> 'a list -> 'a list. One representative per equivalence class, in unspecified/reversed encounter order. Requires total equivalence relation. The list length is the number of classes; do not treat its ordering as the target answer.
The adapter constructs the original shrub and supplies SOME as success continuation and fn () => NONE as failure continuation. A successful list is observed in its returned order. This concrete instance does not observe arbitrary user continuations or prove CPS-totality for arbitrary functions.
