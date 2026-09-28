# Shared tree input type

The task's shared support library provides one `Tree` structure. Contract, Target and data adapters use this same datatype identity.

```sml
structure Tree : sig
  datatype tree = Leaf of int | Node of tree * tree
end
```

`Tree.Leaf : int -> Tree.tree` stores an integer. `Tree.Node : Tree.tree * Tree.tree -> Tree.tree` stores two subtrees. These are the complete public constructors; use pattern matching on `Tree.Leaf n` and `Tree.Node (left,right)`. The datatype itself imposes no search-order or balance invariant. It is a trusted input representation for the task, not a verified implementation of arbitrary tree operations.
