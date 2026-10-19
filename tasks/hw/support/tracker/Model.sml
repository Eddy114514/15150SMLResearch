(* All-pairs shortest distances on the chat relation, independent of the
 * target's repeated frontier expansion and its Utils implementation. *)
structure TrackerModel = struct
  fun receivers (n,chats,source,resolution) =
    let
      val nodes = List.tabulate (n,fn i => i)
      (* n exceeds every finite shortest distance in an n-node graph. *)
      val infinity = IntInf.fromInt n
      fun adjacent (i,j) = List.exists
        (fn chat => Spec.member i chat andalso Spec.member j chat) chats
      val initial = List.map (fn i => List.map
        (fn j => if i = j then 0 else if adjacent (i,j) then 1 else infinity)
        nodes) nodes
      fun via (k,distances) =
        let fun distance i j = List.nth (List.nth (distances,i),j)
        in List.map (fn i => List.map (fn j =>
             IntInf.min (distance i j,distance i k + distance k j)) nodes) nodes
        end
      val distances = List.foldl via initial nodes
      val fromSource = List.nth (distances,source)
    in List.filter (fn j =>
         let val distance = List.nth (fromSource,j)
         in distance < infinity andalso distance <= IntInf.fromInt resolution end)
         nodes
    end
end
