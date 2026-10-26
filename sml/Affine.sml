(* Printable affine function descriptions shared by HOF test instances. *)
structure Affine = struct
  type t = int * int
  fun apply (a,b) x = a*x+b
end
