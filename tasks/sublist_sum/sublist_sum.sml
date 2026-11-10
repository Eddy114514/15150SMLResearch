(* @solution *)
(* @contract sublistSum
 * sublistSum : int list * int -> int list option
 * REQUIRES: true
 * ENSURES: sublistSum(L,n) ==>* SOME(L') where L' is a sublist of L which sums
 *          to n. sublistSum(L,n) ==>* NONE if there is no such sublist
 *)
fun sublistSum (L : int list, 0 : int) : int list option = SOME []
  | sublistSum ([]: int list, x : int) : int list option = NONE
  | sublistSum (l::ls : int list, x : int) : int list option =
      case sublistSum(ls, x - l) of
          NONE => sublistSum(ls, x)
        | SOME L => SOME (l::L)
(* @manual sublist_sum *)
(* @contract sublistSum
 * sublistSum : int list * int -> int list option
 * REQUIRES: true
 * ENSURES: sublistSum(L,n) ==>* SOME(L') where L' is a sublist of L which sums
 *          to n. sublistSum(L,n) ==>* NONE if there is no such sublist
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int list * int
  type output = int list option
  fun requires (input : input) : bool = let val (L, n) = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val (L, n) = input in (let
      fun subseq [] _ = true
        | subseq _ [] = false
        | subseq (ys as y::rest) (x::xs) =
            if y = x then subseq rest xs else subseq ys xs
      fun possible [] k = k = 0
        | possible (x::xs) k = possible xs k orelse possible xs (k - IntInf.fromInt x)
    in case result of
      NONE => not (possible L (IntInf.fromInt n))
    | SOME ys => subseq ys L andalso
        List.foldl (fn (x,s) => IntInf.fromInt x + s) 0 ys = IntInf.fromInt n
    end) end
end
