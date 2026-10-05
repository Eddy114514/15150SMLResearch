(* Independent pages/cursor model, used only by the contracts. *)
structure BookModel = struct
  fun view pages i =
    (i = 0, if i = List.length pages then NONE else SOME (List.nth (pages,i)))
  fun advance pages i BookCase.Forward =
        if i = List.length pages then (i, BookCase.OutOfBounds (view pages i))
        else (i+1, BookCase.Moved (view pages (i+1)))
    | advance pages i BookCase.Backward =
        if i = 0 then (i, BookCase.OutOfBounds (view pages i))
        else (i-1, BookCase.Moved (view pages (i-1)))
  fun trace pages directions =
    let fun go _ [] = []
          | go i (d::ds) =
            let val (j,event) = advance pages i d
            in (event,pages) :: go j ds end
    in ((pages,view pages 0),go 0 directions) end
end
