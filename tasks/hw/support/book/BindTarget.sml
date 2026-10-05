structure TargetAdapter = struct
  structure B = Target.Book
  fun run pages =
    let val b = B.bind pages
        fun walk _ 0 = []
          | walk b n =
            let val next = (SOME (B.flip B.FORWARD b)
                            handle B.OutOfBounds => NONE)
            in case next of
                 SOME next => BookCase.Moved (B.currentPage next) :: walk next (n-1)
               | NONE => [BookCase.OutOfBounds (B.currentPage b)]
            end
    in ((B.unbind b,B.currentPage b),walk b (List.length pages)) end
end
