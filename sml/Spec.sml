(* Trusted pure helpers. Integer semantics are the host SML/NJ Int semantics. *)
structure Spec = struct
  exception DependencyDomainViolation of string
  val forall = List.all
  val exists = List.exists

  fun member x xs = List.exists (fn y => x = y) xs
  fun subset (xs, ys) = List.all (fn x => member x ys) xs

  fun forallRange p (lo : int, hi : int) =
    let
      fun loop i =
        if not (p i) then false
        else if i = hi then true
        else loop (i + 1)
    in
      if lo > hi then true else loop lo
    end

  fun existsRange p bounds = not (forallRange (fn i => not (p i)) bounds)

  fun sorted ([] : int list) = true
    | sorted [_] = true
    | sorted (x :: y :: rest) = x <= y andalso sorted (y :: rest)

  fun removeOne _ [] = NONE
    | removeOne x (y :: ys) =
        if x = y then SOME ys
        else Option.map (fn rest => y :: rest) (removeOne x ys)

  fun sameMultiset ([], ys) = null ys
    | sameMultiset (x :: xs, ys) =
        case removeOne x ys of NONE => false
          | SOME rest => sameMultiset (xs, rest)
end
