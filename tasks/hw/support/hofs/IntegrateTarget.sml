structure TargetAdapter = struct
  fun run (coefficients, constants, probes) =
    let val integrals = Target.integrate (PolynomialInput.polynomial coefficients)
    in List.map (fn c => List.map (integrals (real c)) probes) constants end
end
