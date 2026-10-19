(* Generation budgets only: 0..8 integer coefficients, each in -16..16.
 * Probe 0..length for both differentiation and integration.
 * Observe four constants, including fixed distinct constants -2, 0, 3. *)
structure PolynomialsData = struct
  structure G = QCheck.Gen
  val coefficients = G.vector List.tabulate (G.range(0,8), G.range(~16,16))
  fun probes cs = List.tabulate(List.length cs + 1, fn i => i)
  (* Fixed examples supplement random inputs; probes still depend on length. *)
  val boundaries = List.map (fn (cs,constants) => (cs,constants,probes cs))
    [([],[~2,0,3]),
     ([4],[0,4]),
     ([4,2,24],[~2,0,3]),
     ([0,0,4],[0,4]),
     ([~4,0,4],[~4,4])]
  (* Quoted SML real literals also keep non-finite erroneous results printable. *)
  fun showReal x = Runner.quote (Real.toString x)

  structure Differentiate = struct
    val genInput = G.map (fn cs => (cs,probes cs)) coefficients
    val edges = List.map (fn (cs,_,ns) => (cs,ns)) boundaries
    fun showInput (cs,ns) = Runner.object
      [("coefficients",Runner.list Runner.int cs),
       ("exponents",Runner.list Runner.int ns)]
    val showOutput = Runner.list showReal
  end

  structure Integrate = struct
    val genInput = G.map
      (fn (cs,c) => (cs,[~2,0,3,c],probes cs))
      (G.zip(coefficients,G.range(~16,16)))
    val edges = boundaries
    fun showInput (cs,constants,ns) = Runner.object
      [("coefficients",Runner.list Runner.int cs),
       ("constants",Runner.list Runner.int constants),
       ("exponents",Runner.list Runner.int ns)]
    val showOutput = Runner.list (Runner.list showReal)
  end
end
