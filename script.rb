#!/usr/bin/env ruby
# typed: true
# frozen_string_literal: true

require "bundler/setup"
require_relative "lib/ruby_lsp/internal"
require "json"
require "debug"

# [{ kind: "Module"}, ]

i = RubyIndexer::Index.new
i.index_all
json = JSON.pretty_generate(i.instance_variable_get(:@entries).first.last.last.to_json)
puts json
debugger
entry = RubyIndexer::Entry.json_create(JSON.parse(json))
puts entry
