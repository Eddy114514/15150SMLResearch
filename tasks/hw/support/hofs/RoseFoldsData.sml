(* Generation budgets only: depth <= 3, 0..3 children (<=40 nodes), values -3..3. *)
structure RoseFoldsData = struct
  structure G = QCheck.Gen
  val value = G.range(~3,3)
  fun tree 0 = G.map (fn x => RoseFoldCase.Rose(x,[])) value
    | tree n = G.map RoseFoldCase.Rose
        (G.zip(value,G.vector List.tabulate (G.range(0,3),tree(n-1))))
  val reducer = G.select #[RoseFoldCase.Append ",",RoseFoldCase.Append "|",
    RoseFoldCase.Prepend ",",RoseFoldCase.Bracket]
  val genInput = G.zip3(reducer,G.select #["","z","start"],tree 3)
  val example = RoseFoldCase.Rose(2,[RoseFoldCase.Rose(1,[]),RoseFoldCase.Rose(3,[])])
  val edges = [(RoseFoldCase.Append "", "z", example),
    (RoseFoldCase.Prepend ",", "z", example),
    (RoseFoldCase.Bracket, "z", example),
    (RoseFoldCase.Append ",", "", RoseFoldCase.Rose(0,[])),
    (RoseFoldCase.Append ",", "z", RoseFoldCase.Rose(0,
      [RoseFoldCase.Rose(1,[RoseFoldCase.Rose(2,[])]),
       RoseFoldCase.Rose(3,[]),RoseFoldCase.Rose(4,[])]))]
  fun showReducer (RoseFoldCase.Append s) = Runner.object [("Append",Runner.quote s)]
    | showReducer (RoseFoldCase.Prepend s) = Runner.object [("Prepend",Runner.quote s)]
    | showReducer RoseFoldCase.Bracket = Runner.quote "Bracket"
  fun showTree (RoseFoldCase.Rose(x,children)) = Runner.object
    [("value",Runner.int x),("children",Runner.list showTree children)]
  fun showInput (f,z,t) = Runner.object
    [("reducer",showReducer f),("initial",Runner.quote z),("rose",showTree t)]
  fun showOutput (left,right) = Runner.object
    [("foldl",Runner.quote left),("foldr",Runner.quote right)]
end
