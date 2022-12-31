require 'spec_helper'

describe "Markdown" do
  let(:filename) { 'test.markdown' }

  specify "ruby code block" do
    set_file_contents <<~HTML
      Some text.

      ``` ruby
      def foo
        puts "OK"
      end
      ```

      Some other text.
    HTML

    vim.search 'ruby'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'ruby'
    expect(buffer_contents).to eq <<~HTML
      def foo
        puts "OK"
      end
    HTML
  end

  specify "rust code block" do
    set_file_contents <<~HTML
      Some text.

      ```rust
      fn foo() {
        println!("OK");
      }
      ```

      Some other text.
    HTML

    vim.search 'rust'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'rust'
    expect(buffer_contents).to eq <<~HTML
      fn foo() {
        println!("OK");
      }
    HTML
  end
end
