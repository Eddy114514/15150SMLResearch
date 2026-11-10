(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = CommandCase.bindings * CommandCase.action
  type output = CommandCase.outcome

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([("x",1)],CommandCase.Assign ("x",2)), true),
    ("valid-2", fn () => ([("x",1)],CommandCase.Break), true),
    ("valid-3", fn () => ([],CommandCase.Continue), true),
    ("valid-4", fn () => ([],CommandCase.If (true,[CommandCase.Return 7,CommandCase.Assign ("x",9)],[])), true),
    ("valid-5", fn () => ([],CommandCase.Loop ("i",2,[CommandCase.Continue])), true),
    ("valid-6", fn () => ([],CommandCase.Loop ("i",3,[CommandCase.Break])), true),
    ("valid-7", fn () => ([],CommandCase.Loop ("i",0,[CommandCase.Assign ("x",9)])), true),
    ("valid-8", fn () => ([],CommandCase.Return 7), true),
    ("negative-count-performs-zero-iterations", fn () => ([],CommandCase.Loop ("i",~1,[])), true),
    ("outside-reference-subset-counter-written", fn () => ([],CommandCase.Loop ("i",2,[CommandCase.Assign ("i",0)])), false),
    ("outside-reference-subset-counter-reused", fn () => ([],CommandCase.Loop ("i",2,[CommandCase.Loop ("i",1,[])])), false)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("assignment-shadowing", fn () => (([("x",1)],CommandCase.Assign ("x",2)), CommandCase.Completed [("x",2)]), true),
    ("shadowed-representation-allowed", fn () => (([("x",1)],CommandCase.Assign ("x",2)), CommandCase.Completed [("x",2),("x",1)]), true),
    ("break-tag", fn () => (([("x",1)],CommandCase.Break), CommandCase.Broke [("x",1)]), true),
    ("continue-tag", fn () => (([],CommandCase.Continue), CommandCase.Continued []), true),
    ("return-stops-sequence", fn () => (([],CommandCase.If (true,[CommandCase.Return 7,CommandCase.Assign ("x",9)],[])), CommandCase.Returned 7), true),
    ("continue-progress", fn () => (([],CommandCase.Loop ("i",2,[CommandCase.Continue])), CommandCase.Completed [("i",2)]), true),
    ("break-stops-loop", fn () => (([],CommandCase.Loop ("i",3,[CommandCase.Break])), CommandCase.Completed [("i",1)]), true),
    ("zero-loop", fn () => (([],CommandCase.Loop ("i",0,[CommandCase.Assign ("x",9)])), CommandCase.Completed [("i",0)]), true),
    ("negative-loop", fn () => (([],CommandCase.Loop ("i",~2,[CommandCase.Assign ("x",9)])), CommandCase.Completed [("i",0)]), true),
    ("wrong-shadowing", fn () => (([("x",1)],CommandCase.Assign ("x",2)), CommandCase.Completed [("x",1),("x",2)]), false),
    ("wrong-tag", fn () => (([("x",1)],CommandCase.Break), CommandCase.Completed [("x",1)]), false),
    ("wrong-return", fn () => (([],CommandCase.Return 7), CommandCase.Returned 8), false),
    ("lost-loop-progress", fn () => (([],CommandCase.Loop ("i",2,[CommandCase.Continue])), CommandCase.Completed [("i",1)]), false)
  ]
end
