(* Runtime-only generators. Sampling bounds are not contract preconditions. *)
structure PolysortData = struct
  structure G = QCheck.Gen
  val value = G.range (~3,3)
  val values = G.vector List.tabulate (G.range (0,20), value)
  val pivotValues = G.zip (value,values)
  fun identify xs = ListPair.zip (xs, List.tabulate (List.length xs, fn i => i))
  fun showElement (key,id) = Runner.list Runner.int [key,id]
  fun showPair show (left,right) = "[" ^ show left ^ "," ^ show right ^ "]"
  val listEdges =
    [[], [2], [2,2], [2,1], [2,1,2,1], [~3,0,3], [3,2,1],
     [valOf Int.minInt, valOf Int.maxInt, valOf Int.minInt]]
  val pivotEdges =
    [(2,[]), (2,[2]), (2,[1,1]), (2,[3,1,2]), (3,[2,1]),
     (0,[~1,0,1,0,~1]), (valOf Int.minInt,[valOf Int.minInt]),
     (valOf Int.maxInt,[valOf Int.maxInt,0])]
  (* One family explicitly contains the pivot, supplementing the small domain. *)
  val withPivot = G.map (fn (p,xs) => (p,p :: xs @ [p])) pivotValues

  structure PivotInt = struct
    val genInput = G.choose #[pivotValues,withPivot]
    val edges = pivotEdges
    val showInput = Runner.pair
    val showOutput = showPair (Runner.list Runner.int)
  end
  structure PivotKey = struct
    val genInput = G.map (fn (p,xs) => ((p,~1),identify xs)) PivotInt.genInput
    val edges = List.map (fn (p,xs) => ((p,~1),identify xs)) pivotEdges
    fun showInput (p,xs) = "[" ^ showElement p ^ "," ^ Runner.list showElement xs ^ "]"
    val showOutput = showPair (Runner.list showElement)
  end
  structure SortInt = struct
    val genInput = values
    val edges = listEdges
    val showInput = Runner.list Runner.int
    val showOutput = showInput
  end
  structure SortKey = struct
    val genInput = G.map identify values
    val edges = List.map identify listEdges
    val showInput = Runner.list showElement
    val showOutput = showInput
  end
end
