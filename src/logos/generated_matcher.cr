module Logos
  alias GeneratedPatternIDs = ::Regex::Automata::PatternID | StaticArray(::Regex::Automata::PatternID, 2) | Array(::Regex::Automata::PatternID)
  # A failed match with a live byte prefix before the dead state or EOF.
  record GeneratedMiss, prefix_length : Int32

  alias GeneratedMatch = Tuple(Int32, GeneratedPatternIDs) | GeneratedMiss | Nil
  alias GeneratedMatcher = Proc(::Bytes, Int32, GeneratedMatch)

  @@generated_matchers = {} of String => {GeneratedMatcher, Array(Int32)?}

  def self.register_generated_matcher(name : String, matcher : GeneratedMatcher, priorities : Array(Int32)? = nil) : Nil
    @@generated_matchers[name] = {matcher, priorities}
  end

  def self.generated_matcher?(name : String) : GeneratedMatcher?
    @@generated_matchers[name]?.try(&.[0])
  end

  # Default priorities inferred from the manifest's compiled patterns.
  def self.generated_matcher_priorities?(name : String) : Array(Int32)?
    @@generated_matchers[name]?.try(&.[1])
  end
end
