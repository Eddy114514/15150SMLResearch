(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = EncryptionCase.input
  type output = EncryptionCase.output
  fun observations (a,b,c) = {matrix=[[SOME a,NONE,NONE],[NONE,SOME b,NONE],[NONE,NONE,SOME c]],
    reused=[SOME a,SOME b,SOME c],foreign=List.tabulate (9,fn _ => NONE)}
  fun input () : input = {integers=(1,2,3),strings=("a","b","c"),lists=([1],[],[2,3]),
    functions=((1,0),(2,1),(0,7)),probes=[~1,0,2]}
  fun output () : output = {integers=observations (1,2,3),strings=observations ("a","b","c"),
    lists=observations ([1],[],[2,3]),functions=observations ([~1,0,2],[~1,1,5],[7,7,7])}
  fun replaceInts obs : output = let val result=output () in
    {integers=obs,strings= #strings result,lists= #lists result,functions= #functions result} end
  fun overflowInput probes : input = let val i=input () in
    {integers= #integers i,strings= #strings i,lists= #lists i,
     functions=((valOf Int.maxInt,0),(2,1),(0,7)),probes=probes} end
  fun replaceFunctions obs : output = let val r=output () in
    {integers= #integers r,strings= #strings r,lists= #lists r,functions=obs} end

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => input (), true),
    ("overflow-is-not-an-added-precondition", fn () => overflowInput [2], true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("four-payload-types", fn () => (input (), output ()), true),
    ("unobserved-function-arithmetic", fn () => (overflowInput [], replaceFunctions (observations ([],[],[]))), true),
    ("checker-arithmetic-does-not-overflow", fn () => (overflowInput [2], replaceFunctions (observations ([0],[5],[7]))), false),
    ("wrong-matching-payload", fn () => (input (), replaceInts (observations (9,2,3))), false),
    ("cross-key-leak", fn () => (input (), replaceInts {matrix=List.tabulate (3,fn _ => [SOME 1,SOME 2,SOME 3]),reused=[SOME 1,SOME 2,SOME 3],foreign=List.tabulate (9,fn _ => NONE)}), false),
    ("first-key-rejects-secrets", fn () => (input (), replaceInts {matrix=[[NONE,NONE,NONE],[NONE,SOME 2,NONE],[NONE,NONE,SOME 3]],reused=[NONE,NONE,NONE],foreign=List.tabulate (9,fn _ => NONE)}), false),
    ("foreign-secret-accepted", fn () => (input (), replaceInts {matrix=[[SOME 1,SOME 1,SOME 1],[NONE,SOME 2,NONE],[NONE,NONE,SOME 3]],reused=[SOME 1,SOME 2,SOME 3],foreign=List.tabulate (9,fn _ => SOME 1)}), false),
    ("function-probe-order", fn () => (input (), let val r=output () in {integers= #integers r,strings= #strings r,lists= #lists r,functions=observations ([2,0,~1],[~1,1,5],[7,7,7])} end), false)
  ]
end
