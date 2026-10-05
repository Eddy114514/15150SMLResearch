structure TargetAdapter = struct
  fun tree (CpsCase.Tip x) = Target.Leaf x
    | tree (CpsCase.Fork (l,r)) = Target.Branch (tree l,tree r)
  fun run (p,e,t,n) = Target.findN (CpsCase.test p) (CpsCase.equivalent e)
    (tree t) n SOME (fn () => NONE)
end
