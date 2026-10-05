structure TargetAdapter = struct
  structure B = Target.Book
  fun run (pages,ds) =
    let val initial = B.bind pages
        fun go _ [] = []
          | go b (d::rest) =
            let val direction = case d of BookCase.Forward => B.FORWARD | BookCase.Backward => B.BACKWARD
                val result = (SOME (B.flip direction b) handle B.OutOfBounds => NONE)
                val (next,event) = case result of
                    SOME next => (next,BookCase.Moved (B.currentPage next))
                  | NONE => (b,BookCase.OutOfBounds (B.currentPage b))
            in (event,B.unbind next) :: go next rest end
    in ((B.unbind initial,B.currentPage initial),go initial ds) end
end
