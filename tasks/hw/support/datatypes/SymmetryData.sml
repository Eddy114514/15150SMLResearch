structure HwSymmetryData = struct
  structure G = QCheck.Gen
  open SymmetryInput
  val tree = IntegerTreeData.tree (G.range(~3,3))
  fun reflect Empty = Empty
    | reflect (Node(l,x,r)) = Node(reflect r,x+7,reflect l)
  val genInput = G.choose #[tree 15,
    G.map (fn t => Node(t,0,reflect t)) (tree 7)]
  val edges = [Empty,Node(Empty,1,Empty),
    Node(Node(Empty,2,Empty),1,Node(Empty,3,Empty)),
    Node(Node(Empty,1,Empty),0,Empty),
    Node(Node(Node(Empty,1,Empty),2,Empty),0,
         Node(Node(Empty,1,Empty),2,Empty))]
  val showInput = IntegerTreeData.show
  val showOutput = Runner.bool
end
