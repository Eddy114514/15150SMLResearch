structure TargetAdapter = struct
  fun run (pages,i,d) =
    #2 (BookTarget.step (BookTarget.seek (Target.Book.bind pages) i) d)
end
