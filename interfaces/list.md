# Basis List and ListPair

Bindings: `List`, `ListPair`.

```sml
List.null   : 'a list -> bool
List.length : 'a list -> int
List.hd     : 'a list -> 'a
List.tl     : 'a list -> 'a list
List.nth    : 'a list * int -> 'a
List.take   : 'a list * int -> 'a list
List.drop   : 'a list * int -> 'a list
List.rev    : 'a list -> 'a list
List.concat : 'a list list -> 'a list
List.map    : ('a -> 'b) -> 'a list -> 'b list
List.filter : ('a -> bool) -> 'a list -> 'a list
List.foldl  : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
List.foldr  : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b
List.all    : ('a -> bool) -> 'a list -> bool
List.exists : ('a -> bool) -> 'a list -> bool
ListPair.all   : ('a * 'b -> bool) -> 'a list * 'b list -> bool
ListPair.allEq : ('a * 'b -> bool) -> 'a list * 'b list -> bool
```

Folds pass `(element,accumulator)`: `foldl` processes left-to-right, `foldr` right-to-left. `all`/`exists` short-circuit left-to-right; on `[]` they return true/false. `filter` and `concat` preserve order and occurrences.

`hd`/`tl` require nonempty lists (`Empty`). `nth (xs,i)` uses zero-based indexing, requiring `0<=i<length xs`; `take`/`drop` allow `i=length xs`. Invalid indices raise `Subscript`.

`ListPair.all p (xs,ys)` checks only their common prefix. `ListPair.allEq` additionally requires equal lengths and returns false on mismatch. Example: `ListPair.allEq (op =) ([1],[1,2])` is false.
