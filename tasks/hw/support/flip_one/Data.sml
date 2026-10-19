(* Length 0..20 is a generation budget, not a precondition. *)
structure FlipOneData = struct
  structure G = QCheck.Gen
  val genInput = G.vector List.tabulate (G.range (0,20),G.flip)
  val edges = [[],[false],[true],[false,false],[true,true],
    [false,true],[true,false],[true,false,true],
    List.tabulate (20,fn _ => false),
    List.tabulate (20,fn _ => true),
    List.tabulate (20,fn i => i mod 2 = 0)]
  val showInput = Runner.list Runner.bool
  val showOutput = Runner.list (Runner.list Runner.bool)
end
