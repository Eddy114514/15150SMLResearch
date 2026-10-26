structure BookTarget = struct
  structure B = Target.Book
  fun seek b 0 = b | seek b i = seek (B.flip B.FORWARD b) (i-1)
  fun step b d =
    let val direction = case d of BookCase.Forward => B.FORWARD | BookCase.Backward => B.BACKWARD
        val result = (SOME (B.flip direction b) handle B.OutOfBounds => NONE)
        val (next,event) = case result of
            SOME next => (next,BookCase.Moved (B.currentPage next))
          | NONE => (b,BookCase.OutOfBounds (B.currentPage b))
    in (next,(event,B.unbind next)) end
end
