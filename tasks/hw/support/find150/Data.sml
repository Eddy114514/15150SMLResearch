(* Generation budgets only: at most 12 pages. No Book state is shared by tests. *)
structure Find150Data = struct
  structure G = QCheck.Gen
  val arbitraryPages = G.vector List.tabulate
    (G.range (0,12),G.select #["lambda","pointer","","Lambda","lambda ","chapter"])
  val otherPages = G.vector List.tabulate
    (G.range (0,3),G.select #["","lambda","Lambda","lambda ","chapter"])
  val acceptedPages = G.map
    (fn (a,b,c) => "lambda" :: a @ ("lambda" :: b) @ ("lambda" :: c))
    (G.zip3 (otherPages,otherPages,otherPages))
  val genInput = G.choose #[arbitraryPages,acceptedPages]
  val edges = [[],[""],["lambda"],["lambda","lambda"],
    ["lambda","lambda","lambda"],["lambda","lambda","lambda","lambda"],
    ["pointer","lambda","lambda","lambda"],
    ["lambda","pointer","lambda","lambda"],
    ["lambda","lambda","lambda","pointer"],
    ["lambda","chapter","lambda","","lambda"],
    ["Lambda","lambda ","lambda"],["pointer","pointer"]]
  val showInput = Runner.list Runner.quote
  val showOutput = Runner.bool
end
