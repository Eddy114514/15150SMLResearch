structure PolynomialsSpec = struct
  fun sameCoefficient (x:real,y:real) =
    Real.== (x,y)
  val sameValues = ListPair.allEq sameCoefficient
  (* Reference coefficients, independent of the target's returned closures. *)
  fun derivative cs n =
    if n < 0 orelse n >= List.length cs - 1 then 0.0
    else real (List.nth(cs,n+1)) * real (n+1)
  fun integral cs c n =
    if n < 0 then 0.0
    else if n = 0 then real c
    else if n > List.length cs then 0.0
    else real (List.nth(cs,n-1)) / real n
end
