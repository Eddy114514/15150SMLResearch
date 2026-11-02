(* Sequential list generation before Seq.fromList preserves QCheck RNG order.
 * Matrices share dimensions by construction. Budgets are sampling choices. *)
structure HomeworkSequenceData = struct
  structure G = QCheck.Gen
  val value = G.range (~3,3)
  val values = G.vector List.tabulate (G.range (0,20), value)
  fun identify xs = ListPair.zip (xs,List.tabulate (List.length xs, fn i => i))
  fun fromRows rows = Seq.fromList (List.map Seq.fromList rows)
  fun showSequence f = Runner.sequence Seq.toList f
  val showElement = Runner.pair (Runner.int,Runner.int)
  val edges = [[], [1], [1,1], [2,1,2,1], [3,1,2], [~3,0,3],
               [valOf Int.minInt,valOf Int.maxInt,valOf Int.minInt]]

  val matrixGen = Generators.bind (G.zip (G.range (0,6),G.range (0,6)))
    (fn (rows,cols) => Generators.sequence Seq.fromList
      (G.lift rows,Generators.sequence Seq.fromList (G.lift cols,value)))

  structure Transpose = struct
    val genInput = matrixGen
    val edges = List.map fromRows
      [[], [[]], [[],[]], [[1]], [[1,2,3]], [[1],[2],[3]],
       [[1,2],[3,4]], [[1,2,3],[4,5,6]], [[1,1],[1,1]],
       [[valOf Int.minInt,valOf Int.maxInt]]]
    val showInput = showSequence (showSequence Runner.int)
    val showOutput = showInput
  end
  structure CollectInt = struct
    val genInput = G.map Seq.fromList values
    val edges = List.map Seq.fromList edges
    val showInput = showSequence Runner.int
    val showOutput = showSequence (showSequence Runner.int)
  end
  structure CollectKey = struct
    val genInput = G.map (Seq.fromList o identify) values
    val edges = List.map (Seq.fromList o identify) edges
    val showInput = showSequence showElement
    val showOutput = showSequence (showSequence showElement)
  end
  structure UniqueInt = struct
    val genInput = CollectInt.genInput
    val edges = CollectInt.edges
    val showInput = CollectInt.showInput
    val showOutput = showInput
  end
end
