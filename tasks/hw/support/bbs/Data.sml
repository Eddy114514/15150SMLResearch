structure BbsData = struct
  structure G = QCheck.Gen
  (* Generation budgets, not additional bbs preconditions. Equal prime factors
   * and seeds not coprime to the modulus are allowed by this assignment. *)
  val prime = G.select #[2,3,5,7,11,13,17,19]
  val modulus = G.map (op * ) (G.zip (prime,prime))
  val genInput = G.zip3 (modulus,G.range (~30,30),G.range (0,12))
  val edges = [(15,3,6),(209,3,6),(4,0,4),(9,1,4),(15,~3,6),
               (15,15,4),(4,2,4),(15,3,0),(15,50000,0)]
  fun showInput (m,s,n) = Runner.object
    [("modulus",Runner.int m),("seed",Runner.int s),("probes",Runner.int n)]
  val showOutput = Runner.list (Runner.option Runner.int)
end
