structure TargetAdapter = struct
  structure B = Target.Book
  fun run (pages,ds) =
    let val initial = B.bind pages
        fun go _ [] = []
          | go b (d::rest) =
            let val (next,observation) = BookTarget.step b d
            in observation :: go next rest end
    in ((B.unbind initial,B.currentPage initial),go initial ds) end
end
