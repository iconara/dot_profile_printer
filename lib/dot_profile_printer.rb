# encoding: utf-8

require 'jruby/profiler'
require 'set'


module JRuby
  module Profiler
    class DotProfilePrinter < AbstractProfilePrinter
      def initialize(invocation, options={})
        super()
        @top = invocation
        @font_name = options[:font_name] || 'Menlo'
        @base_font_size = options[:font_size] || 14
        if (renderer_class = NODE_LABEL_RENDERERS[options[:node_label_renderer] || :table])
          @node_label_renderer = renderer_class.new(self)
        else
          raise ArgumentError, %|No node label renderer for "#{options[:node_label_renderer]}"|
        end
      end

      def print_profile(io)
        methods = method_data(@top)

        io.puts(GRAPH_START_DIRECTIVE)
        io.puts(GLOBAL_NODE_DIRECTIVE % [@font_name, @node_label_renderer.node_shape])
        io.puts(GLOBAL_EDGE_DIRECTIVE % [@font_name, edge_font_size])
        io.puts

        top_total_time = @top.duration/1000000.0

        methods.each do |self_serial, data|
          total_time = (data.total_time/1000000.0)
          self_time = (data.self_time/1000000.0)
          total_calls = data.total_calls
          method_name = method_name(self_serial).to_s
          size_modifier = 0.5 + 2 * Math.sqrt(self_time/top_total_time)
          label = @node_label_renderer.render(size_modifier, method_name, top_total_time, total_time, self_time, total_calls)
          font_size = (base_font_size * size_modifier).round
          io.puts(NODE_DIRECTIVE_FORMAT % [self_serial, label, font_size])
        end

        io.puts

        printed_edges = Hash.new { |h, k| h[k] = Set.new }

        methods.each do |self_serial, data|
          unless self_serial == 0
            data.parents.each do |parent_serial|
              unless printed_edges[parent_serial].include?(self_serial)
                calls = data.invocations_from_parent(parent_serial).total_calls
                io.puts(EDGE_DIRECTIVE_FORMAT % [parent_serial, self_serial, calls.to_s])
                printed_edges[parent_serial] << self_serial
              end
            end
          end

          data.children.each do |child_serial|
            unless printed_edges[self_serial].include?(child_serial)
              calls = data.invocations_of_child(child_serial).total_calls
              io.puts(EDGE_DIRECTIVE_FORMAT % [self_serial, child_serial, calls.to_s])
              printed_edges[self_serial] << child_serial
            end
          end
        end

        io.puts(GRAPH_END_DIRECTIVE)
      end

      def base_font_size
        @base_font_size
      end

      def method_name_font_size
        (base_font_size * 1.25).round
      end

      def edge_font_size
        (base_font_size * 0.85).round
      end

      private

      NODE_DIRECTIVE_FORMAT = %|\tmethod_%-5d [label=%s, fontsize="%d"];|
      EDGE_DIRECTIVE_FORMAT = %|\tmethod_%-5d -> method_%-5d [label="%s"];|
      GLOBAL_NODE_DIRECTIVE = %|\tnode [fontname="%s", shape="%s"];|
      GLOBAL_EDGE_DIRECTIVE = %|\tedge [fontname="%s", fontsize="%d"];|
      GRAPH_START_DIRECTIVE = 'digraph profile {'
      GRAPH_END_DIRECTIVE   = '}'

      class NodeLabelRendererBase
        def initialize(config)
          @config = config
        end

        def node_shape
          'box'
        end

        def font_size(percent_time)
          @config.base_font_size
        end
      end

      class SimpleNodeLabelRenderer < NodeLabelRendererBase
        TEMPLATE = '"%s\n%s\ntotal: %.3fs (%.1f%%)\nself: %.3fs (%.1f%%)\ncalls: %d"'

        def render(size_modifier, method_name, top_total_time, total_time, self_time, total_calls)
          package, _, class_and_method = method_name.rpartition('::')
          total_percent = total_time/top_total_time * 100
          self_percent = self_time/top_total_time * 100
          label = TEMPLATE % [package, class_and_method, total_time, total_percent, self_time, self_percent, total_calls]
          label.gsub!(/^"\\n/, '"')
          label
        end
      end

      class TableNodeLabelRenderer < NodeLabelRendererBase
        TEMPLATE = %{
          <
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8">
              <TR>
                <TD ALIGN="LEFT" BALIGN="LEFT">%s</TD>
              </TR>
              <TR>
                <TD>
                  <TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="0">
                    <TR>
                      <TD ALIGN="LEFT">total </TD>
                      <TD ALIGN="RIGHT">(%.1f%%) %.3fs</TD>
                    </TR>
                    <TR>
                      <TD ALIGN="LEFT">self </TD>
                      <TD ALIGN="RIGHT">(%.1f%%) %.3fs</TD>
                    </TR>
                    <TR>
                      <TD ALIGN="LEFT">calls </TD>
                      <TD ALIGN="RIGHT">%d</TD>
                    </TR>
                  </TABLE>
                </TD>
              </TR>
            </TABLE>
          >
        }.freeze

        ONE_LINE_TITLE = '<FONT POINT-SIZE="%d">%s</FONT><BR/>'
        TWO_LINE_TITLE = "%s<BR/>#{ONE_LINE_TITLE}"

        def node_shape
          'plaintext'
        end

        def render(size_modifier, method_name, top_total_time, total_time, self_time, total_calls)
          total_percent = total_time/top_total_time * 100
          self_percent = self_time/top_total_time * 100
          package, _, class_and_method = method_name.rpartition('::')
          method_name_font_size = (@config.method_name_font_size * size_modifier).round
          if package.empty?
            title = ONE_LINE_TITLE % [method_name_font_size, basic_html_escape(class_and_method)]
          else
            title = TWO_LINE_TITLE % [package, method_name_font_size, basic_html_escape(class_and_method)]
          end
          label = TEMPLATE % [title, total_percent, total_time, self_percent, self_time, total_calls]
          label.gsub!(/^\s*/, '')
          label.gsub!("\n", '')
          label
        end

        private

        def basic_html_escape(str)
          str = str.gsub('&', '&amp;')
          str.gsub!('<', '&lt;')
          str.gsub!('>', '&gt;')
          str
        end
      end

      NODE_LABEL_RENDERERS = {
        :simple => SimpleNodeLabelRenderer,
        :table => TableNodeLabelRenderer
      }
    end
  end
end