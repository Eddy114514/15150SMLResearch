(* Public observations only; no Book representation crosses this boundary. *)
structure BookCase = struct
  datatype direction = Forward | Backward
  type view = bool * string option
  type snapshot = string list * view
  datatype step = Moved of view | OutOfBounds of view
  type observedStep = step * string list
end
