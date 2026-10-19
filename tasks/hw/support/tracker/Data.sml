(* Generation budgets only: 1..6 mascots, 0..6 chats, resolution 0..6.
 * A Boolean mask selects each chat's distinct, valid member indices. *)
structure TrackerData = struct
  structure G = QCheck.Gen
  fun forSize n =
    let
      val nodes = List.tabulate (n,fn i => i)
      val chat = G.map
        (fn flags => List.map #1 (List.filter #2 (ListPair.zip (nodes,flags))))
        (G.vector List.tabulate (G.lift n,G.flip))
    in G.map (fn (chats,source,resolution) => (n,chats,source,resolution))
         (G.zip3 (G.vector List.tabulate (G.range (0,6),chat),
                  G.range (0,n-1),G.range (0,6)))
    end
  val genInput = G.choose (Vector.tabulate (6,fn i => forSize (i+1)))
  val edges =
    [(1,[],0,0),
     (3,[],1,10),
     (3,[[],[1]],1,3),
     (3,[[0,1],[1,2]],0,0),
     (3,[[0,1],[1,2]],0,1),
     (3,[[0,1],[1,2]],0,2),
     (4,[[0,1],[2,3]],0,6),
     (3,[[0,1],[0,1],[1,2]],2,2),
     (4,[[3,0,2],[1,2]],3,2),
     (6,[[0,1],[2,1,3,5],[3,4]],0,2),
     (6,[[0,1],[2,1,3,5],[3,4]],0,3)]
  fun showInput (n,chats,source,resolution) = Runner.object
    [("mascots",Runner.int n),
     ("chats",Runner.list (Runner.list Runner.int) chats),
     ("source",Runner.int source),("resolution",Runner.int resolution)]
  val showOutput = Runner.list Runner.int
end
