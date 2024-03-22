# typed: strict
# frozen_string_literal: true

module RubyLsp
  class IndexingConfig
    extend T::Sig
    class << self
      extend T::Sig

      # TODO: signature
      sig { params(workspace_uri: URI::Generic).returns(T::Hash[String, T.untyped]) }
      def call(workspace_uri)
        # Need to use the workspace URI, otherwise, this will fail for people working on a project that is a symlink.
        index_path = File.join(workspace_uri.to_standardized_path, ".index.yml")
        ruby_lsp_path = File.join(workspace_uri.to_standardized_path, ".ruby-lsp.yml")

        if File.exist?(index_path)
          warn("The .index.yml configuration file is deprecated. Please rename it to .ruby-lsp.yml and update the
          structure as described in the README: https://github.com/Shopify/ruby-lsp#configuration")
          ".ruby-lsp.yml"
        end

        # begin
        indexing_config = if File.exist?(index_path)
          YAML.parse_file(index_path).to_ruby
        elsif File.exist?(ruby_lsp_path)
          YAML.parse_file(ruby_lsp_path).to_ruby.fetch("indexing") # TODO: handle exception
        else
          {}
          # end
        end
      end
    end
  end
end
