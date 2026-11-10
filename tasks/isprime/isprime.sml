(* @solution *)
(* @contract isPrime
 * isPrime : int -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if x is at least 2 and the only
 * positive integer divisors of x are 1 and x.
 *)
fun isPrime (x : int) : bool =
    if x < 2 then false
    else if x = 2 then true
    else if x mod 2 = 0 then false
    else
        let
            fun checkDivisor d =
                if d > x div d then true
                else if x mod d = 0 then false
                else checkDivisor (d + 2)
        in
            checkDivisor 3
        end
(* @manual isprime *)
(* @contract isPrime
 * isPrime : int -> bool
 * REQUIRES: true
 * ENSURES: The result is true if and only if x is at least 2 and the only
 * positive integer divisors of x are 1 and x.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int
  type output = bool
  fun requires (input : input) : bool = let val x = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val x = input in (result = (x >= 2 andalso Spec.forallRange (fn d => x mod d <> 0) (2, x div 2))) end
end
