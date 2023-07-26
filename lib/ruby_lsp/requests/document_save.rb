# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Requests
    class DocumentSave < Listener
      extend T::Sig

      ResponseType = type_member { { fixed: T.untyped } }

      sig { override.returns(ResponseType) }
      attr_reader :response

      sig do
        params(
          emitter: EventEmitter,
          message_queue: Thread::Queue,
        ).void
      end
      def initialize(emitter, message_queue)
        super(emitter, message_queue)

        @response = T.let(VOID, Object)
      end
    end
  end
end
