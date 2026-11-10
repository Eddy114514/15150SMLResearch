Shared finite rose and reducer descriptions:
datatype RoseFoldCase.rose = Rose of int * RoseFoldCase.rose list
datatype RoseFoldCase.reducer = Append of string | Prepend of string | Bracket
- RoseFoldCase.apply : RoseFoldCase.reducer -> int * string -> string. Append sep maps (x,acc) to acc ^ sep ^ Int.toString x; Prepend sep to Int.toString x ^ sep ^ acc; Bracket to "(" ^ Int.toString x ^ ":" ^ acc ^ ")". Total, no preconditions.
- RoseModel.preorder : RoseFoldCase.rose -> int list. Independent root-first, children left-to-right traversal; repetitions retained. No preconditions.
The adapter constructs Target.Rose and returns (roseFoldl result,roseFoldr result) for the same reducer and initial accumulator. These are finite observations of a fixed total reducer family. The handout permits preorder in the specification even though student implementations may not use it.
