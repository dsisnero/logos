module Logos
  alias GeneratedPatternIDs = ::Regex::Automata::PatternID | StaticArray(::Regex::Automata::PatternID, 2) | Array(::Regex::Automata::PatternID)
  alias GeneratedMatch = Tuple(Int32, GeneratedPatternIDs)?
  alias GeneratedMatcher = Proc(::Bytes, Int32, GeneratedMatch)

  @@generated_matchers = {} of String => GeneratedMatcher

  def self.register_generated_matcher(name : String, matcher : GeneratedMatcher) : Nil
    @@generated_matchers[name] = matcher
  end

  def self.generated_matcher?(name : String) : GeneratedMatcher?
    @@generated_matchers[name]?
  end
end
