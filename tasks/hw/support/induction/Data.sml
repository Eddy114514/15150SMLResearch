structure HwInductionData = struct
  structure G = QCheck.Gen
  val values = G.range (~3, 3)
  val lists = G.vector List.tabulate (G.range (0,20), values)
  val genInput = G.choose #[
    G.zip (values, lists),
    G.map (fn xs => (1, List.concat (List.map (fn x => [1,x]) xs))) lists,
    G.map (fn (x,n) => (x, List.tabulate(n, fn _ => x)))
      (G.zip(values, G.range(0,20)))]
  val edges = Generators.pairEdges @
    [(1,[1,1,2,1,3]), (2,[1,1,2,1,3]), (3,[1,5,1,5,0]),
     (0,[0,1,0,5,0,1,0,5,0]), (1,[1,2,1]), (0,[1,2]),
     (0,[1,1]), (valOf Int.minInt,[valOf Int.maxInt,valOf Int.minInt])]
  val showInput = Runner.pair (Runner.int,Runner.list Runner.int)
  structure Heads = struct
    val genInput = genInput
    val edges = edges
    val showInput = showInput
    val showOutput = Runner.int
  end
  structure Lists = struct
    val genInput = genInput
    val edges = edges
    val showInput = showInput
    val showOutput = Runner.list Runner.int
  end
end
