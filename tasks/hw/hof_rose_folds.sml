(* @solution *)
datatype 'a rose = Rose of 'a * 'a rose list

fun roseFoldl (f : 'a * 'b -> 'b) (z : 'b) (Rose (x, rs) : 'a rose) : 'b =
  let
    fun roseFoldList z [] = z
      | roseFoldList z (r::rs) = roseFoldList (roseFoldl f z r) rs
  in
    roseFoldList (f(x,z)) rs
  end

fun roseFoldr (f : 'a * 'b -> 'b) (z : 'b) (Rose (x, rs) : 'a rose) : 'b =
  let
    fun roseFoldList z [] = z
      | roseFoldList z (r::rs) =  roseFoldr f (roseFoldList z rs) r
  in
    f(x, roseFoldList z rs)
  end

(* @manual hw_hof_rose_folds *)
(* @contract roseFolds
 * roseFoldl, roseFoldr : ('a * 'b -> 'b) -> 'b -> 'a rose -> 'b
 * REQUIRES: true. This instance supplies total int * string -> string reducers.
 * ENSURES: Observe both folds. Each result equals the corresponding Basis list
 * fold over the rose's preorder values, with the supplied reducer and initial
 * accumulator. Child order, repeated values, and the initial accumulator matter.
 * The handout permits preorder for specifications, but forbids it in solutions.
 *)
functor ManualContract (Helpers : sig end) = struct
  type input = RoseFoldCase.reducer * string * RoseFoldCase.rose
  type output = string * string
  fun requires (_ : input) = true
  fun preorder (RoseFoldCase.Rose(x,children)) =
    x :: List.concat (List.map preorder children)
  fun ensures (reducer,initial,tree) (left,right) =
    let val values = preorder tree
        val f = RoseFoldCase.apply reducer
    in left = List.foldl f initial values andalso
       right = List.foldr f initial values
    end
end
