structure TargetAdapter = struct
  fun run (n,chats,source,resolution) =
    let
      val tracker = List.foldl
        (fn (chat,state) => Target.Tracker.addChat state (Seq.fromList chat))
        (Target.Tracker.empty n) chats
    in Seq.toList (Target.Tracker.query tracker source resolution) end
end
