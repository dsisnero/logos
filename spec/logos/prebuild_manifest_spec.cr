require "../spec_helper"
require "../fixtures/prebuild_export_token"

Logos.define ExportByteToken do
  utf8 false
  regex "[ ]+", :Spaces
  token "\xFF", :Marker, bytes: true
end

describe "prebuild manifest export" do
  it "exports stable metadata for evaluated rules and raw bytes" do
    first = String.build { |io| ExportToken.write_prebuild_manifest(io) }
    String.build { |io| ExportToken.write_prebuild_manifest(io) }.should eq(first)
    manifest = JSON.parse(first)
    manifest["name"].as_s.should eq("ExportToken")
    manifest["validate_binding"].as_bool.should be_true
    manifest["subpatterns"]["digit"].should eq(JSON.parse(%({"pattern":"[0-9]","bytes":false})))

    skip, keyword, integer = manifest["patterns"].as_a
    skip["variant"].raw.should be_nil
    skip["skip"].as_bool.should be_true
    keyword["priority"].as_i.should eq(10)
    keyword["priority_explicit"].as_bool.should be_true
    integer["priority_explicit"].as_bool.should be_false

    bytes = JSON.parse(String.build { |io| ExportByteToken.write_prebuild_manifest(io) })
    bytes["utf8"].as_bool.should be_false
    bytes["patterns"].as_a.map(&.["kind"].as_s).should eq(["token", "regex"])
    marker = bytes["patterns"][0]
    marker["pattern"].as_a.map(&.as_i).should eq([255])
    marker["bytes"].as_bool.should be_true
  end
end
