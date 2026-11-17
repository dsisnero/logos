require "../spec_helper"

{% if flag?(:package_qualification) %}
  require "file_utils"

  module Logos::Spec::Package
    ROOT = File.expand_path("../..", __DIR__)
    @@directory : String?

    def self.command(binary : String, args : Array(String), directory : String, env = {} of String => String) : String
      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(binary, args, chdir: directory, env: env, output: output, error: error)
      raise "#{binary} #{args.join(' ')} failed:\n#{output}#{error}" unless status.success?
      output.to_s
    end

    def self.directory : String
      @@directory ||= begin
        temp = File.join(ROOT, "temp")
        FileUtils.mkdir_p(temp)
        directory = File.tempname("package-", nil, dir: temp)
        FileUtils.mkdir_p(directory)
        %w[src spec examples benchmarks docs Makefile shard.yml shard.lock README.md LICENSE].each do |path|
          FileUtils.cp_r(File.join(ROOT, path), File.join(directory, path))
        end
        cache = File.join(directory, "shard-cache")
        existing_cache = ENV["SHARDS_CACHE_PATH"]? ||
                         File.join(ENV["XDG_CACHE_HOME"]? || File.join(Path.home.to_s, ".cache"), "shards")
        %w[github.com/dsisnero/regex-automata.git github.com/dsisnero/regex-syntax.git github.com/crystal-ameba/ameba.git].each do |repo|
          destination = File.join(cache, repo)
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp_r(File.join(existing_cache, repo), destination)
        end
        ENV["SHARDS_CACHE_PATH"] = cache
        ENV["CRYSTAL_CACHE_DIR"] = File.join(directory, "crystal-cache")
        ENV.delete("CRYSTAL_PATH")
        lock = File.read(File.join(directory, "shard.lock"))
        command("shards", ["install", "--frozen", "--local"], directory)
        File.read(File.join(directory, "shard.lock")).should eq(lock)
        command("shards", ["build", "logos-codegen"], directory)
        consumer = File.join(directory, "consumer")
        FileUtils.mkdir_p(consumer)
        File.write(File.join(consumer, "shard.yml"), "name: logos_consumer\nversion: 0.1.0\ndependencies:\n  logos:\n    path: ..\n")
        command("shards", ["install", "--local"], consumer)
        directory
      end
    end

    def self.readme_block(index : Int32) : String
      File.read(File.join(directory, "README.md")).scan(/\x60{3}crystal\n(.*?)\n\x60{3}/m)[index][1]
    end
  end

  describe "installed package" do
    it "runs the README quick start through a separate consumer" do
      directory = Logos::Spec::Package.directory
      consumer = File.join(directory, "consumer")
      File.write(File.join(consumer, "quick_start.cr"), Logos::Spec::Package.readme_block(0))
      output = Logos::Spec::Package.command("crystal", ["run", "quick_start.cr"], consumer)
      output.should eq("KeywordFn: fn\nIdentifier: hello\nAssign: =\nNumber: 42\n")
    end

    it "executes the README annotations with the advertised byte spans" do
      directory = Logos::Spec::Package.directory
      consumer = File.join(directory, "consumer")
      section = File.read(File.join(directory, "README.md")).split("## Annotation-based API", 2)[1]
      block = section.match(/\x60{3}crystal\n(.*?)\n\x60{3}/m) || raise "missing README annotation sample"
      File.write(File.join(consumer, "annotations.cr"), block[1] + "\n" + <<-'CRYSTAL'
        stream = lexer.spanned.to_a
        raise "wrong annotation spans" unless stream.map(&.[1]) == [0...3, 4...8, 9...11]
        raise "wrong annotation tokens" unless stream.map(&.[0].unwrap) == [Token::KeywordLet, Token::Hex, Token::Number]
        CRYSTAL
      )
      Logos::Spec::Package.command("crystal", ["run", "annotations.cr"], consumer).should be_empty
    end

    it "qualifies shipped contracts through the built CLI and isolated dependencies" do
      directory = Logos::Spec::Package.directory
      binary = File.join(directory, "bin/logos-codegen")
      env = {"LOGOS_CODEGEN_BIN" => binary}
      output = Logos::Spec::Package.command("crystal",
        ["spec", "-Dcodegen_library", "spec/logos/prebuilt_examples_spec.cr"], directory, env)
      output.should contain("4 examples, 0 failures, 0 errors")
    end
  end
{% end %}
