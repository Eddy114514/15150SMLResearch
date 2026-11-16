(* task1 : ('a -> 'b) -> 'a -> 'b *)
fun task1 f a = f a

(* task2 : ('a -> bool) -> 'a -> ('a -> 'b) -> (unit -> 'b) -> 'b *)
fun task2 p a sc fc = if p a then sc a
                      else fc ()

(* task3 : ('a -> 'b) -> 'a list -> ('b list -> 'c) -> 'c *)
fun task3 aTob al blToc = blToc (List.map aTob al)