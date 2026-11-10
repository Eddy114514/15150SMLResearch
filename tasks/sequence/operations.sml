(* @solution *)
(* @contract reverseSeqInt
 * reverseSeq : int Seq.seq -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as xs. At every valid zero-based
 *          index i, its element equals the element of xs at length(xs)-1-i.
 *          Every element occurrence, including duplicates, is preserved.
 *)
(* @contract reverseSeqBool
 * reverseSeq : bool Seq.seq -> bool Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as xs. At every valid zero-based
 *          index i, its Boolean element equals the element of xs at
 *          length(xs)-1-i. Every occurrence is preserved.
 *)
fun reverseSeq xs = Seq.rev xs

(* @contract flattenSeq
 * flattenSeq : int Seq.seq Seq.seq -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result concatenates all inner sequences of xss in their outer
 *          sequence order, preserving each inner sequence's order and every
 *          occurrence. Empty inner sequences contribute no elements.
 *)
fun flattenSeq xss = Seq.flatten xss

(* @contract leafFlags
 * leafFlags : Tree.tree Seq.seq -> bool Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as trees. At every valid zero-based
 *          index i, its Boolean is true if and only if the outermost constructor
 *          of the tree at index i is Tree.Leaf. For Tree.Node it is false,
 *          regardless of the constructors or integer labels below that node.
 *)
fun leafFlags trees = Seq.map (fn Tree.Leaf _ => true | Tree.Node _ => false) trees

(* @contract fromIntList
 * fromIntList : int list -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result contains exactly the integers in xs, in their original
 *          order, preserving every occurrence. Its length equals the length
 *          of xs; the empty list produces an empty sequence.
 *)
fun fromIntList xs = Seq.fromList xs
(* @manual seq_reverse_int *)
(* @contract reverseSeqInt
 * reverseSeq : int Seq.seq -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as xs. At every valid zero-based
 *          index i, its element equals the element of xs at length(xs)-1-i.
 *          Every element occurrence, including duplicates, is preserved.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int Seq.seq
  type output = int Seq.seq
  fun requires (input : input) : bool = let val xs = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val xs = input in (Seq.toList result = List.rev (Seq.toList xs)) end
end
(* @manual seq_reverse_bool *)
(* @contract reverseSeqBool
 * reverseSeq : bool Seq.seq -> bool Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as xs. At every valid zero-based
 *          index i, its Boolean element equals the element of xs at
 *          length(xs)-1-i. Every occurrence is preserved.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = bool Seq.seq
  type output = bool Seq.seq
  fun requires (input : input) : bool = let val xs = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val xs = input in (Seq.toList result = List.rev (Seq.toList xs)) end
end
(* @manual seq_flatten_int *)
(* @contract flattenSeq
 * flattenSeq : int Seq.seq Seq.seq -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result concatenates all inner sequences of xss in their outer
 *          sequence order, preserving each inner sequence's order and every
 *          occurrence. Empty inner sequences contribute no elements.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int Seq.seq Seq.seq
  type output = int Seq.seq
  fun requires (input : input) : bool = let val xss = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val xss = input in (Seq.toList result = List.concat (List.map Seq.toList (Seq.toList xss))) end
end
(* @manual seq_leaf_flags *)
(* @contract leafFlags
 * leafFlags : Tree.tree Seq.seq -> bool Seq.seq
 * REQUIRES: true
 * ENSURES: The result has the same length as trees. At every valid zero-based
 *          index i, its Boolean is true if and only if the outermost constructor
 *          of the tree at index i is Tree.Leaf. For Tree.Node it is false,
 *          regardless of the constructors or integer labels below that node.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = Tree.tree Seq.seq
  type output = bool Seq.seq
  fun requires (input : input) : bool = let val trees = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val trees = input in (Seq.toList result = List.map (fn Tree.Leaf _ => true | Tree.Node _ => false) (Seq.toList trees)) end
end
(* @manual list_to_seq *)
(* @contract fromIntList
 * fromIntList : int list -> int Seq.seq
 * REQUIRES: true
 * ENSURES: The result contains exactly the integers in xs, in their original
 *          order, preserving every occurrence. Its length equals the length
 *          of xs; the empty list produces an empty sequence.
 *)
functor ManualContract (Helpers : sig
end) = struct
  type input = int list
  type output = int Seq.seq
  fun requires (input : input) : bool = let val xs = input in (true) end
  fun ensures (input : input) (result : output) : bool = let val xs = input in (Seq.toList result = xs) end
end
