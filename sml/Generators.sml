(* Fixed boundary samples followed by generators from the pinned QCheck library. *)
structure Generators = struct
  structure G = QCheck.Gen

  (* Dependent inputs consume the next generator with the advanced state. *)
  fun bind gen next seed =
    let val (value, seed') = gen seed
    in next value seed' end

  val intGen : int G.gen = G.range (~100, 100)

  (* Gen.vector advances mutable RNG state in its callback: tabulate sequentially,
   * then construct the chosen sequence representation from the finished list. *)
  fun sequence fromList (lengthGen, elementGen) =
    G.map fromList (G.vector List.tabulate (lengthGen, elementGen))

  val pairEdges =
    [(0, []), (1, []), (0, [0]), (1, [1]), (2, [1]),
     (1, [1, 1]), (2, [1, 2, 3]), (2, [3, 2, 1]),
     (0, [~3, 0, 2]), (~1, [~1, ~1, 2, 2]), (2, [2, ~1, 2, ~1])]
  fun sample edges inputGen {seed, count} = let
    val edgePrefix = List.take (edges, Int.min (count, List.length edges))
    val remaining = count - List.length edgePrefix
    (* This pinned QCheck version exposes its real-valued RNG state. *)
    val (randomInputs, _) =
      G.vector List.tabulate (G.lift remaining, inputGen) (Real.fromInt seed)
  in edgePrefix @ randomInputs end
end
