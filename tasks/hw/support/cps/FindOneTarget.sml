structure TargetAdapter = struct
  fun tree (CpsCase.Tip x) = Target.Leaf x
    | tree (CpsCase.Fork (l,r)) = Target.Branch (tree l,tree r)
  fun run (p,t) = Target.findOne (CpsCase.test p) (tree t) SOME (fn () => NONE)
end
