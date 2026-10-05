structure TargetAdapter = struct
  fun convert SymmetryInput.Empty = Target.Empty
    | convert (SymmetryInput.Node(l,x,r)) = Target.Node(convert l,x,convert r)
  fun run input = Target.isSymmetric (convert input)
end
