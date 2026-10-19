(* Generation budgets only. Sample counts and the seed come from config.json.
 * Function parameters -3..3 and probes -5..5 keep affine arithmetic small. *)
structure EncryptionData = struct
  structure G = QCheck.Gen
  fun triple gen = G.zip3(gen,gen,gen)
  val integer = G.range(~8,8)
  val text = G.map String.implode (G.vector List.tabulate
    (G.range(0,6),G.select #[#"a",#"b",#" ",#"\n",#"\"",#"\\"]))
  val integers = G.vector List.tabulate (G.range(0,5),integer)
  val function = G.zip(G.range(~3,3),G.range(~3,3))
  val baseProbes = [~2,~1,0,1,2]
  val probes = G.map (fn extra => baseProbes @ extra)
    (G.vector List.tabulate (G.range(0,3),G.range(~5,5)))
  val genInput = G.map
    (fn ((ints,strings,lists),(functions,probes)) =>
      {integers=ints,strings=strings,lists=lists,functions=functions,probes=probes})
    (G.zip(G.zip3(triple integer,triple text,triple integers),
           G.zip(triple function,probes)))

  (* All-equal payloads check that key identity does not depend on the value. *)
  val edges =
    [{integers=(0,0,0), strings=("","",""), lists=([],[],[]),
      functions=((0,0),(0,0),(0,0)), probes=baseProbes},
     {integers=(~1,0,1), strings=("a","","b"), lists=([~1],[],[0,1]),
      functions=((1,0),(0,1),(~1,~1)), probes=[~5,~1,0,1,5]},
     {integers=(7,7,7), strings=("same","same","same"),
      lists=([1,1],[1,1],[1,1]), functions=((2,~1),(2,~1),(2,~1)),
      probes=baseProbes},
     {integers=(~8,8,~8), strings=("\"","\\","\n"),
      lists=([0,0],[~1,~1],[~8,0,8]), functions=((~3,3),(3,~3),(0,~3)),
      probes=[~5,0,5,5]}]

  fun showTriple show = Runner.list show o EncryptionCase.values
  fun showFunction (a,b) = Runner.object [("a",Runner.int a),("b",Runner.int b)]
  fun showInput ({integers,strings,lists,functions,probes} : EncryptionCase.input) =
    Runner.object
      [("integers",showTriple Runner.int integers),
       ("strings",showTriple Runner.quote strings),
       ("lists",showTriple (Runner.list Runner.int) lists),
       ("functions",showTriple showFunction functions),
       ("probes",Runner.list Runner.int probes)]

  (* Matrix rows are decrypting keys; columns are encrypting keys (creation order).
   * Foreign columns are the other payload groups in output field order, 3 each. *)
  fun showObservations show {matrix,reused,foreign} = Runner.object
    [("matrix",Runner.list (Runner.list (Runner.option show)) matrix),
     ("reused_by_first_key",Runner.list (Runner.option show) reused),
     ("foreign_by_first_key",Runner.list (Runner.option show) foreign)]
  fun showOutput ({integers,strings,lists,functions} : EncryptionCase.output) =
    Runner.object
      [("integers",showObservations Runner.int integers),
       ("strings",showObservations Runner.quote strings),
       ("lists",showObservations (Runner.list Runner.int) lists),
       ("functions",showObservations (Runner.list Runner.int) functions)]
end
