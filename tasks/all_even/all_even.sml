(* @solution *)
(* @contract isEven
 * isEven : int -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if x is divisible by 2.
 *)
fun isEven (x : int) : bool = x mod 2 = 0

(* @contract allEven
 * allEven : int list -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if every element of xs is even,
 * in the sense defined by the isEven contract. For the empty list the result
 * is true.
 *)
fun allEven (xs : int list) : bool = List.all isEven xs
(* @manual is_even *)
(* @contract isEven
 * isEven : int -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if x is divisible by 2.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int
  type output = bool
  fun requires (input : input) : bool = let val x = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val x = input in (result = (x mod 2 = 0)) end
end
(* @manual all_even *)
(* @contract allEven
 * allEven : int list -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if every element of xs is even,
 * in the sense defined by the isEven contract. For the empty list the result
 * is true.
 *)
functor ManualContract (Helpers : sig
  val isEven : (int) -> (bool)
end) = struct
  type input = int list
  type output = bool
  fun requires (input : input) : bool = let val xs = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val xs = input in (result = List.all Helpers.isEven xs) end
end
