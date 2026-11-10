Shared input datatype (also used for lazy-tree observations):
datatype SymmetryInput.tree = Empty | Node of SymmetryInput.tree * int * SymmetryInput.tree.
Use fully qualified constructors SymmetryInput.Empty and SymmetryInput.Node. This is a finite ordinary tree; it does not expose the student's generative tree datatype. No function is needed to inspect it. Symmetry concerns shape, not equality of labels.
