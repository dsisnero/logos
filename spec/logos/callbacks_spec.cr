require "../spec_helper"
require "regex-automata"

module Logos::Spec::Callbacks
  pending "callback returning values (token variants with associated data)" do
    it "parses numbers with callbacks returning values" do
      # Requires token variants with associated data (logos-gwz)
      # Callback returns parsed i64 or f64 value
      # Token::Integer(i64), Token::Float(f64)
    end
  end

  pending "callback returning bool (filter callbacks)" do
    it "uses boolean callbacks for custom matching logic" do
      # Requires boolean filter callbacks (logos-9me)
      # Callback returns true/false to indicate match success
      # Used for raw string parsing, Lua brackets, etc.
    end
  end

  pending "callback returning Result<(), E> or Skip" do
    it "handles callbacks returning Result or Skip" do
      # Requires support for FilterResult::Error and FilterResult::Skip
      # Callback can return error or skip token
    end
  end

  pending "callback with lifetime annotations" do
    it "supports callbacks with nested lifetimes" do
      # Requires proper lifetime handling in callbacks
      # Token::Integer((&'a str, u64)) with nested tuple
      # Token::Text(Cow<'a, str>) with Cow type
    end
  end
end
