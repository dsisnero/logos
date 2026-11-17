module Logos
  alias GeneratedPatternIDs = ::Regex::Automata::PatternID | StaticArray(::Regex::Automata::PatternID, 2) | Array(::Regex::Automata::PatternID)
  # A failed match with a live byte prefix before the dead state or EOF.
  record GeneratedMiss, prefix_length : Int32

  alias GeneratedMatch = Tuple(Int32, GeneratedPatternIDs) | GeneratedMiss | Nil
  alias GeneratedMatcher = Proc(::Bytes, Int32, GeneratedMatch)

  # Effective manifest priorities and their explicitness for deferred ties.
  record GeneratedPriorities, values : Array(Int32), explicit : Array(Bool)?, resolved : Bool

  # Rule and source metadata emitted by current prebuilds.
  class GeneratedBinding
    def initialize(@utf8 : Bool, @rules : Array(Hash(String, String)), @subpatterns : Array({String, String, Bool}))
    end

    def validate(name : String, utf8 : Bool, rules : Array(Hash(String, String)), subpatterns : Array({String, String, Bool})) : Nil
      mismatch(name, "utf8") unless @utf8 == utf8
      mismatch(name, "rule count") unless @rules.size == rules.size
      mismatch(name, "subpatterns") unless @subpatterns == subpatterns
      @rules.each_with_index do |rule, index|
        rule.each do |field, value|
          mismatch(name, "rule #{index} #{field}") unless rules[index][field]? == value
        end
      end
    end

    private def mismatch(name : String, field : String) : NoReturn
      raise "Generated matcher binding for #{name} differs at #{field}. Regenerate the matcher from matching rules."
    end
  end

  # A snapshot keeps the matcher, binding, and priorities from one registration.
  # :nodoc:
  class GeneratedMatcherRegistration
    getter matcher : GeneratedMatcher
    getter priorities : GeneratedPriorities?
    getter binding : GeneratedBinding?

    def initialize(@matcher : GeneratedMatcher, @priorities : GeneratedPriorities?, @binding : GeneratedBinding?)
    end
  end

  # Held by the token enum so lexing can observe replacements without looking
  # up its name on each token.
  # :nodoc:
  class GeneratedMatcherSlot
    property registration : GeneratedMatcherRegistration?
  end

  @@generated_matchers = {} of String => GeneratedMatcherSlot

  # :nodoc:
  def self.generated_matcher_slot(name : String) : GeneratedMatcherSlot
    @@generated_matchers.put_if_absent(name) { GeneratedMatcherSlot.new }
  end

  def self.register_generated_matcher(name : String, matcher : GeneratedMatcher, priorities : Array(Int32)? = nil,
                                      *, explicit_priorities : Array(Bool)? = nil, resolved_priorities : Bool = false, binding : GeneratedBinding? = nil) : Nil
    metadata = GeneratedPriorities.new(priorities, explicit_priorities, resolved_priorities) if priorities
    generated_matcher_slot(name).registration = GeneratedMatcherRegistration.new(matcher, metadata, binding)
  end

  def self.generated_matcher?(name : String) : GeneratedMatcher?
    @@generated_matchers[name]?.try(&.registration).try(&.matcher)
  end

  # Default or resolved priorities supplied by the generated matcher.
  def self.generated_matcher_priorities?(name : String) : Array(Int32)?
    generated_matcher_priority_info?(name).try(&.values)
  end

  # Priority metadata available when the matcher returns multiple candidates.
  def self.generated_matcher_priority_info?(name : String) : GeneratedPriorities?
    @@generated_matchers[name]?.try(&.registration).try(&.priorities)
  end

  def self.generated_matcher_binding?(name : String) : GeneratedBinding?
    @@generated_matchers[name]?.try(&.registration).try(&.binding)
  end
end
