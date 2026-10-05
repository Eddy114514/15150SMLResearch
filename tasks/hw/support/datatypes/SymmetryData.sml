structure HwSymmetryData = struct
  structure G = QCheck.Gen
  open SymmetryInput
  fun tree 0 = G.lift Empty
    | tree budget = G.choose #[G.lift Empty,
        G.map Node (G.zip3(tree (budget div 2), G.range(~3,3), tree (budget div 2)))]
  fun reflect Empty = Empty
    | reflect (Node(l,x,r)) = Node(reflect r,x+7,reflect l)
  val genInput = G.choose #[tree 15,
    G.map (fn t => Node(t,0,reflect t)) (tree 7)]
  val edges = [Empty,Node(Empty,1,Empty),
    Node(Node(Empty,2,Empty),1,Node(Empty,3,Empty)),
    Node(Node(Empty,1,Empty),0,Empty),
    Node(Node(Node(Empty,1,Empty),2,Empty),0,
         Node(Node(Empty,1,Empty),2,Empty))]
  fun showInput Empty = Runner.object [("tag",Runner.quote "Empty")]
    | showInput (Node(l,x,r)) = Runner.object
        [("tag",Runner.quote "Node"),("left",showInput l),
         ("value",Runner.int x),("right",showInput r)]
  val showOutput = Runner.bool
end
