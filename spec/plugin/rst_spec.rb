require 'spec_helper'

describe "reStructuredText" do
  let(:filename) { 'test.rst' }

  specify "ruby code block" do
    set_file_contents <<~HTML
      Some text.

      .. code-block:: ruby

          def foo
            puts "OK"
          end

      Some other text.
    HTML

    vim.search 'ruby'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(buffer_contents).to eq <<~HTML
      def foo
        puts "OK"
      end
    HTML
    expect(vim.echo('&filetype')).to eq 'ruby'
  end

  specify "ruby code block with directives to ignore" do
    set_file_contents <<~HTML
      Some text.

      .. sourcecode:: ruby
          :lineno-start: 10

          def foo
            puts "OK"
          end

      Some other text.
    HTML

    vim.search 'ruby'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(buffer_contents).to eq <<~HTML
      def foo
        puts "OK"
      end
    HTML
    expect(vim.echo('&filetype')).to eq 'ruby'
  end

  specify "unknown code block with explicit filetype" do
    set_file_contents <<~HTML
      Some text.

      .. sourcecode::

        fn foo() {
          println!("OK");
        }

      Some other text.
    HTML

    vim.search 'fn foo'
    vim.command 'InlineEdit rust'

    buffer_contents = get_buffer_contents

    expect(buffer_contents).to eq <<~HTML
      fn foo() {
        println!("OK");
      }
    HTML
    expect(vim.echo('&filetype')).to eq 'rust'
  end
end
