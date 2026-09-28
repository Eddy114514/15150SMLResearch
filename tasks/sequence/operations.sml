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
