structure TargetAdapter = struct
  fun run (r,text) = Target.accept (RegexTarget.regex r) text
end
