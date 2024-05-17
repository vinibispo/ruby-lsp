# typed: strict
# frozen_string_literal: true

# require "ruby_lsp/listeners/references"

# https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_references

module RubyLsp
  module Requests
    class References < Request
      extend T::Sig
      extend T::Generic

      sig do
        params(
          document: Document,
          global_state: GlobalState,
          position: T::Hash[Symbol, T.untyped],
          dispatcher: Prism::Dispatcher,
          typechecker_enabled: T::Boolean,
        ).void
      end
      def initialize(document, global_state, position, dispatcher, typechecker_enabled)
        super()
      end

      sig { override.returns(T::Array[Interface::Location]) }
      def perform
        []
      end
    end
  end
end
