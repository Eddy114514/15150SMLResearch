structure CpsTarget = struct
  fun tree (CpsCase.Tip x) = Target.Leaf x
    | tree (CpsCase.Fork (l,r)) = Target.Branch (tree l,tree r)
end
