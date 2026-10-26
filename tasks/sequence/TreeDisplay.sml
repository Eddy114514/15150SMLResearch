(* Runtime-only JSON display for the shared Tree datatype. *)
structure TreeDisplay = struct
  fun show (Tree.Leaf value) =
        Runner.object [("tag", Runner.quote "Leaf"), ("value", Runner.int value)]
    | show (Tree.Node (left, right)) =
        Runner.object [("tag", Runner.quote "Node"),
                       ("left", show left), ("right", show right)]
end
