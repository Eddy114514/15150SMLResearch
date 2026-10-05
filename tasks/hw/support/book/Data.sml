(* Generation budgets only: 0..5 pages, 0..12 operations. No reusable Book states. *)
structure BookData = struct
  structure G = QCheck.Gen
  val pagesGen = G.vector List.tabulate
    (G.range (0,5),G.select #["", "a", "b", "lambda", "a"])
  val directionGen = G.select #[BookCase.Forward,BookCase.Backward]
  val stateGen = fn seed =>
    let val (pages,s1) = pagesGen seed
        val (i,s2) = G.range (0,List.length pages) s1
    in ((pages,i),s2) end
  fun showDirection BookCase.Forward = Runner.quote "FORWARD"
    | showDirection BookCase.Backward = Runner.quote "BACKWARD"
  val showPages = Runner.list Runner.quote
  fun showView (first,page) = Runner.object
    [("first",Runner.bool first),("page",Runner.option Runner.quote page)]
  fun showSnapshot (pages,v) = Runner.object [("pages",showPages pages),("view",showView v)]
  fun showStep (BookCase.Moved v) = Runner.object [("tag",Runner.quote "Moved"),("view",showView v)]
    | showStep (BookCase.OutOfBounds v) = Runner.object [("tag",Runner.quote "OutOfBounds"),("view",showView v)]
  fun showObserved (event,pages) = Runner.object [("step",showStep event),("pages",showPages pages)]
  val pageEdges = [[],[""],["a"],["a","b"],["a","a"]]
  val stateEdges = List.concat (List.map (fn pages =>
    List.tabulate (List.length pages+1,fn i => (pages,i))) pageEdges)
  structure Bind = struct
    val genInput = pagesGen
    val edges = pageEdges
    val showInput = showPages
    fun showOutput (initial,steps) = Runner.object
      [("initial",showSnapshot initial),("walk",Runner.list showStep steps)]
  end
  structure Current = struct
    val genInput = stateGen
    val edges = stateEdges
    fun showInput (pages,i) = Runner.object [("pages",showPages pages),("cursor",Runner.int i)]
    val showOutput = showView
  end
  structure Flip = struct
    val genInput = G.map (fn ((pages,i),d) => (pages,i,d)) (G.zip (stateGen,directionGen))
    val edges = List.concat (List.map (fn (pages,i) =>
      [(pages,i,BookCase.Forward),(pages,i,BookCase.Backward)]) stateEdges)
    fun showInput (pages,i,d) = Runner.object
      [("pages",showPages pages),("cursor",Runner.int i),("direction",showDirection d)]
    val showOutput = showObserved
  end
  structure Trace = struct
    val genInput = G.zip (pagesGen,G.vector List.tabulate (G.range (0,12),directionGen))
    val edges = [([],[]),([],[BookCase.Forward,BookCase.Backward]),
      (["a"],[BookCase.Forward,BookCase.Forward,BookCase.Backward]),
      (["a","b"],[BookCase.Backward,BookCase.Forward,BookCase.Forward,BookCase.Backward])]
    fun showInput (pages,ds) = Runner.object [("pages",showPages pages),("operations",Runner.list showDirection ds)]
    fun showOutput (initial,steps) = Runner.object
      [("initial",showSnapshot initial),("steps",Runner.list showObserved steps)]
  end
end
