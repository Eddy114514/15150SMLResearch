(* @solution *)
(* @contract maxList
 * maxList : int list -> int
 * REQUIRES: xs not equal []
 * ENSURES: maxList(xs) -> n where n >= every elements of xs
 *)
fun maxList (xs : int list) : int =
    List.foldl Int.max (List.hd xs) (List.tl xs)
(* @manual list_max *)
(* @contract maxList
 * maxList : int list -> int
 * REQUIRES: xs not equal []
 * ENSURES: maxList(xs) -> n where n >= every elements of xs
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int list
  type output = int
  fun requires (input : input) : bool = let val xs = input in (not (null xs)) end
  fun ensures (input : input) (result : output) : bool = let val xs = input in (List.all (fn x => result >= x) xs andalso Spec.member result xs) end
end
