Shared productive stream descriptions:
datatype LazyCase.source = Finite of int list | Repeat of int * int list
Repeat(first,rest) repeats the nonempty period first::rest forever. Finite [] is empty. Qualify constructors with LazyCase.
- LazyModel.finiteLength : LazyCase.source -> int option. SOME n for finite length, NONE for infinite Repeat; no preconditions.
- LazyModel.at : LazyCase.source -> int -> int option. Value at index or NONE past finite end. Requires index >= 0.
- LazyModel.cycleAt : LazyCase.source -> int -> int option. Independent cycle value: empty stays empty; nonempty finite repeats; infinite input unchanged. Requires index >= 0.
- LazyModel.interleaveAt : LazyCase.source * LazyCase.source -> int -> int option. Alternate left first; when one ends, append all the remaining other input. Requires index >= 0.
- LazyModel.observe : (int -> 'a option) -> int -> 'a option list. At most max(0,probes) sequential fronts starting at index 0, stopping immediately after first NONE. Requires total valueAt at visited indices. [] at the budget boundary means observation stopped; [NONE] means a real exposed Empty. They are not interchangeable.
All target stream objects and counters are rebuilt per invocation. Counters count actual input thunk evaluations, not merely prefix length. Construction count is captured before any output front is exposed. For interleave, firstRightForces is the right counter immediately after exposing the first output front, or 0 when probes<=0. fronts then records all budgeted observations. This checks finite traces and selected laziness events, not general productivity or infinite-stream equality.
