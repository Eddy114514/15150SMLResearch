(* AST recursion budget 3, string length 0..5, alphabet a/b.
 * Star generation prefixes its body with a Char to construct standard form;
 * requires accepts all standard-form ASTs, not just this sampling grammar. *)
structure RegexData = struct
  structure G = QCheck.Gen
  val charGen = G.select #[#"a",#"b"]
  val textGen = G.vector List.tabulate (G.range (0,5),charGen)
  val atomGen = G.choose #[G.lift RegexCase.Zero,G.lift RegexCase.One,G.map RegexCase.Char charGen]
  fun regexGen 0 = atomGen
    | regexGen n =
      let val child = regexGen (n-1)
          val pair = G.zip (child,child)
      in G.choose #[atomGen,G.map RegexCase.Plus pair,G.map RegexCase.Times pair,
           G.map RegexCase.Both pair,
           G.map (fn (c,r) => RegexCase.Star (RegexCase.Times (RegexCase.Char c,r)))
             (G.zip (charGen,child))] end
  fun matchGen rgen = Generators.bind (G.zip (rgen,textGen))
    (fn (r,text) => G.map (fn table => (r,text,table))
      (G.vector List.tabulate (G.lift (List.length text+1),G.flip)))
  fun showRegex RegexCase.Zero = Runner.quote "Zero"
    | showRegex RegexCase.One = Runner.quote "One"
    | showRegex (RegexCase.Char c) = Runner.object [("Char",Runner.quote (str c))]
    | showRegex (RegexCase.Plus (a,b)) = pair "Plus" (a,b)
    | showRegex (RegexCase.Times (a,b)) = pair "Times" (a,b)
    | showRegex (RegexCase.Both (a,b)) = pair "Both" (a,b)
    | showRegex (RegexCase.Star a) = Runner.object [("Star",showRegex a)]
  and pair name operands = Runner.object [(name,Runner.pair (showRegex,showRegex) operands)]
  val a = RegexCase.Char #"a"
  val b = RegexCase.Char #"b"
  val bothEdges = [
    (RegexCase.Both (RegexCase.One,a),[#"a"],[true,true]),
    (RegexCase.Both (a,RegexCase.Times(a,a)),[#"a",#"a"],[true,true,true]),
    (RegexCase.Both (RegexCase.Plus(a,b),a),[#"a"],[false,true]),
    (RegexCase.Both (RegexCase.One,RegexCase.One),[],[true]),
    (RegexCase.Both (a,a),[#"a"],[true,false])]
  structure Match = struct
    val genInput = matchGen (regexGen 3)
    val edges = [(RegexCase.Zero,[],[true]),(RegexCase.One,[],[true]),
      (RegexCase.One,[],[false]),(a,[#"a"],[false,true]),
      (RegexCase.Times(a,b),[#"a",#"b"],[false,false,true]),
      (RegexCase.Star a,[#"a",#"a"],[false,false,true]),
      (RegexCase.Star (RegexCase.Plus(a,b)),[#"a",#"b"],[false,false,true])] @ bothEdges
    fun showInput (r,text,table) = Runner.object [("regex",showRegex r),
      ("text",Runner.quote (String.implode text)),("continuation",Runner.list Runner.bool table)]
    val showOutput = Runner.bool
  end
  structure Both = struct
    val genInput = matchGen (G.map RegexCase.Both (G.zip (regexGen 2,regexGen 2)))
    val edges = bothEdges
    val showInput = Match.showInput
    val showOutput = Runner.bool
  end
  structure Accept = struct
    val genInput = G.map (fn (r,cs) => (r,String.implode cs)) (G.zip (regexGen 3,textGen))
    val edges = [(RegexCase.Zero,""),(RegexCase.One,""),(a,"a"),(a,"aa"),
      (RegexCase.Star a,"aaa"),(RegexCase.Star a,"b"),
      (RegexCase.Times (RegexCase.Both (RegexCase.One,a),RegexCase.Star a),"a"),
      (RegexCase.Both (RegexCase.Plus(a,b),a),"a")]
    fun showInput (r,text) = Runner.object [("regex",showRegex r),("text",Runner.quote text)]
    val showOutput = Runner.bool
  end
end
