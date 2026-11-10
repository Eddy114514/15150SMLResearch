structure BbsModel = struct
  fun prime n = n >= 2 andalso
    let fun check d = d > n div d orelse
          (n mod d <> 0 andalso check (d+1))
    in check 2 end
  fun semiprime m = m >= 4 andalso
    let fun factor d = d <= m div d andalso
          (if m mod d = 0 then prime d andalso prime (m div d)
           else factor (d+1))
    in factor 2 end
end
