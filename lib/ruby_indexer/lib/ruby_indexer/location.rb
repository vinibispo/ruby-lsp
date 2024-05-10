# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class Location
    class << self
      extend T::Sig

      sig { params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
      def json_create(hash)
        new(
          hash["start_line"],
          hash["end_line"],
          hash["start_column"],
          hash["end_column"],
        )
      end
    end

    extend T::Sig

    sig { returns(Integer) }
    attr_reader :start_line, :end_line, :start_column, :end_column

    sig do
      params(
        start_line: Integer,
        end_line: Integer,
        start_column: Integer,
        end_column: Integer,
      ).void
    end
    def initialize(start_line, end_line, start_column, end_column)
      @start_line = start_line
      @end_line = end_line
      @start_column = start_column
      @end_column = end_column
    end

    sig { params(args: T.untyped).returns(String) }
    def to_json(*args)
      {
        start_line: @start_line,
        end_line: @end_line,
        start_column: @start_column,
        end_column: @end_column,
      }.to_json
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      other.is_a?(Location) && other.start_line == @start_line && other.end_line == @end_line &&
        other.start_column == @start_column && other.end_column == @end_column
    end
  end
end
