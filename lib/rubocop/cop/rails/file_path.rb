# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      # Identifies usages of file path joining process
      # to use `Rails.root.join` clause. It is used to add uniformity when
      # joining paths.
      #
      # @example EnforcedStyle: arguments
      #   # bad
      #   Rails.root.join('app/models/goober')
      #   File.join(Rails.root, 'app/models/goober')
      #   "#{Rails.root}/app/models/goober"
      #
      #   # good
      #   Rails.root.join('app', 'models', 'goober')
      #
      # @example EnforcedStyle: slashes (default)
      #   # bad
      #   Rails.root.join('app', 'models', 'goober')
      #   File.join(Rails.root, 'app/models/goober')
      #   "#{Rails.root}/app/models/goober"
      #
      #   # good
      #   Rails.root.join('app/models/goober')
      #
      class FilePath < Base
        include ConfigurableEnforcedStyle
        include RangeHelp

        MSG_SLASHES = 'Prefer `Rails.root.join(\'path/to\')`.'
        MSG_ARGUMENTS = 'Prefer `Rails.root.join(\'path\', \'to\')`.'
        RESTRICT_ON_SEND = %i[join].freeze

        def_node_matcher :file_join_nodes?, <<~PATTERN
          (send (const nil? :File) :join ...)
        PATTERN

        def_node_search :rails_root_nodes?, <<~PATTERN
          (send (const nil? :Rails) :root)
        PATTERN

        def_node_matcher :rails_root_join_nodes?, <<~PATTERN
          (send (send (const nil? :Rails) :root) :join ...)
        PATTERN

        def on_dstr(node)
          return unless rails_root_nodes?(node)
          return unless node.children.last.str_type?

          last_child_source = node.children.last.source
          return unless last_child_source.start_with?('.') ||
                        last_child_source.include?(File::SEPARATOR)
          return if last_child_source.start_with?(':')

          register_offense(node)
        end

        def on_send(node)
          check_for_file_join_with_rails_root(node)
          check_for_rails_root_join_with_slash_separated_path(node)
          check_for_rails_root_join_with_string_arguments(node)
        end

        private

        def check_for_file_join_with_rails_root(node)
          return unless file_join_nodes?(node)
          return unless node.arguments.any? { |e| rails_root_nodes?(e) }

          register_offense(node)
        end

        def check_for_rails_root_join_with_string_arguments(node)
          return unless style == :slashes
          return unless rails_root_nodes?(node)
          return unless rails_root_join_nodes?(node)
          return unless node.arguments.size > 1
          return unless node.arguments.all?(&:str_type?)

          register_offense(node)
        end

        def check_for_rails_root_join_with_slash_separated_path(node)
          return unless style == :arguments
          return unless rails_root_nodes?(node)
          return unless rails_root_join_nodes?(node)
          return unless node.arguments.any? { |arg| string_with_slash?(arg) }

          register_offense(node)
        end

        def string_with_slash?(node)
          node.str_type? && node.source.include?('/')
        end

        def register_offense(node)
          line_range = node.loc.column...node.loc.last_column
          source_range = source_range(processed_source.buffer, node.first_line,
                                      line_range)
          add_offense(source_range)
        end

        def message(_range)
          format(style == :arguments ? MSG_ARGUMENTS : MSG_SLASHES)
        end
      end
    end
  end
end
