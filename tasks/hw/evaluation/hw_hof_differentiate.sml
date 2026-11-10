(* Fixed functional-projection labels, not validation of the full original
 * specification. Never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = int list * int list
  type output = real list

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([3,2,4],[~1,0,1,2,5]), true),
    ("valid-2", fn () => ([3,2,4],[0]), true),
    ("valid-3", fn () => ([9],[0,1]), true),
    ("valid-4", fn () => ([],[]), true),
    ("valid-5", fn () => ([3,2,4],[0,1]), true),
    ("valid-6", fn () => ([3,2,4],[1,0]), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("coefficients-and-negative-probes", fn () => (([3,2,4],[~1,0,1,2,5]), [0.0,2.0,8.0,0.0,0.0]), true),
    ("no-unspecified-tolerance", fn () => (([3,2,4],[0]), [2.005]), false),
    ("constant", fn () => (([9],[0,1]), [0.0,0.0]), true),
    ("empty-observation", fn () => (([],[]), []), true),
    ("wrong-factor", fn () => (([3,2,4],[0,1]), [2.0,4.0]), false),
    ("wrong-probe-order", fn () => (([3,2,4],[1,0]), [2.0,8.0]), false),
    ("wrong-coefficient", fn () => (([3,2,4],[0]), [2.02]), false)
  ]
end
