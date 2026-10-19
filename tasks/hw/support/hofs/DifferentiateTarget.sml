structure TargetAdapter = struct
  fun run (coefficients, probes) =
    let val derivative = Target.differentiate (PolynomialInput.polynomial coefficients)
    in List.map derivative probes end
end
