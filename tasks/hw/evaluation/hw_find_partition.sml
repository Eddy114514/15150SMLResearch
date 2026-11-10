(* Fixed independent semantic labels; never included in model prompts.
 * Every thunk constructs fresh values for each predicate evaluation. *)
structure Evaluation = struct
  type input = PartitionCase.input
  type output = PartitionCase.output

  val requiresCases : (string * (unit -> input) * bool) list = [
    ("valid-1", fn () => ([],PartitionCase.Length 0,PartitionCase.Length 0), true),
    ("valid-2", fn () => ([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), true),
    ("valid-3", fn () => ([1,2],PartitionCase.Sum 9,PartitionCase.All CpsCase.Any), true)
  ]
  val ensuresCases : (string * (unit -> input * output) * bool) list = [
    ("empty-partition", fn () => (([],PartitionCase.Length 0,PartitionCase.Length 0), SOME ([],(0,0))), true),
    ("witness-a", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), SOME ([1,2],(1,3))), true),
    ("witness-b", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), SOME ([1,3],(1,2))), true),
    ("no-partition", fn () => (([1,2],PartitionCase.Sum 9,PartitionCase.All CpsCase.Any), NONE), true),
    ("false-none", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), NONE), false),
    ("unstable-left-order", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), SOME ([2,1],(1,3))), false),
    ("wrong-right-evidence", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), SOME ([1,2],(1,2))), false),
    ("reused-position", fn () => (([1,2,3],PartitionCase.Length 2,PartitionCase.Length 1), SOME ([1,1],(1,3))), false)
  ]
end
