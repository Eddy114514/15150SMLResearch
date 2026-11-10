(* @solution *)
(* @contract flatten
 * flatten : int list list -> int list
 * REQUIRES: true
 * ENSURES: flatten LL ==>* F such that F is flattened with respect to LL
 *)
fun flatten ([] : int list list) : int list = []
  | flatten ([]::LL : int list list) : int list = flatten(LL)
  | flatten ((x::L)::LL : int list list) : int list = x :: flatten(L::LL)
(* @manual flatten *)
(* @contract flatten
 * flatten : int list list -> int list
 * REQUIRES: true
 * ENSURES: flatten LL ==>* F such that F is flattened with respect to LL
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int list list
  type output = int list
  fun requires (input : input) : bool = let val LL = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val LL = input in (result = List.concat LL) end
end
