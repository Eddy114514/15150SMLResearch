(* @solution *)
structure StreamRand : STREAMRAND =
struct
  fun bbs m s = Stream.delay (fn () => bbs' m s)
  and bbs' m s = 
  let
    val new = (s*s) mod m
  in
    Stream.Cons(new, bbs m new)
  end

end

(* @manual hw_bbs *)
(* @contract bbs
 * bbs : int -> int -> int Stream.t
 * REQUIRES: The modulus is the product of two primes.
 * ENSURES: The stream is infinite, starts with seed squared modulo modulus,
 * and each next value is the preceding value squared modulo modulus.
 * The wrapper observes max(0, probes) fronts; probes is not a bbs precondition.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int * int * int
  type output = int option list

  fun prime n = n >= 2 andalso
    let fun check d = d > n div d orelse
          (n mod d <> 0 andalso check (d+1))
    in check 2 end
  fun semiprime m = m >= 4 andalso
    let fun factor d = d <= m div d andalso
          (if m mod d = 0 then prime d andalso prime (m div d)
           else factor (d+1))
    in factor 2 end
  fun requires (m,_,_) = semiprime m

  fun ensures (m,seed,probes) fronts =
    let
      val modulus = IntInf.fromInt m
      fun recurrence _ [] = true
        | recurrence _ (NONE::_) = false
        | recurrence previous (SOME x::rest) =
            let val current = IntInf.fromInt x
            in current = (previous * previous) mod modulus
               andalso recurrence current rest
            end
    in List.length fronts = Int.max (0,probes)
       andalso recurrence (IntInf.fromInt seed) fronts
    end
end
