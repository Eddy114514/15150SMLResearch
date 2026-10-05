structure TargetAdapter = struct
  structure B = Target.Book
  fun seek b 0 = b | seek b i = seek (B.flip B.FORWARD b) (i-1)
  fun run (pages,i,d) =
    let val b = seek (B.bind pages) i
        val direction = case d of BookCase.Forward => B.FORWARD | BookCase.Backward => B.BACKWARD
        val result = (SOME (B.flip direction b) handle B.OutOfBounds => NONE)
    in case result of
         SOME next => (BookCase.Moved (B.currentPage next),B.unbind next)
       | NONE => (BookCase.OutOfBounds (B.currentPage b),B.unbind b)
    end
end
