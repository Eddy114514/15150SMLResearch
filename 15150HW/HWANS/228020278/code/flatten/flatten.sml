(* flatten : int list list -> int list
 * REQUIRES: true
 * ENSURES: flatten LL ==>* F such that F is flattened with respect to LL
 *)
fun flatten ([] : int list list) : int list = []
  | flatten ([]::LL : int list list) : int list = flatten(LL)
  | flatten ((x::L)::LL : int list list) : int list = x :: flatten(L::LL)

(*
val [] = flatten []
val [] = flatten [[]]
val [15 , 150] = flatten [[15 , 150]]
val [15150] = flatten [[15150]] 
val [15 , 15 , 0] = flatten [[] , [15 , 15] , [] , [] , [] , [0]] 
val [1 , 5 , 1 , 5 , 0] = flatten [[1 , 5] , [1] , [] , [5 , 0]] 
*)