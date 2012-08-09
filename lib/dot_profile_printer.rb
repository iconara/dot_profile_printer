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
        @node_label_renderer = HtmlNodeLabelRenderer.new
      end

      NODE_DIRECTIVE_FORMAT = %|\tnode_%-5d [label=%s];|
      EDGE_DIRECTIVE_FORMAT = %|\tnode_%-5d -> node_%-5d [label="%s"];|
      GLOBAL_NODE_DIRECTIVE = %|\tnode [fontname="%s", fontsize="14", shape="%s"];|
      GLOBAL_EDGE_DIRECTIVE = %|\tedge [fontname="%s", fontsize="12"];|
      GRAPH_START_DIRECTIVE = 'digraph profile {'
      GRAPH_END_DIRECTIVE   = '}'

      def node_label_html(package, class_and_method, total_time, self_time, total_calls)
        if package.empty?
          title = NODE_TITLE_HTML_ONE_LINE_FORMAT % [basic_html_escape(class_and_method)]
        else
          title = NODE_TITLE_HTML_TWO_LINE_FORMAT % [package, basic_html_escape(class_and_method)]
        end
        NODE_LABEL_HTML_TEMPLATE % [title, total_time, self_time, total_calls]
      end

      def print_profile(io)
        methods = method_data(@top)

        io.puts(GRAPH_START_DIRECTIVE)
        io.puts(GLOBAL_NODE_DIRECTIVE % [@font_name, @node_label_renderer.node_shape])
        io.puts(GLOBAL_EDGE_DIRECTIVE % [@font_name])
        io.puts

        methods.each do |self_serial, data|
          total_time = (data.total_time/1000000.0)
          self_time = (data.self_time/1000000.0)
          total_calls = data.total_calls
          method_name = method_name(self_serial).to_s
          label = @node_label_renderer.render(method_name, total_time, self_time, total_calls)
          io.puts(NODE_DIRECTIVE_FORMAT % [self_serial, label])
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

    private

      class HtmlNodeLabelRenderer
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
                      <TD ALIGN="RIGHT">%.3fs</TD>
                    </TR>
                    <TR>
                      <TD ALIGN="LEFT">self </TD>
                      <TD ALIGN="RIGHT">%.3fs</TD>
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
        }

        ONE_LINE_TITLE = '<FONT POINT-SIZE="18">%s</FONT><BR/>'
        TWO_LINE_TITLE = "%s<BR/>#{ONE_LINE_TITLE}"

        def node_shape
          'plaintext'
        end

        def render(method_name, total_time, self_time, total_calls)
          package, _, class_and_method = method_name.rpartition('::')
          if package.empty?
            title = ONE_LINE_TITLE % [basic_html_escape(class_and_method)]
          else
            title = TWO_LINE_TITLE % [package, basic_html_escape(class_and_method)]
          end
          label = TEMPLATE % [title, total_time, self_time, total_calls]
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
    end
  end
end