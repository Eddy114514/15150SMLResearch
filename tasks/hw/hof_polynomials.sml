(* @solution *)
type poly = int -> real

(* differentiate : poly -> poly
 * REQUIRES: p is a valid polynomial (i.e. p n = 0.0 for n<0 and p n = 0.0 for
 * all but finitely many n)
 * ENSURES: differentiate p = p', where p' is the derivative of p
 *)
fun differentiate (p : poly) : poly = 
    fn n => real(n+1) * p(n+1)

(* integrate : poly -> (real -> poly)
 * REQUIRES: p is a valid polynomial (i.e. p n = 0.0 for n<0 and p n = 0.0 for
 * all but finitely many n)
 * ENSURES: integrate p = P, where P(c) is the antiderivative of p with constant
 * of integration c
 * Alternatively, you could say differentiate ((integrate p) c) = p for all
 * c : real
 *)
fun integrate (p : poly) : real -> poly =
    fn c =>
      fn 0 => c
       | n => p(n-1) / real(n)

(* @manual hw_hof_differentiate *)
(* @contract differentiate
 * differentiate : (int -> real) -> (int -> real)
 * REQUIRES: The original polynomial has finite support and maps negative
 * exponents to zero. The finite coefficient description guarantees both.
 * Functional projection only: at each supplied exponent, compare the returned
 * coefficient to the derivative using Real.==. The original gives no numeric
 * tolerance. Finite probes cannot establish the original function equality.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int list * int list
  type output = real list
  fun requires (_ : input) = true
  fun ensures (cs,probes) result =
    PolynomialsSpec.sameValues(result,List.map (PolynomialsSpec.derivative cs) probes)
end

(* @manual hw_hof_integrate *)
(* @contract integrate
 * integrate : (int -> real) -> (real -> (int -> real))
 * REQUIRES: The original polynomial has finite support and maps negative
 * exponents to zero. The finite coefficient description guarantees both.
 * Functional projection only: each supplied constant gives one row of
 * antiderivative coefficients at the supplied exponents, including that
 * constant at exponent zero. Use Real.==; the original gives no tolerance.
 * Finite probes cannot establish equality at all exponents and constants.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = int list * int list * int list
  type output = real list list
  fun requires (_ : input) = true
  fun ensures (cs,constants,probes) result =
    ListPair.allEq PolynomialsSpec.sameValues
      (result,List.map (fn c => List.map (PolynomialsSpec.integral cs c) probes) constants)
end
