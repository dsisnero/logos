require "./spec_helper"
require "../src/regex/syntax/either"

describe Regex::Syntax::Either do
  it "stores left values like the vendored helper" do
    value = Regex::Syntax::Either(Int32, String).left(7)

    value.left?.should be_true
    value.right?.should be_false
    value.left!.should eq(7)
  end

  it "stores right values like the vendored helper" do
    value = Regex::Syntax::Either(Int32, String).right("ok")

    value.right?.should be_true
    value.left?.should be_false
    value.right!.should eq("ok")
  end
end
