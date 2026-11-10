Independent ordering operations, separate from the student's sort.
- OrderSpec.keyCompare : (int * int) * (int * int) -> order. Compare only first components by Int.compare; second components remain element identity. Total, no preconditions.
- OrderSpec.strictlyOrdered : ('a * 'a -> order) -> 'a list -> bool. True iff each adjacent pair compares LESS; empty/singleton true. Comparator must be total. This is strict order, not merely nondecreasing order.
