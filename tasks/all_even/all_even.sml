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
