module Logos
  alias GeneratedMatch = Tuple(Int32, Array(::Regex::Automata::PatternID))?
  alias GeneratedMatcher = Proc(::Bytes, Int32, GeneratedMatch)

  @@generated_matchers = {} of String => GeneratedMatcher

  def self.register_generated_matcher(name : String, matcher : GeneratedMatcher) : Nil
    @@generated_matchers[name] = matcher
  end

  def self.generated_matcher?(name : String) : GeneratedMatcher?
    @@generated_matchers[name]?
  end
end
