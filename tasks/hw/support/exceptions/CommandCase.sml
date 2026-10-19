(* Finite descriptions of commands in a well-formed loop body.
 * Bindings describe prior assignments; repeated names use their latest value.
 * Loop descriptions use a protected counter and a maximum iteration count.
 * The runtime constructs the course's actual Target.command constructors. *)
structure CommandCase = struct
  type bindings = (string * int) list
  datatype action = Assign of string * int | Break | Continue | Return of int
                  | If of bool * action list * action list
                  | Loop of string * int * action list
  datatype outcome = Completed of bindings | Broke of bindings
                   | Continued of bindings | Returned of int
end
