# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class Entry
    class << self
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
      def json_create(hash); end
    end

    extend T::Sig
    extend T::Helpers

    abstract!

    sig { returns(String) }
    attr_reader :name

    sig { returns(String) }
    attr_reader :file_path

    sig { returns(RubyIndexer::Location) }
    attr_reader :location

    sig { returns(T::Array[String]) }
    attr_reader :comments

    sig { returns(Symbol) }
    attr_accessor :visibility

    sig do
      params(
        name: String,
        file_path: String,
        location: T.any(Prism::Location, RubyIndexer::Location),
        comments: T::Array[String],
      ).void
    end
    def initialize(name, file_path, location, comments)
      @name = name
      @file_path = file_path
      @comments = comments
      @visibility = T.let(:public, Symbol)

      @location = T.let(
        if location.is_a?(Prism::Location)
          Location.new(
            location.start_line,
            location.end_line,
            location.start_column,
            location.end_column,
          )
        else
          location
        end,
        RubyIndexer::Location,
      )
    end

    sig { abstract.params(args: T.untyped).returns(String) }
    def to_json(*args); end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      other.is_a?(Entry) && other.file_path == @file_path && other.location == @location
    end

    sig { returns(String) }
    def file_name
      File.basename(@file_path)
    end

    class Namespace < Entry
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(T::Array[String]) }
      def included_modules
        @included_modules ||= T.let([], T.nilable(T::Array[String]))
      end

      sig { returns(T::Array[String]) }
      def prepended_modules
        @prepended_modules ||= T.let([], T.nilable(T::Array[String]))
      end
    end

    class Module < Namespace
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
          )
        end
      end

      extend T::Sig

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Module",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
        }.to_json
      end
    end

    class Class < Namespace
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
            hash["parent_class"],
          )
        end
      end

      extend T::Sig

      # The unresolved name of the parent class. This may return `nil`, which indicates the lack of an explicit parent
      # and therefore ::Object is the correct parent class
      sig { returns(T.nilable(String)) }
      attr_reader :parent_class

      sig do
        params(
          name: String,
          file_path: String,
          location: T.any(Prism::Location, RubyIndexer::Location),
          comments: T::Array[String],
          parent_class: T.nilable(String),
        ).void
      end
      def initialize(name, file_path, location, comments, parent_class)
        super(name, file_path, location, comments)
        @parent_class = T.let(parent_class, T.nilable(String))
      end

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Class",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
          parent_class: @parent_class,
        }.to_json
      end
    end

    class Constant < Entry
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
          )
        end
      end

      extend T::Sig

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Constant",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
        }.to_json
      end
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

      sig { params(args: T.untyped).returns(String) }
      def to_json(*args)
        { kind: T.must(self.class.name).split("::").last, name: @name }.to_json
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        other.is_a?(Parameter) && other.name == @name
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
          location: T.any(Prism::Location, RubyIndexer::Location),
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
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          owner_kind = hash.dig("owner", "kind")

          owner = case owner_kind
          when "Module"
            Module.json_create(hash["owner"])
          when "Class"
            Class.json_create(hash["owner"])
          end

          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
            owner,
          )
        end
      end

      extend T::Sig

      sig { override.returns(T::Array[Parameter]) }
      def parameters
        params = []
        params << RequiredParameter.new(name: name.delete_suffix("=").to_sym) if name.end_with?("=")
        params
      end

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Accessor",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
          owner: @owner,
        }.to_json
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
          location: T.any(Prism::Location, RubyIndexer::Location),
          comments: T::Array[String],
          parameters: T.nilable(T.any(Prism::ParametersNode, T::Array[Parameter])),
          owner: T.nilable(Entry::Namespace),
        ).void
      end
      def initialize(name, file_path, location, comments, parameters, owner) # rubocop:disable Metrics/ParameterLists
        super(name, file_path, location, comments, owner)

        @parameters = T.let(
          if parameters.is_a?(Array)
            parameters
          else
            list_params(parameters)
          end,
          T::Array[Parameter],
        )
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
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          owner_kind = hash.dig("owner", "kind")

          owner = case owner_kind
          when "Module"
            Module.json_create(hash["owner"])
          when "Class"
            Class.json_create(hash["owner"])
          end

          parameters = hash["parameters"].map do |parameter_hash|
            const_get(parameter_hash["kind"]).new(name: parameter_hash["name"].to_sym) # rubocop:disable Sorbet/ConstantsFromStrings
          end

          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
            parameters,
            owner,
          )
        end
      end

      extend T::Sig

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "SingletonMethod",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
          parameters: @parameters,
          owner: @owner,
        }.to_json
      end
    end

    class InstanceMethod < Method
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          owner_kind = hash.dig("owner", "kind")

          owner = case owner_kind
          when "Module"
            Module.json_create(hash["owner"])
          when "Class"
            Class.json_create(hash["owner"])
          end

          parameters = hash["parameters"].map do |parameter_hash|
            const_get(parameter_hash["kind"]).new(name: parameter_hash["name"].to_sym) # rubocop:disable Sorbet/ConstantsFromStrings
          end

          new(
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
            parameters,
            owner,
          )
        end
      end

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "InstanceMethod",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
          parameters: @parameters,
          owner: @owner,
        }.to_json
      end
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
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          new(
            hash["target"],
            hash["nesting"],
            hash["name"],
            hash["file_path"],
            RubyIndexer::Location.json_create(hash["location"]),
            hash["comments"],
          )
        end
      end

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
          location: T.any(Prism::Location, RubyIndexer::Location),
          comments: T::Array[String],
        ).void
      end
      def initialize(target, nesting, name, file_path, location, comments) # rubocop:disable Metrics/ParameterLists
        super(name, file_path, location, comments)

        @target = target
        @nesting = nesting
      end

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "UnresolvedAlias",
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
          target: @target,
          nesting: @nesting,
        }.to_json
      end
    end

    # Alias represents a resolved alias, which points to an existing constant target
    class Alias < Entry
      class << self
        extend T::Sig

        sig { override.params(hash: T::Hash[String, T.untyped]).returns(T.attached_class) }
        def json_create(hash)
          new(
            hash["target"],
            [
              hash["name"],
              hash["file_path"],
              RubyIndexer::Location.json_create(hash["location"]),
              hash["comments"],
            ],
          )
        end
      end

      extend T::Sig

      sig { returns(String) }
      attr_reader :target

      sig do
        params(
          target: String,
          unresolved_alias: T.any(
            UnresolvedAlias,
            [String, String, T.any(Prism::Location, RubyIndexer::Location), T::Array[String]],
          ),
        ).void
      end
      def initialize(target, unresolved_alias)
        if unresolved_alias.is_a?(UnresolvedAlias)
          super(unresolved_alias.name, unresolved_alias.file_path, unresolved_alias.location, unresolved_alias.comments)
        else
          super(*unresolved_alias)
        end

        @target = target
      end

      sig { override.params(args: T.untyped).returns(String) }
      def to_json(*args)
        {
          kind: "Alias",
          target: @target,
          name: @name,
          file_path: @file_path,
          location: @location,
          comments: @comments,
        }.to_json
      end
    end
  end
end
