structure TargetAdapter = struct
  structure T = Target.LazyTree

  fun run (mapper,tree) = let
    val treeForces = ref 0
    val mapperCalls = ref 0
    fun build SymmetryInput.Empty = T.delay
          (fn () => (treeForces := !treeForces + 1; T.LEAF))
      | build (SymmetryInput.Node(l,x,r)) = T.delay
          (fn () => (treeForces := !treeForces + 1; T.NODE(build l,x,build r)))
    fun apply x = (mapperCalls := !mapperCalls + 1; EncryptionCase.affine mapper x)
    fun observe t =
      case T.expose t of T.LEAF => SymmetryInput.Empty
      | T.NODE(l,x,r) => SymmetryInput.Node(observe l,x,observe r)
    val result = T.map apply (build tree)
    val constructionTreeForces = !treeForces
    val constructionMapperCalls = !mapperCalls
  in (constructionTreeForces,constructionMapperCalls,observe result) end
end
