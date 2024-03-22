# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  class IndexConfigTest < Minitest::Test
    def test_returns_empty_hash_when_no_configuration_files_exist
      FileUtils.mv(".ruby-lsp.yml", ".ruby-lsp.yml.tmp")
      workspace_uri = URI::Generic.build(scheme: "file", host: nil, path: "/path/to/workspace")

      result = RubyLsp::IndexingConfig.call(workspace_uri)

      assert_empty(result)
    ensure
      FileUtils.mv(".ruby-lsp.yml.tmp", ".ruby-lsp.yml")
    end

    def test_supports_depecated_index_configuration_file
      FileUtils.mv(".ruby-lsp.yml", ".ruby-lsp.yml.tmp")
      File.write(".index.yml", <<~YAML)
        excluded_patterns:
        - "**/test/fixtures/**/*.rb"
      YAML
      workspace_uri = URI::Generic.build(scheme: "file", host: nil, path: Dir.pwd)

      result = RubyLsp::IndexingConfig.call(workspace_uri)

      assert_equal({ "excluded_patterns" => ["**/test/fixtures/**/*.rb"] }, result)
    ensure
      FileUtils.mv(".ruby-lsp.yml.tmp", ".ruby-lsp.yml")
      FileUtils.rm_f(".index.yml")
    end

    def test_supports_newer_configuration
      workspace_uri = URI::Generic.build(scheme: "file", host: nil, path: Dir.pwd)

      result = RubyLsp::IndexingConfig.call(workspace_uri)

      assert_equal({ "excluded_patterns" => ["**/test/fixtures/**/*.rb"] }, result)
    end
  end
end
