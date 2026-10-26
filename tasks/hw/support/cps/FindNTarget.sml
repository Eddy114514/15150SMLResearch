structure TargetAdapter = struct
  fun run (p,e,t,n) = Target.findN (CpsCase.test p) (CpsCase.equivalent e)
    (CpsTarget.tree t) n SOME (fn () => NONE)
end
