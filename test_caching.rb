# typed: strict
# frozen_string_literal: true

require "bundler/setup"
require "ruby_lsp/internal"
require "benchmark"

index = RubyIndexer::Index.new
indexables = RubyIndexer.configuration.indexables
indexables.select! do |indexable|
  indexable.full_path.start_with?(Bundler.bundle_path.to_s)
end

puts indexables.map(&:full_path)

RubyVM::YJIT.enable

normal = Benchmark.realtime do
  index.index_all(indexable_paths: indexables)
end

puts normal

index_cached = RubyIndexer::Index.new

cached = Benchmark.realtime do
  index_cached.import_from_cache
end

puts cached
