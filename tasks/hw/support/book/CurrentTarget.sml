structure TargetAdapter = struct
  structure B = Target.Book
  fun run (pages,i) = B.currentPage (BookTarget.seek (B.bind pages) i)
end
