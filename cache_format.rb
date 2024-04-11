# typed: strict
# frozen_string_literal: true

require "bundler/setup"
require "ruby_lsp/internal"
require "benchmark/ips"

index = RubyIndexer::Index.new
index.index_all
entries = index.instance_variable_get(:@entries)

entries_json = entries.to_json
entries_marshal = Marshal.dump(entries)

RubyVM::YJIT.enable

# Benchmark.ips do |x|
#   x.report("json") { JSON.parse(entries_json) }
#   x.report("marshal") { Marshal.load(entries_marshal) }
#   x.compare!
# end

puts Marshal.load(entries_marshal)
