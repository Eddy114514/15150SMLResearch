datatype 'a tree = Empty | Node of 'a tree * 'a * 'a tree
datatype 'a rose = Rose of 'a * 'a rose list

fun roseToString (f : 'a -> string) (Rose (x,rs)) : string =
  (f x) ^ "\n" ^ (
    case rs of
      [] => ""
    | _  =>
      MakeString.indent (
        String.concatWith "\n" (List.map (roseToString f) rs)
      )
  )

fun roseHelp(Node(Empty,x,Empty))  = Rose(x,[])
  | roseHelp(Node(l, x, Empty)) = Rose(x,[roseHelp(l)])
  | roseHelp(Node(Empty,x,r)) = Rose(x, [roseHelp(r)])
  | roseHelp(Node(l,x,r)) = Rose(x, [roseHelp(l),roseHelp(r)])


fun treeToRose (Empty : 'a tree) : 'a rose option = NONE
  | treeToRose (t: 'a tree) : 'a rose option = SOME(roseHelp(t))


val () = Test.test_eq (op=, MakeString.option (roseToString MakeString.int))
  ( "treeToRose0"
  , SOME (Rose (2, [Rose (1, []), Rose (3, [])]))
  , treeToRose (Node (Node (Empty, 1, Empty), 2, Node (Empty, 3, Empty)))
  )




fun roseMap (f : 'a -> 'b) (Rose(r,rs) : 'a rose) : 'b rose = 
  let
    fun roseMapList f [] = []
      | roseMapList f (r::rs) = (roseMap f r) :: (roseMapList f rs)
  in
    Rose (f r, roseMapList f rs)
  end

val () = Test.test_eq (op=, roseToString MakeString.int)
  ( "roseMap0"
  , Rose (4, [Rose (2, []), Rose (6, [])])
  , roseMap (fn x => x * 2) (Rose (2, [Rose (1, []), Rose (3, [])]))
  )

fun roseFoldl (f : 'a * 'b -> 'b) (z : 'b) (Rose (x, rs) : 'a rose) : 'b =
  let
    fun roseFoldList z [] = z
      | roseFoldList z (r::rs) = roseFoldList (roseFoldl f z r) rs
  in
    roseFoldList (f(x,z)) rs
  end



val () =
  Test.string
    ( "roseFoldl0"
    , "z213"
    , roseFoldl
        (fn (x, ac) => ac ^ Int.toString x)
        "z"
        (Rose (2, [Rose (1, []), Rose (3, [])]))
    )


fun roseFoldr (f : 'a * 'b -> 'b) (z : 'b) (Rose (x, rs) : 'a rose) : 'b =
  let
    fun roseFoldList z [] = z
      | roseFoldList z (r::rs) =  roseFoldr f (roseFoldList z rs) r
  in
    f(x, roseFoldList z rs)
  end


val () =
  Test.string
    ( "roseFoldr0"
    , "z312"
    , roseFoldr
        (fn (x, ac) => ac ^ Int.toString x)
        "z"
        (Rose (2, [Rose (1, []), Rose (3, [])]))
    )

