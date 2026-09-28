# CMU 15-150 Set

An actual matching set binding must be supplied by the task's shared support library. The sequence types below refer to the matching `Seq` runtime binding; tasks needing its API must list `cmu150.sequence` explicitly.

`SET` is a signature, not a `Set` structure. An actual shared binding such as `IntSet` must exist before use; Contract and Target must share its abstract type `IntSet.t`. Element type: `IntSet.Elt.t`. With that illustrative binding:

```sml
IntSet.Elt.equal : IntSet.Elt.t * IntSet.Elt.t -> bool
IntSet.empty        : IntSet.t
IntSet.singleton    : IntSet.Elt.t -> IntSet.t
IntSet.fromSeq      : IntSet.Elt.t Seq.t -> IntSet.t
IntSet.size         : IntSet.t -> int
IntSet.toSeq        : IntSet.t -> IntSet.Elt.t Seq.t
IntSet.insert       : IntSet.t -> IntSet.Elt.t -> IntSet.t
IntSet.remove       : IntSet.t -> IntSet.Elt.t -> IntSet.t
IntSet.member       : IntSet.t -> IntSet.Elt.t -> bool
IntSet.union        : IntSet.t * IntSet.t -> IntSet.t
IntSet.intersection : IntSet.t * IntSet.t -> IntSet.t
IntSet.difference   : IntSet.t * IntSet.t -> IntSet.t
```

`Elt : EQ` provides `equal`; abstract elements need not support SML `=`. `empty` is a value. Use `IntSet.member s x` (set first), and `IntSet.union (a,b)` (tuple). Difference removes elements of the second set from the first.

Sets discard duplicate elements; `fromSeq` retains the first equal representative. `toSeq` specifies membership, not ordering. Neither list `Spec.subset` nor list equality directly accepts an abstract set. This documentation establishes neither runtime availability nor abstract-type QCheck generators/displayers.
