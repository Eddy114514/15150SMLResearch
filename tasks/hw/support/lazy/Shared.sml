(* Finite descriptions of productive inputs, not a replacement Stream type.
 * Repeat (first,rest) denotes the nonempty period first::rest forever. *)
structure LazyCase = struct
  datatype source = Finite of int list | Repeat of int * int list
end
