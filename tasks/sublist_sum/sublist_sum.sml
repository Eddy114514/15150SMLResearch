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
