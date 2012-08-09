# encoding: utf-8

require 'jruby/profiler'


module JRuby
  module Profiler
    class DotProfilePrinter < AbstractProfilePrinter
      def initialize(invocation)
        super()
        @top = invocation
      end

      NODE_DIRECTIVE_FORMAT = %|\tnode_%-5d [label=<%s>];|
      EDGE_DIRECTIVE_FORMAT = %|\tnode_%-5d -> node_%-5d [label="%s"];|
      GLOBAL_NODE_DIRECTIVE = %|\tnode [fontname="Menlo", fontsize="14", shape="plaintext"];|
      GLOBAL_EDGE_DIRECTIVE = %|\tedge [fontname="Menlo", fontsize="12"];|
      GRAPH_START_DIRECTIVE = 'digraph profile {'
      GRAPH_END_DIRECTIVE   = '}'

      NODE_TITLE_ONE_LINE_FORMAT = '<FONT POINT-SIZE="18">%s</FONT><BR/>'
      NODE_TITLE_TWO_LINE_FORMAT = "%s<BR/>#{NODE_TITLE_ONE_LINE_FORMAT}"
      NODE_LABEL_TEMPLATE = (<<-end).gsub(/^\s*|\n/, '')
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
      end

      def print_profile(io)
        methods = method_data(@top)

        io.puts(GRAPH_START_DIRECTIVE)
        io.puts(GLOBAL_NODE_DIRECTIVE)
        io.puts(GLOBAL_EDGE_DIRECTIVE)
        io.puts

        methods.each do |self_serial, data|
          total_time = (data.total_time/1000000.0)
          self_time = (data.self_time/1000000.0)
          total_calls = data.total_calls
          method_name = method_name(self_serial).to_s
          package, _, class_and_method = method_name.rpartition('::')
          if package.empty?
            title = NODE_TITLE_ONE_LINE_FORMAT % [class_and_method]
          else
            title = NODE_TITLE_TWO_LINE_FORMAT % [package, class_and_method]
          end
          label = NODE_LABEL_TEMPLATE % [title, total_time, self_time, total_calls]
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
    end
  end
end