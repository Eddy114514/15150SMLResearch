# Trusted Spec

The shared `Spec` structure is available during isolated predicate compilation and execution.

```sml
Spec.forall       : ('a -> bool) -> 'a list -> bool
Spec.exists       : ('a -> bool) -> 'a list -> bool
Spec.member       : ''a -> ''a list -> bool
Spec.subset       : ''a list * ''a list -> bool
Spec.forallRange  : (int -> bool) -> int * int -> bool
Spec.existsRange  : (int -> bool) -> int * int -> bool
Spec.sorted       : int list -> bool
Spec.sameMultiset : int list * int list -> bool
```

`forall`/`exists` use Basis list quantifiers: left-to-right short circuit; empty results are true/false respectively. `member` uses SML equality; `''a` requires an equality type, not arbitrary functions or reals. `subset (xs,ys)` checks inclusion, ignoring order and duplicates; it accepts lists, not abstract SET values.

`sorted` means nondecreasing, including `[]`. `sameMultiset` ignores order but preserves occurrence counts. List `=` preserves both order and counts. For example, `Spec.subset ([2,2],[2])` is true, but `Spec.sameMultiset ([2,2],[2])` is false.

Range quantifiers visit the closed interval `(lo,hi)` in increasing order, without building a list. If `lo>hi`, results are true/false respectively without evaluating the predicate. They short-circuit and stop at `hi` before incrementing, including `Int.maxInt`; predicate exceptions propagate. Worst-case traversal remains linear in interval size.
