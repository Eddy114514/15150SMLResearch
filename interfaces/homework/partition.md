Shared finite CPS predicate and evidence descriptions:
datatype PartitionCase.predicate = Sum of IntInf.int | Length of int | All of CpsCase.predicate
type PartitionCase.input = int list * PartitionCase.predicate * PartitionCase.predicate
type PartitionCase.evidence = int list * (int * IntInf.int)
type PartitionCase.output = PartitionCase.evidence option
- PartitionCase.sum : int list -> IntInf.int. Mathematical sum; no preconditions.
- PartitionCase.accepts : PartitionCase.predicate -> int list -> bool. Sum target, Length target, or all values accepted by CpsCase.test. Total; no preconditions, including negative Length (accepts nothing).
- PartitionCase.summary : int list -> int * IntInf.int. Length and mathematical sum, no preconditions.
- PartitionModel.partitions : 'a list -> ('a list * 'a list) list. Enumerate every stable positional partition; each input position goes to exactly one side. No preconditions; exponential cost.
- PartitionModel.evidence : PartitionCase.input -> PartitionCase.evidence list. All accepted partitions' (left list,(right length,right sum)). No preconditions; duplicates/order irrelevant.
The adapter supplies total CPS predicates, SOME success and NONE failure; left evidence is the actual left subsequence, right evidence only its length/sum. Accept any allowed evidence, not a preferred reference witness. Observations do not identify the hidden right list beyond its summary, nor arbitrary continuations.
