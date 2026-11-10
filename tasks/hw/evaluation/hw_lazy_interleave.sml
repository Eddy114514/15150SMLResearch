(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = LazyCase.source * LazyCase.source * int
  type output = int * int * int option list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => (LazyCase.Finite [1,2],LazyCase.Finite [9],4), true),
    ("valid-2", fn () => (LazyCase.Finite [],LazyCase.Finite [9],2), true),
    ("valid-3", fn () => (LazyCase.Finite [1],LazyCase.Finite [9],0), true),
    ("valid-4", fn () => (LazyCase.Finite [1],LazyCase.Finite [9],1), true),
    ("valid-5", fn () => (LazyCase.Finite [1],LazyCase.Finite [9],2), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("alternate", fn () => ((LazyCase.Finite [1,2],LazyCase.Finite [9],4), (0,0,[SOME 1,SOME 9,SOME 2,NONE])), true),
    ("left-empty-needs-right", fn () => ((LazyCase.Finite [],LazyCase.Finite [9],2), (0,1,[SOME 9,NONE])), true),
    ("zero-budget", fn () => ((LazyCase.Finite [1],LazyCase.Finite [9],0), (0,0,[])), true),
    ("unnecessary-right-force", fn () => ((LazyCase.Finite [1],LazyCase.Finite [9],1), (0,1,[SOME 1])), false),
    ("wrong-order", fn () => ((LazyCase.Finite [1],LazyCase.Finite [9],2), (0,1,[SOME 9,SOME 1])), false),
    ("eager-construction", fn () => ((LazyCase.Finite [1],LazyCase.Finite [9],1), (1,0,[SOME 1])), false)
  ]
end
