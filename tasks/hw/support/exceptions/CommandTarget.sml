structure TargetAdapter = struct
  fun command (CommandCase.Assign (name,value)) = Target.Assign (name,Target.AConst value)
    | command CommandCase.Break = Target.Break
    | command CommandCase.Continue = Target.Continue
    | command (CommandCase.Return value) = Target.Return (Target.AConst value)
    | command (CommandCase.If (condition,yes,no)) =
        Target.If (Target.BConst condition,List.map command yes,List.map command no)
    | command (CommandCase.Loop (counter,count,body)) =
        Target.If (Target.BConst true,
          [Target.Assign (counter,Target.AConst 0),
           Target.Loop (
             [Target.If (Target.LessThan (Target.Variable counter,Target.AConst count),
                         [],[Target.Break]),
              (* Increment before the body: Continue cannot skip progress. *)
              Target.Assign (counter,Target.Add (Target.Variable counter,Target.AConst 1))]
             @ List.map command body)],[])
  fun run (bindings, action) = let
    val env = List.foldl (fn ((name,value),acc) => Target.set name value acc)
                        Target.emptyEnvironment bindings
  in
    (CommandCase.Completed (Target.runCommand env (command action))
     handle Target.BreakExn result => CommandCase.Broke result
          | Target.ContinueExn result => CommandCase.Continued result
          | Target.ReturnExn result => CommandCase.Returned result)
  end
end
