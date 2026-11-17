require "json"

module Logos
  # Serializes the same metadata used to bind a generated matcher.
  module PrebuildManifest
    def self.write(io : IO, name : String, utf8 : Bool, rules : Array(Hash(String, String)),
                   subpatterns : Array({String, String, Bool}), resolve_priorities : Bool) : Nil
      JSON.build(io, indent: "  ") do |json|
        json.object do
          json.field "name", name
          json.field "utf8", utf8
          json.field "validate_binding", true
          json.field "resolve_priorities", resolve_priorities
          json.field "subpatterns" do
            json.object do
              subpatterns.each do |sub_name, pattern, unicode|
                json.field sub_name, {pattern: encoded_pattern(pattern), bytes: !unicode}
              end
            end
          end
          json.field "patterns" do
            json.array do
              rules.each do |rule|
                declared_priority = rule["declared_priority"]
                priority = declared_priority.empty? ? nil : declared_priority.to_i
                variant = rule["variant"]
                json.object do
                  json.field "kind", rule["kind"]
                  json.field "pattern", encoded_pattern(rule["pattern"])
                  json.field "bytes", rule["unicode"] == "false"
                  json.field "ignore_case", rule["ignore_case"] == "true"
                  json.field "ignore_ascii_case", rule["ignore_ascii_case"] == "true"
                  json.field "allow_greedy", rule["allow_greedy"] == "true"
                  json.field "skip", rule["skip"] == "true"
                  json.field "variant", variant.empty? ? nil : variant
                  json.field "priority", priority
                  json.field "priority_explicit", !priority.nil?
                  json.field "declared_priority", priority
                end
              end
            end
          end
        end
      end
      io.puts
    end

    private def self.encoded_pattern(pattern : String) : String | Array(UInt8)
      pattern.valid_encoding? ? pattern : pattern.to_slice.to_a
    end
  end
end
