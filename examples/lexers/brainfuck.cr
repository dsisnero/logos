require "../../src/logos"

# Each Op variant is a single character.
Logos.define Op do
  # Skip all non-op characters (lowest priority).
  skip_regex ".|\n", :Skip, priority: 0

  token ">", :IncPointer
  token "<", :DecPointer
  token "+", :IncData
  token "-", :DecData
  token ".", :OutData
  token ",", :InpData
  token "[", :CondJumpForward
  token "]", :CondJumpBackward
end
