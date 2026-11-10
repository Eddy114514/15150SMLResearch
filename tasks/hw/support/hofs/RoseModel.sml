structure RoseModel = struct
  fun preorder (RoseFoldCase.Rose(x,children)) =
    x :: List.concat (List.map preorder children)
end
