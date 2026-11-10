Finite list reference operations (independent of Target).
- SublistModel.subsequence : ''a list -> ''a list -> bool. subsequence ys xs tests order-preserving selection of input positions, respecting multiplicity. No preconditions.
- SublistModel.sum : int list -> IntInf.int. Mathematical sum; no preconditions.
- SublistModel.selectionSums : int list -> IntInf.int list. All positional selection sums, including the empty selection and duplicates. No semantic length restriction; exponential cost. No particular solution witness is selected.
