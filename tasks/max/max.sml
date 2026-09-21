(* @contract maxList
 * maxList : int list -> int
 * REQUIRES: xs not equal []
 * ENSURES: maxList(xs) -> n where n >= every elements of xs
 *)
fun maxList (xs : int list) : int =
    List.foldl Int.max (List.hd xs) (List.tl xs)
