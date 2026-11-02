structure TargetAdapter = struct
  structure B = Target.Book
  fun run pages =
    let val b = B.bind pages
        fun walk _ 0 = []
          | walk b n =
            let val (next,event) = BookTarget.move b BookCase.Forward
            in case event of
                 BookCase.Moved _ => event :: walk next (n-1)
               | BookCase.OutOfBounds _ => [event]
            end
    in (BookTarget.snapshot b,walk b (List.length pages)) end
end
