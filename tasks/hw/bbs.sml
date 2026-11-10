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
 * Functional projection only: the wrapper observes max(0, probes) fronts.
 * These observations do not establish infinitude or general productivity.
 * The probe count is not a bbs precondition.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int * int * int
  type output = int option list

  fun requires (m,_,_) = BbsModel.semiprime m

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
