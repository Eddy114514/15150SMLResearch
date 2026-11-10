(* @solution *)
(* sublistSum : int list * int -> int list option
 * REQUIRES: true
 * ENSURES: sublistSum(L,n) ==>* SOME(L') where L' is a sublist of L which sums
 *          to n. sublistSum(L,n) ==>* NONE if there is no such sublist
 *)
fun sublistSum (L : int list, 0 : int) : int list option = SOME []
  | sublistSum ([]: int list, x : int) : int list option = NONE
  | sublistSum (l::ls : int list, x: int) : int list option =
    case sublistSum(ls, x - l) of
        NONE => sublistSum(ls, x)
       |SOME L =>  SOME (l::L)

(* @manual hw_sublist_sum *)
(* @contract sublistSum
 * sublistSum : int list * int -> int list option
 * REQUIRES: true
 * ENSURES: SOME ys is an order-preserving selection of input positions
 * whose mathematical sum is n. NONE means no such selection exists.
 * The empty selection is allowed. No particular witness is preferred.
 * IntInf protects the oracle, not the student's bounded int arithmetic.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int list * int
  type output = int list option
  fun requires (_ : input) = true

  fun ensures (xs, n) result =
    case result of
      SOME ys => SublistModel.subsequence ys xs andalso SublistModel.sum ys = IntInf.fromInt n
    | NONE => not (List.exists (fn s => s = IntInf.fromInt n) (SublistModel.selectionSums xs))
end
