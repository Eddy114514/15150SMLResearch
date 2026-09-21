(* @contract sublistSum
 * sublistSum : int list * int -> int list option
 * REQUIRES: true
 * ENSURES: if return Some(int list ys), then ys sum to n. Else return NONE
 *)
fun sublistSum (L : int list, 0 : int) : int list option = SOME []
  | sublistSum ([]: int list, x : int) : int list option = NONE
  | sublistSum (l::ls : int list, x : int) : int list option =
      case sublistSum(ls, x - l) of
          NONE => sublistSum(ls, x)
        | SOME L => SOME (l::L)
