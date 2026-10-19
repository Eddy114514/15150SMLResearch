(* A printable description of a finite rose and a total reducer family. *)
structure RoseFoldCase = struct
  datatype rose = Rose of int * rose list
  datatype reducer = Append of string | Prepend of string | Bracket
  fun apply (Append sep) (x,acc) = acc ^ sep ^ Int.toString x
    | apply (Prepend sep) (x,acc) = Int.toString x ^ sep ^ acc
    | apply Bracket (x,acc) = "(" ^ Int.toString x ^ ":" ^ acc ^ ")"
end

(* Convert the finite coefficient description for calls to the original targets. *)
structure PolynomialInput = struct
  fun polynomial coefficients n =
    if n < 0 orelse n >= List.length coefficients then 0.0
    else real (List.nth (coefficients,n))
end
