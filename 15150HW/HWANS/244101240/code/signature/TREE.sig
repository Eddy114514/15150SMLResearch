signature TREE =
  sig
    type 'a tree
    exception NotFound
    val empty : unit -> 'a tree
    val insert : ('a * 'a -> order) -> 'a tree -> 'a -> 'a tree
    val isIn : ('a * 'a -> order) -> 'a tree  -> 'a -> bool
    val findRoot : 'a tree -> 'a
    val remove : ('a * 'a -> order) -> 'a tree -> 'a -> 'a tree
  end
