(* Lossless external description. It is converted to Target.tree at runtime;
 * it is never assumed to have the same SML type identity as Target.tree. *)
structure SymmetryInput = struct
  datatype tree = Empty | Node of tree * int * tree
end
