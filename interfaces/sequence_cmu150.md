# CMU 15-150 Sequence

The task's shared support library must provide a single `Seq : SEQUENCE` binding used by Contract, Target and adapters. Selecting this card does not load a library. Sequences are ordered abstract collections: `'a Seq.seq = 'a Seq.t`; representation and SML equality are not exposed. Call the operations below through `Seq`.

```sml
signature SEQUENCE = sig
  type 'a t
  type 'a seq = 'a t
  exception Range of string

  val empty : unit -> 'a seq
  val singleton : 'a -> 'a seq
  val tabulate : (int -> 'a) -> int -> 'a seq
  val fromList : 'a list -> 'a seq

  val nth : 'a seq -> int -> 'a
  val null : 'a seq -> bool
  val length : 'a seq -> int
  val toList : 'a seq -> 'a list
  val toString : ('a -> string) -> 'a seq -> string
  val equal : ('a * 'a -> bool) -> 'a seq * 'a seq -> bool

  val rev : 'a seq -> 'a seq
  val append : 'a seq * 'a seq -> 'a seq
  val flatten : 'a seq seq -> 'a seq
  val cons : 'a -> 'a seq -> 'a seq

  val filter : ('a -> bool) -> 'a seq -> 'a seq
  val map : ('a -> 'b) -> 'a seq -> 'b seq
  val reduce : ('a * 'a -> 'a) -> 'a -> 'a seq -> 'a
  val reduce1 : ('a * 'a -> 'a) -> 'a seq -> 'a
  val mapreduce : ('a -> 'b) -> 'b -> ('b * 'b -> 'b) -> 'a seq -> 'b
  val zip : 'a seq * 'b seq -> ('a * 'b) seq
  val zipWith : ('a * 'b -> 'c) -> 'a seq * 'b seq -> 'c seq

  val enum : 'a seq -> (int * 'a) seq
  val mapIdx : (int * 'a -> 'b) -> 'a seq -> 'b seq
  val update : 'a seq * (int * 'a) -> 'a seq
  val inject : 'a seq * (int * 'a) seq -> 'a seq
  val subseq : 'a seq -> int * int -> 'a seq
  val take : 'a seq -> int -> 'a seq
  val drop : 'a seq -> int -> 'a seq
  val split : 'a seq -> int -> 'a seq * 'a seq

  val sort : ('a * 'a -> order) -> 'a seq -> 'a seq
  val merge : ('a * 'a -> order) -> 'a seq * 'a seq -> 'a seq
  val search : ('a * 'a -> order) -> 'a -> 'a seq -> int option

  datatype 'a lview = Nil | Cons of 'a * 'a seq
  val showl : 'a seq -> 'a lview
  val hidel : 'a lview -> 'a seq

  datatype 'a tview = Empty | Leaf of 'a | Node of 'a seq * 'a seq
  val showt : 'a seq -> 'a tview
  val hidet : 'a tview -> 'a seq
end
```

Let `n = Seq.length S`; indices start at zero. Range failures raise `Seq.Range` with a string message; do not rely on the message text. Pure callback values must meet the requirements below. Parallel combinators specify result positions, not callback execution order or short-circuit behavior.

## Construction and observation

- `Seq.empty ()` has length zero; `Seq.singleton x` has length one and element `x`.
- `Seq.tabulate f n` has length `n` and element `f i` at each `0 <= i < n`; every such call must return a value. Negative `n` raises `Range`; zero produces the empty sequence without an element call.
- `Seq.fromList xs` and `Seq.toList S` preserve order and every occurrence when converting between lists and sequences.
- `Seq.nth S i` returns element `i`; it raises `Range` unless `0 <= i < n`. The sequence argument comes first.
- `Seq.null S` is true exactly when `n = 0`; `Seq.length S` returns the element count.
- `Seq.toString show S` uses `show` on the elements to make a sequence representation; `show` must return a string for every element. The current binding formats empty as `<>` and other sequences as `<x, y, ...>` with comma-space separators. This is a pretty-printed string, not a JSON encoder; exact punctuation is an implementation detail.
- `Seq.equal eq (A,B)` requires total `eq`; it is true exactly when lengths agree and corresponding elements satisfy `eq`. Use this supplied relation for abstract elements, not SML `=` on sequences. Two empty sequences compare true.

## Ordered transformations

- `Seq.rev S` reverses all positions, preserving every occurrence.
- `Seq.append (A,B)` places all of `A` before all of `B`; result length is `length A + length B`.
- `Seq.flatten SS` concatenates inner sequences in outer order, preserving inner order and occurrences; empty inner sequences contribute nothing.
- `Seq.cons x S` prepends `x`; it has length `n+1`. It is curried, unlike `append`, and has linear work for an array-based sequence, unlike list cons.
- `Seq.filter p S` keeps exactly the occurrences for which `p` returns true, in their original order. `p x` must return a value for every input element.
- `Seq.map f S` retains length and maps index `i` to `f (Seq.nth S i)`; `f` must return a value on every input element.

## Combining and pairing

