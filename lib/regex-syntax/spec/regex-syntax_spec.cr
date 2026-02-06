require "./spec_helper"

describe Regex::Syntax do
  it "can be required" do
    # Just test that the module exists
    Regex::Syntax.should_not be_nil
  end

  it "has version constant" do
    Regex::Syntax::VERSION.should be_a(String)
  end

  it "defines Parser class" do
    parser = Regex::Syntax::Parser.new
    parser.should be_a(Regex::Syntax::Parser)
  end
end