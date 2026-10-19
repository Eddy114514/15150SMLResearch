(* Generation budgets: 0..8 positions, values -3..3, at most 256 partitions.
 * Seed and sample counts use the existing config.json settings. *)
structure PartitionData = struct
  structure G = QCheck.Gen
  val value = G.range(~3,3)
  val values = G.vector List.tabulate (G.range(0,8),value)
  val elementPredicate = G.choose
    #[G.select #[CpsCase.Any,CpsCase.Even,CpsCase.Positive],
      G.map CpsCase.Equals value]
  val predicate = G.choose
    #[G.map (PartitionCase.Sum o IntInf.fromInt) (G.range(~24,24)),
      G.map PartitionCase.Length (G.range(0,9)),
      G.map PartitionCase.All elementPredicate]
  fun describes useSum xs =
    if useSum then PartitionCase.Sum (PartitionCase.sum xs)
    else PartitionCase.Length (List.length xs)
  val witness = G.map
    (fn (entries,leftSum,rightSum) =>
      let val xs = List.map #1 entries
          val left = List.map #1 (List.filter #2 entries)
          val right = List.map #1 (List.filter (not o #2) entries)
      in (xs,describes leftSum left,describes rightSum right) end)
    (G.zip3(G.vector List.tabulate (G.range(0,8),G.zip(value,G.flip)),G.flip,G.flip))
  val impossible = G.map
    (fn xs => (xs,PartitionCase.Length (List.length xs + 1),
                   PartitionCase.All CpsCase.Any)) values
  val genInput = G.choose #[witness,G.zip3(values,predicate,predicate),impossible]
  val edges =
    [([],PartitionCase.Length 0,PartitionCase.Sum 0),
     ([],PartitionCase.Length 1,PartitionCase.All CpsCase.Any),
     ([1,1],PartitionCase.Length 1,PartitionCase.Sum 1),
     ([1,2,3],PartitionCase.Sum 4,PartitionCase.Length 1),
     ([0,~1,2],PartitionCase.All CpsCase.Positive,PartitionCase.Sum ~1),
     ([2,~2],PartitionCase.Length 0,PartitionCase.Sum 0),
     ([~1,0,2],PartitionCase.All CpsCase.Positive,PartitionCase.All CpsCase.Even),
     ([1,2,1],PartitionCase.Sum 2,PartitionCase.Length 1),
     ([4],PartitionCase.All (CpsCase.Equals 4),PartitionCase.Length 0),
     ([1,2],PartitionCase.Length 2,PartitionCase.Length 2)]

  fun showPredicate (PartitionCase.Sum n) = Runner.object
        [("sum",Runner.quote (IntInf.toString n))]
    | showPredicate (PartitionCase.Length n) = Runner.object [("length",Runner.int n)]
    | showPredicate (PartitionCase.All CpsCase.Any) = Runner.quote "All Any"
    | showPredicate (PartitionCase.All CpsCase.Even) = Runner.quote "All Even"
    | showPredicate (PartitionCase.All CpsCase.Positive) = Runner.quote "All Positive"
    | showPredicate (PartitionCase.All (CpsCase.Equals x)) =
        Runner.object [("all_equal",Runner.int x)]
  fun showInput (xs,left,right) = Runner.object
    [("values",Runner.list Runner.int xs),
     ("left_predicate",showPredicate left),("right_predicate",showPredicate right)]
  val showOutput = Runner.option (fn (left,(count,sum)) => Runner.object
    [("left_evidence",Runner.list Runner.int left),
     ("right_evidence",Runner.object
       [("length",Runner.int count),("sum",Runner.quote (IntInf.toString sum))])])
end
