(* Budgets: depth <= 3 (<= 8 leaves), values -3..3. These are not REQUIRES. *)
structure CpsData = struct
  structure G = QCheck.Gen
  val valueGen = G.range (~3,3)
  val predicateGen = G.choose #[G.lift CpsCase.Any,G.lift CpsCase.Even,
    G.lift CpsCase.Positive,G.map CpsCase.Equals valueGen]
  val equalityGen = G.select #[CpsCase.Exact,CpsCase.Parity]
  fun treeGen 0 = G.map CpsCase.Tip valueGen
    | treeGen n = G.choose #[G.map CpsCase.Tip valueGen,
        G.map CpsCase.Fork (G.zip (treeGen (n-1),treeGen (n-1)))]
  fun showTree (CpsCase.Tip x) = Runner.object [("tag",Runner.quote "Leaf"),("value",Runner.int x)]
    | showTree (CpsCase.Fork (l,r)) = Runner.object
        [("tag",Runner.quote "Branch"),("left",showTree l),("right",showTree r)]
  fun showPredicate CpsCase.Any = Runner.quote "Any"
    | showPredicate CpsCase.Even = Runner.quote "Even"
    | showPredicate CpsCase.Positive = Runner.quote "Positive"
    | showPredicate (CpsCase.Equals x) = Runner.object [("Equals",Runner.int x)]
  fun showEquality CpsCase.Exact = Runner.quote "Exact"
    | showEquality CpsCase.Parity = Runner.quote "Parity"
  val treeEdges = [CpsCase.Tip 0,CpsCase.Tip 1,
    CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 2),
    CpsCase.Fork (CpsCase.Tip 1,CpsCase.Tip 1),
    CpsCase.Fork (CpsCase.Tip ~1,CpsCase.Fork (CpsCase.Tip 2,CpsCase.Tip 3))]
  structure FindOne = struct
    val genInput = G.zip (predicateGen,treeGen 3)
    val edges = List.concat (List.map (fn t =>
      List.map (fn p => (p,t)) [CpsCase.Any,CpsCase.Even,CpsCase.Equals 9]) treeEdges)
    fun showInput (p,t) = Runner.object [("predicate",showPredicate p),("tree",showTree t)]
    val showOutput = Runner.option Runner.int
  end
  structure FindN = struct
    val genInput = Generators.bind (G.zip3 (predicateGen,equalityGen,treeGen 3))
      (fn (p,e,t) => G.map (fn n => (p,e,t,n))
        (G.range (0,List.length (CpsModel.leaves t)+1)))
    val edges = List.concat (List.map (fn t =>
      List.concat (List.map (fn e => List.map (fn n => (CpsCase.Any,e,t,n))
        [0,1,2,3]) [CpsCase.Exact,CpsCase.Parity])) treeEdges)
      @ [(CpsCase.Equals 9,CpsCase.Exact,CpsCase.Tip 1,1)]
    fun showInput (p,e,t,n) = Runner.object [("predicate",showPredicate p),
      ("equality",showEquality e),("tree",showTree t),("n",Runner.int n)]
    val showOutput = Runner.option (Runner.list Runner.int)
  end
end
