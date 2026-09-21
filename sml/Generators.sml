(* Fixed boundary samples followed by generators from the pinned QCheck library. *)
structure Generators = struct
  structure G = QCheck.Gen

  val intGen : int G.gen = G.range (~100, 100)
  val listGen : int list G.gen =
    G.vector List.tabulate (G.range (0, 20), intGen)
  val listListGen : int list list G.gen =
    G.vector List.tabulate (G.range (0, 20), listGen)

  val intEdges = [0, 1, ~1, valOf Int.minInt, valOf Int.maxInt, ~100, 100]
  val listEdges =
    [[], [0], [1], [~1], [1, 1], [1, 2, 3], [3, 2, 1],
     [~3, 0, 2], [0, 0, 0], [~1, ~1, 2, 2], [2, ~1, 2, ~1]]
  val pairEdges =
    [(0, []), (1, []), (0, [0]), (1, [1]), (2, [1]),
     (1, [1, 1]), (2, [1, 2, 3]), (2, [3, 2, 1]),
     (0, [~3, 0, 2]), (~1, [~1, ~1, 2, 2]), (2, [2, ~1, 2, ~1])]
  val listListEdges =
    [[], [[]], [[], []], [[0]], [[1, 2], [3, 4]],
     [[], [1], [], [2, 3], []], [[1, 1], [1]], [[~3, 0], [2, ~1]],
     [[], [], [0]], [[valOf Int.minInt], [valOf Int.maxInt]], [[3, 2], [1, 0]]]

  fun sample edges inputGen {seed, count} = let
    val edgePrefix = List.take (edges, Int.min (count, List.length edges))
    val remaining = count - List.length edgePrefix
    (* This pinned QCheck version exposes its real-valued RNG state. *)
    val (randomInputs, _) =
      G.vector List.tabulate (G.lift remaining, inputGen) (Real.fromInt seed)
  in edgePrefix @ randomInputs end

  fun randomList sortLists : int list G.gen =
    if sortLists then G.map (ListMergeSort.sort (op >)) listGen else listGen

  fun ints {seed, count} : int list =
    sample intEdges intGen {seed=seed, count=count}

  fun lists {seed, count, sortLists} : int list list =
    sample listEdges (randomList sortLists) {seed=seed, count=count}

  fun pairs {seed, count, sortLists} : (int * int list) list =
    sample pairEdges (G.zip (intGen, randomList sortLists)) {seed=seed, count=count}

  fun listIntPairs options : (int list * int) list =
    List.map (fn (x, xs) => (xs, x)) (pairs options)

  fun listLists {seed, count} : int list list list =
    sample listListEdges listListGen {seed=seed, count=count}
end
