(* The basic tasks retain their original QCheck distributions and edge order. *)
structure BasicData = struct
  structure G = QCheck.Gen

  val listGen : int list G.gen =
    G.vector List.tabulate (G.range (0, 20), Generators.intGen)
  val listListGen : int list list G.gen =
    G.vector List.tabulate (G.range (0, 20), listGen)

  val intEdges = [0, 1, ~1, valOf Int.minInt, valOf Int.maxInt, ~100, 100]
  val listEdges =
    [[], [0], [1], [~1], [1, 1], [1, 2, 3], [3, 2, 1],
     [~3, 0, 2], [0, 0, 0], [~1, ~1, 2, 2], [2, ~1, 2, ~1]]
  val listListEdges =
    [[], [[]], [[], []], [[0]], [[1, 2], [3, 4]],
     [[], [1], [], [2, 3], []], [[1, 1], [1]], [[~3, 0], [2, ~1]],
     [[], [], [0]], [[valOf Int.minInt], [valOf Int.maxInt]], [[3, 2], [1, 0]]]

  structure Flatten = struct
    val genInput = listListGen
    val edges = listListEdges
    val showInput = Runner.list (Runner.list Runner.int)
    val showOutput = Runner.list Runner.int
  end

  structure IntBool = struct
    val genInput = Generators.intGen
    val edges = intEdges
    val showInput = Runner.int
    val showOutput = Runner.bool
  end

  structure SublistSum = struct
    val genInput = G.map (fn (x, xs) => (xs, x)) (G.zip (Generators.intGen, listGen))
    val edges = List.map (fn (x, xs) => (xs, x)) Generators.pairEdges
    val showInput = Runner.pair (Runner.list Runner.int, Runner.int)
    val showOutput = Runner.option (Runner.list Runner.int)
  end

  structure ListMax = struct
    val genInput = listGen
    val edges = listEdges
    val showInput = Runner.list Runner.int
    val showOutput = Runner.int
  end

  structure AllEven = struct
    val genInput = listGen
    val edges = listEdges
    val showInput = Runner.list Runner.int
    val showOutput = Runner.bool
  end
end
