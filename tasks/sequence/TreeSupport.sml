(* Runtime-only generation and display for Tree; callers choose values/depth. *)
structure TreeSupport = struct
  structure G = QCheck.Gen
  fun gen value 0 = G.map Tree.Leaf value
    | gen value depth =
        let val child = gen value (depth - 1)
        in G.choose #[G.map Tree.Leaf value,G.map Tree.Node (G.zip (child,child))] end

  fun show (Tree.Leaf value) =
        Runner.object [("tag", Runner.quote "Leaf"), ("value", Runner.int value)]
    | show (Tree.Node (left, right)) =
        Runner.object [("tag", Runner.quote "Node"),
                       ("left", show left), ("right", show right)]
end
