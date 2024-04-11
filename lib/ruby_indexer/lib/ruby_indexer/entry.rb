# typed: strict
# frozen_string_literal: true

module Prism
  class Location
    def to_json(*args)
      {
        source: @source.to_json,
        start_offset: @start_offset,
        length: @length,
      }
    end

    def self.json_create(hash)
      new(Source.json_create(hash["source"]), hash["start_offset"], hash["length"])
    end
  end

  class Source
    def to_json(*args)
      {
        source: @source,
        start_line: @start_line,
        offsets: @offsets,
      }
    end

    def self.json_create(hash)
      new(hash["source"], hash["start_line"], hash["offsets"])
    end
  end
end

module RubyIndexer
  class Entry
    extend T::Sig

    sig { returns(String) }
    attr_reader :name

    sig { returns(String) }
    attr_reader :file_path

    sig { returns(Prism::Location) }
    attr_reader :location

    sig { returns(T::Array[String]) }
    attr_reader :comments

    sig { returns(Symbol) }
    attr_accessor :visibility

    sig { params(name: String, file_path: String, location: Prism::Location, comments: T::Array[String]).void }
    def initialize(name, file_path, location, comments)
      @name = name
      @file_path = file_path
      # start_line, end_line, start_column, end_column
      @location = location
      @comments = comments
      @visibility = T.let(:public, Symbol)
    end

    sig { returns(String) }
    def file_name
      File.basename(@file_path)
    end

    sig { abstract.params(args: T.untyped).returns(String) }
    def to_json(*args); end

    sig { abstract.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
    def self.json_create(hash); end

    def to_json(*arg)
      kind = { "entry_kind": self.class.name.split("::").last }

      hash = instance_variables.to_h do |variable_name|
        value = instance_variable_get(variable_name)
        [variable_name, value.to_json(*arg)]
      end

      kind.merge(hash)
    end

    def self.json_create(hash)
      entry_kind = hash["entry_kind"]
      # debugger
      # const_get(entry_kind).json_create(hash)

      case entry_kind
      when "Namespace"
        Namespace.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
        )
      when "Module"
        Module.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          hash["@comments"],
        )
      when "Class"
        Class.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
          JSON.parse(hash["@parent_class"]),
        )
      when "Constant"
        Constant.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
        )
      when "Accessor"
        Accessor.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
          JSON.parse(hash["@owner"]),
        )
      when "SingletonMethod"
        SingletonMethod.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
          Prism::ParametersNode.json_create(hash["@parameters_node"]),
          JSON.parse(hash["@owner"]),
        )
      when "InstanceMethod"
        InstanceMethod.new(
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
          Prism::ParametersNode.json_create(hash["@parameters_node"]),
          JSON.parse(hash["@owner"]),
        )
      when "UnresolvedAlias"
        UnresolvedAlias.new(
          hash["@target"],
          JSON.parse(hash["@nesting"]),
          hash["@name"],
          hash["@file_path"],
          Prism::Location.json_create(hash["@location"]),
          JSON.parse(hash["@comments"]),
        )
      when "Alias"
        Alias.new(
          hash["@target"],
          UnresolvedAlias.json_create(JSON.parse(hash["@unresolved_alias"])),
        )
      else
        raise StandardError, "Unknown entry kind: #{entry_kind}"
      end
    end

    class Namespace < Entry
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(T::Array[String]) }
      attr_accessor :included_modules

      sig do
        params(
          name: String,
          file_path: String,
          location: Prism::Location,
          comments: T::Array[String],
        ).void
      end
      def initialize(name, file_path, location, comments)
        super(name, file_path, location, comments)
        @included_modules = T.let([], T::Array[String])
      end

      sig { returns(String) }
      def short_name
        T.must(@name.split("::").last)
      end

      sig { abstract.params(args: T.untyped).returns(String) }
      def to_json(*args); end
    end

    class Module < Namespace
      extend T::Sig

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Module",
        }.to_json
      end
    end

    class Class < Namespace
      extend T::Sig

      # The unresolved name of the parent class. This may return `nil`, which indicates the lack of an explicit parent
      # and therefore ::Object is the correct parent class
      sig { returns(T.nilable(String)) }
      attr_reader :parent_class

      sig do
        params(
          name: String,
          file_path: String,
          location: Prism::Location,
          comments: T::Array[String],
          parent_class: T.nilable(String),
        ).void
      end
      def initialize(name, file_path, location, comments, parent_class)
        super(name, file_path, location, comments)
        @parent_class = T.let(parent_class, T.nilable(String))
      end
    end

    class Constant < Entry
    end

    class Parameter
      extend T::Helpers
      extend T::Sig

      abstract!

      # Name includes just the name of the parameter, excluding symbols like splats
      sig { returns(Symbol) }
      attr_reader :name

      # Decorated name is the parameter name including the splat or block prefix, e.g.: `*foo`, `**foo` or `&block`
      alias_method :decorated_name, :name

      sig { params(name: Symbol).void }
      def initialize(name:)
        @name = name
      end
    end

    # A required method parameter, e.g. `def foo(a)`
    class RequiredParameter < Parameter
    end

    # An optional method parameter, e.g. `def foo(a = 123)`
    class OptionalParameter < Parameter
    end

    # An required keyword method parameter, e.g. `def foo(a:)`
    class KeywordParameter < Parameter
      sig { override.returns(Symbol) }
      def decorated_name
        :"#{@name}:"
      end
    end

    # An optional keyword method parameter, e.g. `def foo(a: 123)`
    class OptionalKeywordParameter < Parameter
      sig { override.returns(Symbol) }
      def decorated_name
        :"#{@name}:"
      end
    end

    # A rest method parameter, e.g. `def foo(*a)`
    class RestParameter < Parameter
      DEFAULT_NAME = T.let(:"<anonymous splat>", Symbol)

      sig { override.returns(Symbol) }
      def decorated_name
        :"*#{@name}"
      end
    end

    # A keyword rest method parameter, e.g. `def foo(**a)`
    class KeywordRestParameter < Parameter
      DEFAULT_NAME = T.let(:"<anonymous keyword splat>", Symbol)

      sig { override.returns(Symbol) }
      def decorated_name
        :"**#{@name}"
      end
    end

    # A block method parameter, e.g. `def foo(&block)`
    class BlockParameter < Parameter
      DEFAULT_NAME = T.let(:"<anonymous block>", Symbol)

      sig { override.returns(Symbol) }
      def decorated_name
        :"&#{@name}"
      end
    end

    class Member < Entry
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(T.nilable(Entry::Namespace)) }
      attr_reader :owner

      sig do
        params(
          name: String,
          file_path: String,
          location: Prism::Location,
          comments: T::Array[String],
          owner: T.nilable(Entry::Namespace),
        ).void
      end
      def initialize(name, file_path, location, comments, owner)
        super(name, file_path, location, comments)
        @owner = owner
      end

      sig { abstract.returns(T::Array[Parameter]) }
      def parameters; end
    end

    class Accessor < Member
      extend T::Sig

      sig { override.returns(T::Array[Parameter]) }
      def parameters
        params = []
        params << RequiredParameter.new(name: name.delete_suffix("=").to_sym) if name.end_with?("=")
        params
      end
    end

    class Method < Member
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { override.returns(T::Array[Parameter]) }
      attr_reader :parameters

      sig do
        params(
          name: String,
          file_path: String,
          location: Prism::Location,
          comments: T::Array[String],
          parameters_node: T.nilable(Prism::ParametersNode),
          owner: T.nilable(Entry::Namespace),
        ).void
      end
      def initialize(name, file_path, location, comments, parameters_node, owner) # rubocop:disable Metrics/ParameterLists
        super(name, file_path, location, comments, owner)

        @parameters = T.let(list_params(parameters_node), T::Array[Parameter])
      end

      private

      sig { params(parameters_node: T.nilable(Prism::ParametersNode)).returns(T::Array[Parameter]) }
      def list_params(parameters_node)
        return [] unless parameters_node

        parameters = []

        parameters_node.requireds.each do |required|
          name = parameter_name(required)
          next unless name

          parameters << RequiredParameter.new(name: name)
        end

        parameters_node.optionals.each do |optional|
          name = parameter_name(optional)
          next unless name

          parameters << OptionalParameter.new(name: name)
        end

        parameters_node.keywords.each do |keyword|
          name = parameter_name(keyword)
          next unless name

          case keyword
          when Prism::RequiredKeywordParameterNode
            parameters << KeywordParameter.new(name: name)
          when Prism::OptionalKeywordParameterNode
            parameters << OptionalKeywordParameter.new(name: name)
          end
        end

        rest = parameters_node.rest

        if rest.is_a?(Prism::RestParameterNode)
          rest_name = rest.name || RestParameter::DEFAULT_NAME
          parameters << RestParameter.new(name: rest_name)
        end

        keyword_rest = parameters_node.keyword_rest

        if keyword_rest.is_a?(Prism::KeywordRestParameterNode)
          keyword_rest_name = parameter_name(keyword_rest) || KeywordRestParameter::DEFAULT_NAME
          parameters << KeywordRestParameter.new(name: keyword_rest_name)
        end

        parameters_node.posts.each do |post|
          name = parameter_name(post)
          next unless name

          parameters << RequiredParameter.new(name: name)
        end

        block = parameters_node.block
        parameters << BlockParameter.new(name: block.name || BlockParameter::DEFAULT_NAME) if block

        parameters
      end

      sig { params(node: T.nilable(Prism::Node)).returns(T.nilable(Symbol)) }
      def parameter_name(node)
        case node
        when Prism::RequiredParameterNode, Prism::OptionalParameterNode,
          Prism::RequiredKeywordParameterNode, Prism::OptionalKeywordParameterNode,
          Prism::RestParameterNode, Prism::KeywordRestParameterNode
          node.name
        when Prism::MultiTargetNode
          names = node.lefts.map { |parameter_node| parameter_name(parameter_node) }

          rest = node.rest
          if rest.is_a?(Prism::SplatNode)
            name = rest.expression&.slice
            names << (rest.operator == "*" ? "*#{name}".to_sym : name&.to_sym)
          end

          names << nil if rest.is_a?(Prism::ImplicitRestNode)

          names.concat(node.rights.map { |parameter_node| parameter_name(parameter_node) })

          names_with_commas = names.join(", ")
          :"(#{names_with_commas})"
        end
      end
    end

    class SingletonMethod < Method
    end

    class InstanceMethod < Method
    end

    # An UnresolvedAlias points to a constant alias with a right hand side that has not yet been resolved. For
    # example, if we find
    #
    # ```ruby
    #   CONST = Foo
    # ```
    # Before we have discovered `Foo`, there's no way to eagerly resolve this alias to the correct target constant.
    # All aliases are inserted as UnresolvedAlias in the index first and then we lazily resolve them to the correct
    # target in [rdoc-ref:Index#resolve]. If the right hand side contains a constant that doesn't exist, then it's not
    # possible to resolve the alias and it will remain an UnresolvedAlias until the right hand side constant exists
    class UnresolvedAlias < Entry
      extend T::Sig

      sig { returns(String) }
      attr_reader :target

      sig { returns(T::Array[String]) }
      attr_reader :nesting

      sig do
        params(
          target: String,
          nesting: T::Array[String],
          name: String,
          file_path: String,
          location: Prism::Location,
          comments: T::Array[String],
        ).void
      end
      def initialize(target, nesting, name, file_path, location, comments) # rubocop:disable Metrics/ParameterLists
        super(name, file_path, location, comments)

        @target = target
        @nesting = nesting
      end
    end

    # Alias represents a resolved alias, which points to an existing constant target
    class Alias < Entry
      extend T::Sig

      sig { returns(String) }
      attr_reader :target

      sig { params(target: String, unresolved_alias: UnresolvedAlias).void }
      def initialize(target, unresolved_alias)
        super(unresolved_alias.name, unresolved_alias.file_path, unresolved_alias.location, unresolved_alias.comments)

        @target = target
      end
    end
  end
end
