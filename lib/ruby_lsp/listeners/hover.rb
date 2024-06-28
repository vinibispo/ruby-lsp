# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Listeners
    class Hover
      extend T::Sig
      include Requests::Support::Common

      ALLOWED_TARGETS = T.let(
        [
          Prism::AliasGlobalVariableNode,
          Prism::AliasMethodNode,
          Prism::AndNode,
          Prism::BeginNode,
          Prism::BreakNode,
          Prism::CallNode,
          Prism::CaseNode,
          Prism::ClassNode,
          Prism::ConstantPathNode,
          Prism::ConstantReadNode,
          Prism::ConstantWriteNode,
          Prism::DefNode,
          Prism::DefinedNode,
          Prism::ElseNode,
          Prism::EnsureNode,
          Prism::FalseNode,
          Prism::ForNode,
          Prism::IfNode,
          Prism::InNode,
          Prism::InstanceVariableAndWriteNode,
          Prism::InstanceVariableOperatorWriteNode,
          Prism::InstanceVariableOrWriteNode,
          Prism::InstanceVariableReadNode,
          Prism::InstanceVariableTargetNode,
          Prism::InstanceVariableWriteNode,
          Prism::ModuleNode,
          Prism::NextNode,
          Prism::NilNode,
          Prism::OrNode,
          Prism::RedoNode,
          Prism::RescueNode,
          Prism::RetryNode,
          Prism::ReturnNode,
          Prism::SelfNode,
          Prism::StringNode,
          Prism::SuperNode,
          Prism::SymbolNode,
          Prism::TrueNode,
          Prism::UndefNode,
          Prism::UnlessNode,
          Prism::UntilNode,
          Prism::WhenNode,
          Prism::WhileNode,
          Prism::YieldNode,
        ],
        T::Array[T.class_of(Prism::Node)],
      )

      ALLOWED_REMOTE_PROVIDERS = T.let(
        [
          "https://github.com",
          "https://gitlab.com",
        ].freeze,
        T::Array[String],
      )

      sig do
        params(
          response_builder: ResponseBuilders::Hover,
          global_state: GlobalState,
          uri: URI::Generic,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
          typechecker_enabled: T::Boolean,
        ).void
      end
      def initialize(response_builder, global_state, uri, node_context, dispatcher, typechecker_enabled) # rubocop:disable Metrics/ParameterLists
        @response_builder = response_builder
        @global_state = global_state
        @index = T.let(global_state.index, RubyIndexer::Index)
        @type_inferrer = T.let(global_state.type_inferrer, TypeInferrer)
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        @node_context = node_context
        @typechecker_enabled = typechecker_enabled

        dispatcher.register(
          self,
          :on_alias_global_variable_node_enter,
          :on_alias_method_node_enter,
          :on_and_node_enter,
          :on_begin_node_enter,
          :on_break_node_enter,
          :on_call_node_enter,
          :on_case_node_enter,
          :on_class_node_enter,
          :on_constant_path_node_enter,
          :on_constant_read_node_enter,
          :on_constant_write_node_enter,
          :on_def_node_enter,
          :on_defined_node_enter,
          :on_else_node_enter,
          :on_ensure_node_enter,
          :on_false_node_enter,
          :on_for_node_enter,
          :on_if_node_enter,
          :on_in_node_enter,
          :on_instance_variable_and_write_node_enter,
          :on_instance_variable_operator_write_node_enter,
          :on_instance_variable_or_write_node_enter,
          :on_instance_variable_read_node_enter,
          :on_instance_variable_target_node_enter,
          :on_instance_variable_write_node_enter,
          :on_module_node_enter,
          :on_next_node_enter,
          :on_nil_node_enter,
          :on_or_node_enter,
          :on_redo_node_enter,
          :on_rescue_node_enter,
          :on_retry_node_enter,
          :on_return_node_enter,
          :on_self_node_enter,
          :on_super_node_enter,
          :on_symbol_node_enter,
          :on_true_node_enter,
          :on_undef_node_enter,
          :on_unless_node_enter,
          :on_until_node_enter,
          :on_when_node_enter,
          :on_while_node_enter,
          :on_yield_node_enter,
        )
      end

      sig { params(node: Prism::AndNode).void }
      def on_and_node_enter(node)
        @response_builder.push(static_documentation("and.md"), category: :documentation)
      end

      sig { params(node: Prism::AliasGlobalVariableNode).void }
      def on_alias_global_variable_node_enter(node)
        @response_builder.push(static_documentation("alias.md"), category: :documentation)
      end

      sig { params(node: Prism::AliasMethodNode).void }
      def on_alias_method_node_enter(node)
        @response_builder.push(static_documentation("alias.md"), category: :documentation)
      end

      sig { params(node: Prism::BeginNode).void }
      def on_begin_node_enter(node)
        @response_builder.push(static_documentation("begin.md"), category: :documentation)
      end

      sig { params(node: Prism::BreakNode).void }
      def on_break_node_enter(node)
        @response_builder.push(static_documentation("break.md"), category: :documentation)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        if @path && File.basename(@path) == GEMFILE_NAME && node.name == :gem
          generate_gem_hover(node)
          return
        end

        return if @typechecker_enabled

        message = node.message
        return unless message

        type = @type_inferrer.infer_receiver_type(@node_context)
        return unless type

        methods = @index.resolve_method(message, type)
        return unless methods

        title = "#{message}#{T.must(methods.first).decorated_parameters}"

        categorized_markdown_from_index_entries(title, methods).each do |category, content|
          @response_builder.push(content, category: category)
        end
      end

      sig { params(node: Prism::CaseNode).void }
      def on_case_node_enter(node)
        @response_builder.push(static_documentation("case.md"), category: :documentation)
      end

      sig { params(node: Prism::ClassNode).void }
      def on_class_node_enter(node)
        @response_builder.push(static_documentation("class.md"), category: :documentation)
      end

      sig { params(node: Prism::ConstantReadNode).void }
      def on_constant_read_node_enter(node)
        return if @typechecker_enabled

        name = constant_name(node)
        return if name.nil?

        generate_hover(name, node.location)
      end

      sig { params(node: Prism::ConstantWriteNode).void }
      def on_constant_write_node_enter(node)
        return if @global_state.has_type_checker

        generate_hover(node.name.to_s, node.name_loc)
      end

      sig { params(node: Prism::ConstantPathNode).void }
      def on_constant_path_node_enter(node)
        return if @global_state.has_type_checker

        name = constant_name(node)
        return if name.nil?

        generate_hover(name, node.location)
      end

      sig { params(node: Prism::DefNode).void }
      def on_def_node_enter(node)
        @response_builder.push(static_documentation("def.md"), category: :documentation)
      end

      sig { params(node: Prism::DefinedNode).void }
      def on_defined_node_enter(node)
        @response_builder.push(static_documentation("defined?.md"), category: :documentation)
      end

      sig { params(node: Prism::ElseNode).void }
      def on_else_node_enter(node)
        @response_builder.push(static_documentation("else.md"), category: :documentation)
      end

      sig { params(node: Prism::EnsureNode).void }
      def on_ensure_node_enter(node)
        @response_builder.push(static_documentation("ensure.md"), category: :documentation)
      end

      sig { params(node: Prism::FalseNode).void }
      def on_false_node_enter(node)
        @response_builder.push(static_documentation("false.md"), category: :documentation)
      end

      sig { params(node: Prism::ForNode).void }
      def on_for_node_enter(node)
        @response_builder.push(static_documentation("for.md"), category: :documentation)
      end

      sig { params(node: Prism::IfNode).void }
      def on_if_node_enter(node)
        @response_builder.push(static_documentation("if.md"), category: :documentation)
      end

      sig { params(node: Prism::InNode).void }
      def on_in_node_enter(node)
        @response_builder.push(static_documentation("in.md"), category: :documentation)
      end

      sig { params(node: Prism::InstanceVariableAndWriteNode).void }
      def on_instance_variable_and_write_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::InstanceVariableOperatorWriteNode).void }
      def on_instance_variable_operator_write_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::InstanceVariableOrWriteNode).void }
      def on_instance_variable_or_write_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::InstanceVariableReadNode).void }
      def on_instance_variable_read_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::InstanceVariableTargetNode).void }
      def on_instance_variable_target_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::InstanceVariableWriteNode).void }
      def on_instance_variable_write_node_enter(node)
        handle_instance_variable_hover(node.name.to_s)
      end

      sig { params(node: Prism::ModuleNode).void }
      def on_module_node_enter(node)
        @response_builder.push(static_documentation("module.md"), category: :documentation)
      end

      sig { params(node: Prism::NextNode).void }
      def on_next_node_enter(node)
        @response_builder.push(static_documentation("next.md"), category: :documentation)
      end

      sig { params(node: Prism::NilNode).void }
      def on_nil_node_enter(node)
        @response_builder.push(static_documentation("nil.md"), category: :documentation)
      end

      sig { params(node: Prism::OrNode).void }
      def on_or_node_enter(node)
        @response_builder.push(static_documentation("or.md"), category: :documentation)
      end

      sig { params(node: Prism::RedoNode).void }
      def on_redo_node_enter(node)
        @response_builder.push(static_documentation("redo.md"), category: :documentation)
      end

      sig { params(node: Prism::RescueNode).void }
      def on_rescue_node_enter(node)
        @response_builder.push(static_documentation("rescue.md"), category: :documentation)
      end

      sig { params(node: Prism::RetryNode).void }
      def on_retry_node_enter(node)
        @response_builder.push(static_documentation("retry.md"), category: :documentation)
      end

      sig { params(node: Prism::ReturnNode).void }
      def on_return_node_enter(node)
        @response_builder.push(static_documentation("return.md"), category: :documentation)
      end

      sig { params(node: Prism::SelfNode).void }
      def on_self_node_enter(node)
        @response_builder.push(static_documentation("self.md"), category: :documentation)
      end

      sig { params(node: Prism::SuperNode).void }
      def on_super_node_enter(node)
        @response_builder.push(static_documentation("super.md"), category: :documentation)
      end

      sig { params(node: Prism::SymbolNode).void }
      def on_symbol_node_enter(node)
        @response_builder.push(static_documentation("symbol.md"), category: :documentation)
      end

      sig { params(node: Prism::TrueNode).void }
      def on_true_node_enter(node)
        @response_builder.push(static_documentation("true.md"), category: :documentation)
      end

      sig { params(node: Prism::UndefNode).void }
      def on_undef_node_enter(node)
        @response_builder.push(static_documentation("undef.md"), category: :documentation)
      end

      sig { params(node: Prism::UnlessNode).void }
      def on_unless_node_enter(node)
        @response_builder.push(static_documentation("unless.md"), category: :documentation)
      end

      sig { params(node: Prism::UntilNode).void }
      def on_until_node_enter(node)
        @response_builder.push(static_documentation("until.md"), category: :documentation)
      end

      sig { params(node: Prism::WhenNode).void }
      def on_when_node_enter(node)
        @response_builder.push(static_documentation("when.md"), category: :documentation)
      end

      sig { params(node: Prism::WhileNode).void }
      def on_while_node_enter(node)
        @response_builder.push(static_documentation("while.md"), category: :documentation)
      end

      sig { params(node: Prism::YieldNode).void }
      def on_yield_node_enter(node)
        @response_builder.push(static_documentation("yield.md"), category: :documentation)
      end

      private

      sig { params(name: String).void }
      def handle_instance_variable_hover(name)
        type = @type_inferrer.infer_receiver_type(@node_context)
        return unless type

        entries = @index.resolve_instance_variable(name, type)
        return unless entries

        categorized_markdown_from_index_entries(name, entries).each do |category, content|
          @response_builder.push(content, category: category)
        end
      rescue RubyIndexer::Index::NonExistingNamespaceError
        # If by any chance we haven't indexed the owner, then there's no way to find the right declaration
      end

      sig { params(name: String, location: Prism::Location).void }
      def generate_hover(name, location)
        entries = @index.resolve(name, @node_context.nesting)
        return unless entries

        # We should only show hover for private constants if the constant is defined in the same namespace as the
        # reference
        first_entry = T.must(entries.first)
        return if first_entry.private? && first_entry.name != "#{@node_context.fully_qualified_name}::#{name}"

        categorized_markdown_from_index_entries(name, entries).each do |category, content|
          @response_builder.push(content, category: category)
        end
      end

      sig { params(node: Prism::CallNode).void }
      def generate_gem_hover(node)
        first_argument = node.arguments&.arguments&.first
        return unless first_argument.is_a?(Prism::StringNode)

        spec = Gem::Specification.find_by_name(first_argument.content)
        return unless spec

        info = T.let(
          [
            spec.description,
            spec.summary,
            "This rubygem does not have a description or summary.",
          ].find { |text| !text.nil? && !text.empty? },
          String,
        )

        # Remove leading whitespace if a heredoc was used for the summary or description
        info = info.gsub(/^ +/, "")

        remote_url = [spec.homepage, spec.metadata["source_code_uri"]].compact.find do |page|
          page.start_with?(*ALLOWED_REMOTE_PROVIDERS)
        end

        @response_builder.push(
          "**#{spec.name}** (#{spec.version}) #{remote_url && " - [open remote](#{remote_url})"}",
          category: :title,
        )
        @response_builder.push(info, category: :documentation)
      rescue Gem::MissingSpecError
        # Do nothing if the spec cannot be found
      end
    end
  end
end
