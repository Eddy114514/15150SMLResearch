(* Trusted pure helpers. Integer semantics are the host SML/NJ Int semantics. *)
structure Spec = struct
  fun sorted ([] : int list) = true
    | sorted [_] = true
    | sorted (x :: y :: rest) = x <= y andalso sorted (y :: rest)

  fun removeOne (_ : int) [] = NONE
    | removeOne x (y :: ys) =
        if x = y then SOME ys
        else Option.map (fn rest => y :: rest) (removeOne x ys)

  fun sameMultiset ([] : int list, ys : int list) = null ys
    | sameMultiset (x :: xs, ys) =
        case removeOne x ys of NONE => false
          | SOME rest => sameMultiset (xs, rest)
end
