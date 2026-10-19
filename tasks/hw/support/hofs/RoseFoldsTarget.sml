structure TargetAdapter = struct
  fun rose (RoseFoldCase.Rose(x,children)) =
    Target.Rose(x,List.map rose children)
  fun run (reducer,initial,input) =
    let val tree = rose input
        val f = RoseFoldCase.apply reducer
    in (Target.roseFoldl f initial tree, Target.roseFoldr f initial tree) end
end
