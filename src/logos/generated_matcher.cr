module Logos
  alias GeneratedPatternIDs = ::Regex::Automata::PatternID | StaticArray(::Regex::Automata::PatternID, 2) | Array(::Regex::Automata::PatternID)
  # A failed match with a live byte prefix before the dead state or EOF.
  record GeneratedMiss, prefix_length : Int32

  alias GeneratedMatch = Tuple(Int32, GeneratedPatternIDs) | GeneratedMiss | Nil
  alias GeneratedMatcher = Proc(::Bytes, Int32, GeneratedMatch)

  # Effective manifest priorities and their explicitness for deferred ties.
  record GeneratedPriorities, values : Array(Int32), explicit : Array(Bool)?, resolved : Bool

  @@generated_matchers = {} of String => {GeneratedMatcher, GeneratedPriorities?}

  def self.register_generated_matcher(name : String, matcher : GeneratedMatcher, priorities : Array(Int32)? = nil,
                                      *, explicit_priorities : Array(Bool)? = nil, resolved_priorities : Bool = false) : Nil
    metadata = GeneratedPriorities.new(priorities, explicit_priorities, resolved_priorities) if priorities
    @@generated_matchers[name] = {matcher, metadata}
  end

  def self.generated_matcher?(name : String) : GeneratedMatcher?
    @@generated_matchers[name]?.try(&.[0])
  end

  # Default or resolved priorities supplied by the generated matcher.
  def self.generated_matcher_priorities?(name : String) : Array(Int32)?
    generated_matcher_priority_info?(name).try(&.values)
  end

  # Priority metadata available when the matcher returns multiple candidates.
  def self.generated_matcher_priority_info?(name : String) : GeneratedPriorities?
    @@generated_matchers[name]?.try(&.[1])
  end
end
