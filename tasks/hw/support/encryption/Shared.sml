(* Printable payload descriptions and observations; keys and secrets stay in Target. *)
structure EncryptionCase = struct
  type 'a triple = 'a * 'a * 'a
  type input = {integers : int triple, strings : string triple,
                lists : int list triple, functions : Affine.t triple,
                probes : int list}
  type 'a observations = {matrix : 'a option list list,
                          reused : 'a option list,
                          foreign : 'a option list}
  type output = {integers : int observations, strings : string observations,
                 lists : int list observations, functions : int list observations}

  fun values (x,y,z) = [x,y,z]
end
