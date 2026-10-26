(* Runtime generation and display for the shared finite integer-tree description. *)
structure IntegerTreeData = struct
  structure G = QCheck.Gen
  open SymmetryInput
  fun tree value 0 = G.lift Empty
    | tree value budget = G.choose #[G.lift Empty,
        G.map Node (G.zip3(tree value (budget div 2),value,
                          tree value (budget div 2)))]
  fun show Empty = Runner.object [("tag",Runner.quote "Empty")]
    | show (Node(l,x,r)) = Runner.object
        [("tag",Runner.quote "Node"),("left",show l),
         ("value",Runner.int x),("right",show r)]
end
