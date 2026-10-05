structure HwSublistData = struct
  structure G = QCheck.Gen
  val value = G.range (~5,5)
  val listGen = G.vector List.tabulate (G.range(0,10), value)
  val witness = G.map
    (fn entries =>
      (List.map (fn (x,_) => x) entries,
       List.foldl (fn ((x,chosen),n) => if chosen then x+n else n) 0 entries))
    (G.vector List.tabulate (G.range(0,10), G.zip(value,G.flip)))
  val genInput = G.choose #[witness, G.zip(listGen,G.range(~60,60))]
  val edges = [([],0),([],1),([1],1),([1],2),([2,1],1),([2,~1],1),
               ([1,1],2),([0,0],0),([1,3],2),([1,2,3],3),([2,9,1],3)]
  val showInput = Runner.listIntPair
  val showOutput = Runner.option (Runner.list Runner.int)
end
