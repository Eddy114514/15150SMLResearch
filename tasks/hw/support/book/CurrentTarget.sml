structure TargetAdapter = struct
  structure B = Target.Book
  fun seek b 0 = b | seek b i = seek (B.flip B.FORWARD b) (i-1)
  fun run (pages,i) = B.currentPage (seek (B.bind pages) i)
end
