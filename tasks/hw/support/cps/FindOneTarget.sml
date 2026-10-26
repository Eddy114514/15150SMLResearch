structure TargetAdapter = struct
  fun run (p,t) = Target.findOne (CpsCase.test p) (CpsTarget.tree t) SOME (fn () => NONE)
end
