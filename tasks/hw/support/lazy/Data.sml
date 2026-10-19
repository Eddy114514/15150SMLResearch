(* Sampling budgets, not preconditions: finite lengths 0..5, periods 1..4,
 * integers -4..4, and 0..12 output-front probes. *)
structure LazyData = struct
  structure G = QCheck.Gen
  val valueGen = G.range (~4,4)
  val finiteGen = G.map LazyCase.Finite
    (G.vector List.tabulate (G.range (0,5),valueGen))
  val repeatedGen = G.map LazyCase.Repeat (G.zip
    (valueGen,G.vector List.tabulate (G.range (0,3),valueGen)))
  val sourceGen = G.choose #[finiteGen,repeatedGen]
  val probesGen = G.range (0,12)

  fun showSource (LazyCase.Finite xs) = Runner.object
        [("finite",Runner.list Runner.int xs)]
    | showSource (LazyCase.Repeat (first,rest)) = Runner.object
        [("repeat",Runner.list Runner.int (first::rest))]
  fun showOutput (constructionForces,fronts) = Runner.object
    [("construction_forces",Runner.int constructionForces),
     ("fronts",Runner.list (Runner.option Runner.int) fronts)]

  structure Cycle = struct
    val genInput = G.zip (sourceGen,probesGen)
    val edges = [(LazyCase.Finite [],0),(LazyCase.Finite [],1),
      (LazyCase.Finite [1,5,0],11),(LazyCase.Finite [3],4),
      (LazyCase.Repeat (2,[7]),7),(LazyCase.Finite [9],0)]
    fun showInput (source,probes) = Runner.object
      [("source",showSource source),("probes",Runner.int probes)]
    val showOutput = showOutput
  end

  structure Interleave = struct
    val genInput = G.zip3 (sourceGen,sourceGen,probesGen)
    val edges = [(LazyCase.Finite [],LazyCase.Finite [],0),
      (LazyCase.Finite [],LazyCase.Finite [],1),
      (LazyCase.Finite [1],LazyCase.Finite [2],1),
      (LazyCase.Finite [1,1,5,0],LazyCase.Finite [5],8),
      (LazyCase.Finite [],LazyCase.Finite [3,4],4),
      (LazyCase.Finite [3,4],LazyCase.Finite [],4),
      (LazyCase.Repeat (1,[2]),LazyCase.Finite [9],8),
      (LazyCase.Finite [9],LazyCase.Repeat (1,[2]),8),
      (LazyCase.Repeat (1,[2]),LazyCase.Repeat (3,[4]),9)]
    fun showInput (left,right,probes) = Runner.object
      [("left",showSource left),("right",showSource right),
       ("probes",Runner.int probes)]
    fun showOutput (constructionForces,firstRightForces,fronts) = Runner.object
      [("construction_forces",Runner.int constructionForces),
       ("first_right_forces",Runner.int firstRightForces),
       ("fronts",Runner.list (Runner.option Runner.int) fronts)]
  end
end
