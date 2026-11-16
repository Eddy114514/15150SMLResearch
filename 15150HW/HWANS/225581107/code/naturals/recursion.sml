(* add : int * int -> int
 * REQUIRES: n, m >= 0
 * ENSURES: add (n, m) ==> n + m
 *)
fun add (0 : int, n : int) : int = n
  | add (m : int, n : int) : int = 1 + add (m - 1, n)

(* TEST CASES *)
val () = Test.int ("0 + 0", 0, add (0,0))
val () = Test.int ("0 + 5", 5, add (0,5))
val () = Test.int ("5 + 0", 5, add (5,0))
val () = Test.int ("15 + 150", 165, add (15,150))


(* mult : int * int -> int
 * REQUIRES: n, m >= 0
 * ENSURES: add (n,m) ==> n * m
 *)
(* Note: You may want to pattern-match for different cases. *)
fun mult (m : int, 0 : int) : int = 0
  | mult (m : int, n : int) : int = add (m, mult(m,n-1))


(* TEST CASES *)
(* Write test cases here *)
val () = Test.int ("0 * 0", 0, mult (0,0))
val () = Test.int ("0 * 5", 0, mult (0,5))
val () = Test.int ("5 * 0", 0, mult (5,0))
val () = Test.int ("15 * 150", 2250, mult (15,150))
val () = Test.int ("150 * 15", 2250, mult (150,15))

(* helpCheck : int*int -> bool
 * REQUIRES: n > 1, m >= 1
 * ENSURES: helpCheck (n,m) ==> true if n is rpime and false otherwise
 *)
fun helpCheck (n : int, m : int) : bool = (
  if m = 1 then true 
  else
    case n mod m of
    0 => false
  | _ => helpCheck (n, m-1)
  )

(* isPrime : int -> bool
 * REQUIRES: n > 1
 * ENSURES: isPrime n ==> true if n is prime and false otherwise
 *)
fun isPrime (n : int) : bool = helpCheck (n, n-1)



(* TEST CASES *)
(* Write test cases here *)

val () = Test.bool ("2", true, isPrime 2)
val () = Test.bool ("3", true, isPrime 3)
val () = Test.bool ("4", false, isPrime 4)
val () = Test.bool ("15", false, isPrime 15)
val () = Test.bool ("150", false, isPrime 150)