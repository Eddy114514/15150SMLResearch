(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int list * int
  type output = int list option

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([],0), true),
    ("valid-2", fn () => ([2,4],3), true),
    ("valid-3", fn () => ([1,2,3],3), true),
    ("valid-4", fn () => ([~2,5,1],3), true),
    ("valid-5", fn () => ([1,2,3],2), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-witness", fn () => (([],0), SOME []), true),
    ("no-solution", fn () => (([2,4],3), NONE), true),
    ("witness-first", fn () => (([1,2,3],3), SOME [1,2]), true),
    ("witness-alternative", fn () => (([1,2,3],3), SOME [3]), true),
    ("negative-values", fn () => (([~2,5,1],3), SOME [~2,5]), true),
    ("false-none", fn () => (([1,2,3],3), NONE), false),
    ("wrong-sum", fn () => (([1,2,3],3), SOME [1]), false),
    ("reordered", fn () => (([1,2,3],3), SOME [2,1]), false),
    ("reused-position", fn () => (([1,2,3],2), SOME [1,1]), false)
  ]
end
