(* @contract flatten
 * flatten : int list list -> int list
 * REQUIRES: true
 * ENSURES: flatten LL ==>* F such that F is flattened with respect to LL
 *)
fun flatten ([] : int list list) : int list = []
  | flatten ([]::LL : int list list) : int list = flatten(LL)
  | flatten ((x::L)::LL : int list list) : int list = x :: flatten(L::LL)
