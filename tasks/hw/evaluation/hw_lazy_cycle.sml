(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = LazyCase.source * int
  type output = int * int option list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (LazyCase.Finite [],3), true),
    ("valid-2", fn () => (LazyCase.Finite [1,2],5), true),
    ("valid-3", fn () => (LazyCase.Repeat (3,[4]),3), true),
    ("valid-4", fn () => (LazyCase.Finite [1],0), true),
    ("valid-5", fn () => (LazyCase.Finite [1],~2), true),
    ("valid-6", fn () => (LazyCase.Finite [1],1), true),
    ("valid-7", fn () => (LazyCase.Finite [1],2), true),
    ("valid-8", fn () => (LazyCase.Finite [],0), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-ended", fn () => ((LazyCase.Finite [],3), (0,[NONE])), true),
    ("finite-repeats", fn () => ((LazyCase.Finite [1,2],5), (0,[SOME 1,SOME 2,SOME 1,SOME 2,SOME 1])), true),
    ("infinite-preserved", fn () => ((LazyCase.Repeat (3,[4]),3), (0,[SOME 3,SOME 4,SOME 3])), true),
    ("zero-budget", fn () => ((LazyCase.Finite [1],0), (0,[])), true),
    ("negative-budget", fn () => ((LazyCase.Finite [1],~2), (0,[])), true),
    ("eager-construction", fn () => ((LazyCase.Finite [1],1), (1,[SOME 1])), false),
    ("premature-end", fn () => ((LazyCase.Finite [1],2), (0,[SOME 1,NONE])), false),
    ("wrong-repeated-value", fn () => ((LazyCase.Finite [1,2],5), (0,[SOME 1,SOME 2,SOME 2,SOME 1,SOME 2])), false)
  ]
end
