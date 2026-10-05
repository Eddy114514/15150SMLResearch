structure CpsModel = struct
  fun leaves (CpsCase.Tip x) = [x]
    | leaves (CpsCase.Fork (l,r)) = leaves l @ leaves r
  fun distinct eq [] = true
    | distinct eq (x::xs) =
        not (List.exists (fn y => eq (x,y)) xs) andalso distinct eq xs
  fun classes eq xs = List.foldl
    (fn (x,seen) => if List.exists (fn y => eq (x,y)) seen then seen else x::seen) [] xs
end
