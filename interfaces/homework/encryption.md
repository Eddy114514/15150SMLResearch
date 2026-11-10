Shared ordinary payload/observation types:
type Affine.t = int * int
- Affine.apply : Affine.t -> int -> int. apply(a,b) x = a*x+b; requires arithmetic fits host Int for executed arguments.
type 'a EncryptionCase.triple = 'a * 'a * 'a
type EncryptionCase.input = {integers:int EncryptionCase.triple, strings:string EncryptionCase.triple, lists:int list EncryptionCase.triple, functions:Affine.t EncryptionCase.triple, probes:int list}
type 'a EncryptionCase.observations = {matrix:'a option list list, reused:'a option list, foreign:'a option list}
type EncryptionCase.output = {integers:int EncryptionCase.observations, strings:string EncryptionCase.observations, lists:int list EncryptionCase.observations, functions:int list EncryptionCase.observations}
- EncryptionCase.values : 'a EncryptionCase.triple -> 'a list. Convert triple to three values in order; no preconditions.
Each payload group creates three fresh keys and three secrets, preserving the first secret across later key creation. matrix rows are decrypting keys and columns encrypting keys, both creation order. reused holds first-key decryption after re-encrypting each of the three payloads with that first key. foreign holds first-key decryptions of the nine secrets from the other three payload groups, in output field order excluding this group. Function successes are SOME of the function's values at probes in order; NONE still means decryption failure. Actual keys, exn values, and closures never become predicate arguments. All keys are fresh for every target call. Finite probes do not prove arbitrary function equality.
The reference checks only this functional projection, not the original universal key/payload equalities. It uses IntInf to compare affine observations without overflowing inside the checker. Actual Affine.apply calls can raise Overflow; the harness records that execution exception separately. This observation limitation does not add a fits-host-Int condition to the original requires=true.
