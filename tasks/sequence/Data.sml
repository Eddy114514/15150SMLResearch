(* Runtime-only data adapters. Random sequence lengths are 0..4; nested lengths
 * are bounded independently. Tree generation decreases a depth budget of 3.
 * These sampling budgets do not restrict the natural-language contracts. *)
structure SequenceCases = struct
  structure G = QCheck.Gen
  val lengthGen = G.range (0, 4)
  val intGen = G.range (~3, 3)
  fun sequence elementGen = Generators.sequence Seq.fromList (lengthGen, elementGen)
  fun showSequence showElement = Runner.sequence Seq.toList showElement

  val intListEdges =
    [[], [0], [1, 1], [1, 2, 3], [2, ~1, 2, 0],
     [1, 1, 2], [1, 2, 2], [valOf Int.minInt, valOf Int.maxInt]]
  val intSequenceGen : int Seq.seq G.gen = sequence intGen

  structure ReverseInt = struct
    val genInput : int Seq.seq G.gen = intSequenceGen
    val edges = List.map Seq.fromList intListEdges
    val showInput = showSequence Runner.int
    val showOutput = showSequence Runner.int
  end

  structure ReverseBool = struct
    val genInput : bool Seq.seq G.gen = sequence G.flip
    val edges = List.map Seq.fromList
      [[], [false], [true], [true, false], [false, false, true], [true, false, true, true]]
    val showInput = showSequence Runner.bool
    val showOutput = showSequence Runner.bool
  end

  structure FlattenInt = struct
    val genInput : int Seq.seq Seq.seq G.gen = sequence intSequenceGen
    val edges = List.map (Seq.fromList o List.map Seq.fromList)
      [[], [[]], [[], []], [[1, 2], [3]], [[], [1, 2], [], [2, 1]],
       [[1, 1], [2]], [[valOf Int.minInt], [valOf Int.maxInt]]]
    val showInput = showSequence (showSequence Runner.int)
    val showOutput = showSequence Runner.int
  end

  fun treeGen 0 = G.map Tree.Leaf intGen
    | treeGen depth = G.choose
        #[G.map Tree.Leaf intGen,
          G.map Tree.Node (G.zip (treeGen (depth - 1), treeGen (depth - 1)))]

  fun showTree (Tree.Leaf value) =
        Runner.object [("tag", Runner.quote "Leaf"), ("value", Runner.int value)]
    | showTree (Tree.Node (left, right)) =
        Runner.object [("tag", Runner.quote "Node"),
                       ("left", showTree left), ("right", showTree right)]

  structure LeafFlags = struct
    val genInput : Tree.tree Seq.seq G.gen = sequence (treeGen 3)
    val edges = List.map Seq.fromList
      [[], [Tree.Leaf 0], [Tree.Node (Tree.Leaf 1, Tree.Leaf 2)],
       [Tree.Leaf ~1, Tree.Node (Tree.Leaf 0, Tree.Leaf 1), Tree.Leaf 2],
       [Tree.Node (Tree.Node (Tree.Leaf 0, Tree.Leaf 1), Tree.Leaf 2),
        Tree.Leaf (valOf Int.maxInt)]]
    val showInput = showSequence showTree
    val showOutput = showSequence Runner.bool
  end

  structure ListToSeq = struct
    val genInput : int list G.gen = G.vector List.tabulate (lengthGen, intGen)
    val edges = intListEdges
    val showInput = Runner.list Runner.int
    val showOutput = showSequence Runner.int
  end
end