- `Seq.reduce g z S` combines the ordered elements followed by one final `z`; empty input returns `z`. The current binding uses a balanced reduction with the base at the right end. `g` must be total and associative, including on intermediate values, so this has the value of a right fold with base `z`. This interface does not require `z` to be an identity or promise sequential callback evaluation.
- `Seq.reduce1 g S` has the same totality/associativity requirements, returns the sole element on a singleton, combines a longer sequence without a supplied base, and raises `Range` on empty input.
- `Seq.mapreduce f z g S` has the meaning of `Seq.reduce g z (Seq.map f S)` and inherits both sets of callback requirements. Argument order is mapper, base, combiner, sequence.
- `Seq.zip (A,B)` has length `min(length A,length B)` and element `(Seq.nth A i, Seq.nth B i)` at index `i`; excess elements of the longer input are omitted.
- `Seq.zipWith f (A,B)` has the meaning of `Seq.map f (Seq.zip (A,B))`; the callback receives a tuple and must return a value on each paired element. Neither operation requires equal input lengths.

## Indices and slices

- `Seq.enum S` has element `(i,Seq.nth S i)` at index `i` and unchanged length.
- `Seq.mapIdx f S` has the meaning of `Seq.map f (Seq.enum S)`; `f` receives the tuple `(index,element)` and must return a value on each such pair.
- `Seq.update (S,(i,x))` replaces only position `i` with `x`, preserving length and all other positions. It raises `Range` unless `0 <= i < n`.
- `Seq.inject (S,U)` applies the `(index,value)` entries of sequence `U`, preserving length and untouched positions. Every index must satisfy `0 <= i < n`, else `Range`. The public interface permits any one associated value to win when an index repeats. The current binding processes updates in order, so the last repeated update wins, and leaves `S` unchanged; do not promote this implementation choice into a general interface guarantee.
- `Seq.subseq S (start,len)` is the contiguous slice of length `len` beginning at `start`; the second number is a length, not an end index. This binding accepts exactly `0 <= start <= n` and `0 <= len <= n-start`; invalid slices raise `Range`. In particular `(n,0)` is an empty slice, including `(0,0)` on empty input.
- `Seq.take S i` keeps the first `i` elements; `Seq.drop S i` keeps the rest. `Seq.split S i` returns `(Seq.take S i, Seq.drop S i)`, whose concatenation equals `S`. All three require `0 <= i <= n`, including both endpoints, and raise `Range` otherwise.

## Ordering and search

- `Seq.sort cmp S` requires total `cmp` and returns a sorted permutation of `S`, retaining multiplicities. It is stable: occurrences considered `EQUAL` retain their prior relative order.
- `Seq.merge cmp (A,B)` requires total `cmp` and both inputs already sorted by `cmp`. It returns a sorted permutation of `Seq.append (A,B)`. The current binding takes an equal-key element from `A` before `B`; that tie rule is an implementation detail beyond the general merge contract.
- `Seq.search cmp x S` requires total `cmp` and `S` sorted by it. It returns `SOME i` for the first index satisfying `cmp (Seq.nth S i,x) = EQUAL`, otherwise `NONE`. Empty input has no matching index.

## One-level views

- Constructors are `Seq.Nil`, `Seq.Cons`, `Seq.Empty`, `Seq.Leaf`, `Seq.Node`, with exactly the types in the signature.
- `Seq.showl S` is `Seq.Nil` for empty input, otherwise `Seq.Cons (first,tail)`. The tail is another sequence, not another lview; nested lview patterns cannot inspect it directly.
- `Seq.hidel Seq.Nil` is empty; `Seq.hidel (Seq.Cons (x,tail))` has the meaning of `Seq.cons x tail`. Showing a hidden lview preserves that view; hiding a shown sequence preserves its elements and order.
- `Seq.showt S` in this binding returns `Seq.Empty` for `n=0`, `Seq.Leaf (Seq.nth S 0)` for `n=1`, and `Seq.Node (left,right)` otherwise, where `left` is the first `n div 2` elements and `right` the remainder. Both children are sequences, not tviews. The fixed split is a property of this binding.
- `Seq.hidet Seq.Empty` is empty; `Seq.hidet (Seq.Leaf x)` is the singleton `x`; `Seq.hidet (Seq.Node (A,B))` concatenates `A` then `B`. Hiding a shown sequence preserves its elements and order. Showing an arbitrary hidden view need not reproduce that view: a `Node` containing an empty sequence and a singleton becomes a `Leaf`.
- There are no `Seq.hd` or `Seq.tl` operations in this interface.

## Cost model

These work/span bounds describe array-based parallel sequences with constant-work, constant-span callbacks. The current binding executes sequentially and does not realize these parallel span bounds; they are not runtime measurements. Let `n,m` be input lengths, `k` the outer length for flatten and `N` its total inner length; logarithmic bounds describe nontrivial sizes with constant-time base cases.

| Operations | Work | Span |
|---|---|---|
| empty, singleton, nth, null, length, subseq, take, drop, split | O(1) | O(1) |
| fromList, toList | O(n) | O(n) |
| tabulate, rev, cons, map, enum, mapIdx, update | O(n) | O(1) |
| append | O(n+m) | O(1) |
| flatten | O(k+N) | O(log k) |
| toString, filter, reduce, reduce1, mapreduce | O(n) | O(log n) |
| equal | O(min(n,m)) | O(log min(n,m)) |
| zip, zipWith | O(min(n,m)) | O(1) |
| inject | O(n+m) | O(1) |
| sort | O(n log n) | O(log^2 n) |
| merge | O(n+m) | O(log(n+m)) |
| search | O(log n) | O(log n) |

Nonconstant callback costs must be included; no view-operation costs are specified here. Allocation limits and aggregate-length arithmetic can raise resource exceptions or `Overflow` on oversized constructions; these bounds do not promise unbounded sequence sizes.
