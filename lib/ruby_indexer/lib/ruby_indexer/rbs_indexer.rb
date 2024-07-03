# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class RBSIndexer
    extend T::Sig

    sig { params(index: Index).void }
    def initialize(index)
      @index = index
    end

    sig { void }
    def index_ruby_core
      loader = RBS::EnvironmentLoader.new
      RBS::Environment.from_loader(loader).resolve_type_names

      loader.each_signature do |source, pathname, _buffer, declarations, _directives|
        process_signature(source, pathname, declarations)
      end
    end

    private

    sig do
      params(
        source: T.any(Symbol, String), # If source is from Ruby Core, it will be the string `:core`
        pathname: Pathname,
        declarations: T::Array[RBS::AST::Declarations::Base],
      ).void
    end
    def process_signature(source, pathname, declarations)
      declarations.each do |declaration|
        process_declaration(declaration, pathname)
      end
    end

    sig { params(declaration: RBS::AST::Declarations::Base, pathname: Pathname).void }
    def process_declaration(declaration, pathname)
      case declaration
      when RBS::AST::Declarations::Class
        handle_class_declaration(declaration, pathname)
      when RBS::AST::Declarations::Module
        handle_module_declaration(declaration, pathname)
      else # rubocop:disable Style/EmptyElse
        # Other kinds not yet handled
      end
    end

    sig { params(declaration: RBS::AST::Declarations::Class, pathname: Pathname).void }
    def handle_class_declaration(declaration, pathname)
      nesting = [declaration.name.name.to_s]
      file_path = pathname.to_s
      location = to_ruby_indexer_location(declaration.location)
      comments = Array(declaration.comment&.string)
      parent_class = declaration.super_class&.name&.name&.to_s
      class_entry = Entry::Class.new(nesting, file_path, location, location, comments, parent_class)
      add_declaration_mixins_to_entry(declaration, class_entry)
      @index.add(class_entry)
      declaration.members.each do |member|
        next unless member.is_a?(RBS::AST::Members::MethodDefinition)

        handle_method(member, class_entry)
      end
    end

    sig { params(declaration: RBS::AST::Declarations::Module, pathname: Pathname).void }
    def handle_module_declaration(declaration, pathname)
      nesting = [declaration.name.name.to_s]
      file_path = pathname.to_s
      location = to_ruby_indexer_location(declaration.location)
      comments = Array(declaration.comment&.string)
      module_entry = Entry::Module.new(nesting, file_path, location, location, comments)
      add_declaration_mixins_to_entry(declaration, module_entry)
      @index.add(module_entry)
      declaration.members.each do |member|
        next unless member.is_a?(RBS::AST::Members::MethodDefinition)

        handle_method(member, module_entry)
      end
    end

    sig { params(rbs_location: RBS::Location).returns(RubyIndexer::Location) }
    def to_ruby_indexer_location(rbs_location)
      RubyIndexer::Location.new(
        rbs_location.start_line,
        rbs_location.end_line,
        rbs_location.start_column,
        rbs_location.end_column,
      )
    end

    sig do
      params(
        declaration: T.any(RBS::AST::Declarations::Class, RBS::AST::Declarations::Module),
        entry: Entry::Namespace,
      ).void
    end
    def add_declaration_mixins_to_entry(declaration, entry)
      declaration.each_mixin do |mixin|
        name = mixin.name.name.to_s
        mixin_operation =
          case mixin
          when RBS::AST::Members::Include
            Entry::Include.new(name)
          when RBS::AST::Members::Extend
            Entry::Extend.new(name)
          when RBS::AST::Members::Prepend
            Entry::Prepend.new(name)
          end
        entry.mixin_operations << mixin_operation if mixin_operation
      end
    end

    sig { params(member: RBS::AST::Members::MethodDefinition, owner: Entry::Namespace).void }
    def handle_method(member, owner)
      name = member.name.name
      file_path = member.location.buffer.name
      location = to_ruby_indexer_location(member.location)
      comments = Array(member.comment&.string)

      visibility = case member.visibility
      when :private
        Entry::Visibility::PRIVATE
      when :protected
        Entry::Visibility::PROTECTED
      else
        Entry::Visibility::PUBLIC
      end

      real_owner = member.singleton? ? existing_or_new_singleton_klass(owner) : owner
      signatures = signatures(member)
      @index.add(Entry::Method.new(name, file_path, location, location, comments, signatures, visibility, real_owner))
    end

    sig { params(member: RBS::AST::Members::MethodDefinition).returns(T::Array[Entry::Signature]) }
    def signatures(member)
      member.overloads.map do |overload|
        parameters = process_overload(overload)
        Entry::Signature.new(parameters)
      end
    end

    sig { params(overload: RBS::AST::Members::MethodDefinition::Overload).returns(T::Array[Entry::Parameter]) }
    def process_overload(overload)
      function = T.cast(overload.method_type.type, RBS::Types::Function)
      parameters = []
      parameters += process_required_positionals(function) if function.required_positionals
      parameters += process_optional_positionals(function) if function.optional_positionals
      parameters += process_required_keywords(function) if function.required_keywords
      parameters += process_optional_keywords(function) if function.optional_keywords
      parameters += process_trailing_positionals(function) if function.trailing_positionals
      parameters += process_rest_positionals(function) if function.rest_positionals

      block = overload.method_type.block
      parameters += process_block(block) if block&.required

      parameters
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::RequiredParameter]) }
    def process_required_positionals(function)
      function.required_positionals.map do |param|
        name = param.name || :anon # TODO: consider how to handle

        Entry::RequiredParameter.new(name: name)
      end
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::RestParameter]) }
    def process_rest_positionals(function)
      rest = function.rest_positionals

      rest_name = rest.name || Entry::RestParameter::DEFAULT_NAME

      [Entry::RestParameter.new(name: rest_name)]
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::OptionalParameter]) }
    def process_optional_positionals(function)
      function.optional_positionals.map do |param|
        name = param.name || :anon # TODO: consider how to handle

        Entry::OptionalParameter.new(name: name)
      end
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::OptionalParameter]) }
    def process_trailing_positionals(function)
      function.trailing_positionals.map do |param|
        Entry::OptionalParameter.new(name: param.name)
      end
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::KeywordParameter]) }
    def process_required_keywords(function)
      function.required_keywords.map do |param|
        name = param.first
        Entry::KeywordParameter.new(name: name)
      end
    end

    sig { params(function: RBS::Types::Function).returns(T::Array[Entry::OptionalKeywordParameter]) }
    def process_optional_keywords(function)
      function.optional_keywords.map do |param|
        # hack?
        name = param.first.to_s.to_sym
        Entry::OptionalKeywordParameter.new(name: name)
      end
    end

    sig { params(block: RBS::Types::Block).returns(T::Array[Entry::BlockParameter]) }
    def process_block(block)
      function = block.type
      # TODO: other kinds of arguments
      function.required_positionals.map do |required_positional|
        name = required_positional.name
        name = :blk unless name

        Entry::BlockParameter.new(name: name)
      end
    end

    sig { params(owner: Entry::Namespace).returns(T.nilable(Entry::Class)) }
    def existing_or_new_singleton_klass(owner)
      *_parts, name = owner.name.split("::")

      # Return the existing singleton class if available
      singleton_entries = T.cast(
        @index["#{owner.name}::<Class:#{name}>"],
        T.nilable(T::Array[Entry::SingletonClass]),
      )
      return singleton_entries.first if singleton_entries

      # If not available, create the singleton class lazily
      nesting = owner.nesting + ["<Class:#{name}>"]
      entry = Entry::SingletonClass.new(nesting, owner.file_path, owner.location, owner.name_location, [], nil)
      @index.add(entry, skip_prefix_tree: true)
      entry
    end
  end
end
