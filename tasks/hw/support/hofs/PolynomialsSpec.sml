structure PolynomialsSpec = struct
  fun close (x:real,y:real) =
    Real.isFinite x andalso Real.isFinite y andalso Real.abs(x-y) < 0.01
  val sameValues = ListPair.allEq close
end
