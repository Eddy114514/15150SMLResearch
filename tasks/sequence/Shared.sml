(* One public input representation shared by Contract, Target and Data. *)
structure Tree = struct
  datatype tree = Leaf of int | Node of tree * tree
end
