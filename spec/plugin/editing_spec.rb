require 'spec_helper'

describe "Editing" do
  let(:filename) { 'test.html' }

  specify "javascript in HTML" do
    set_file_contents <<~HTML
      <script>
        alert("Foo");
      </script>
    HTML

    vim.search 'script'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents
    expect(buffer_contents.strip).to eq 'alert("Foo");'

    filetype = vim.echo('&filetype')
    expect(filetype).to eq 'javascript'

    vim.search 'Foo'
    vim.normal 'cwBar'
    vim.write
    vim.command 'quit'

    buffer_contents = get_buffer_contents
    expect(buffer_contents).to eq <<~EOF
      <script>
        alert("Bar");
      </script>
    EOF
  end

  specify "explicit filetype override" do
    set_file_contents <<~HTML
      <script>
        alert("Foo");
      </script>
    HTML

    vim.search 'script'
    vim.command 'InlineEdit typescript'

    filetype = vim.echo('&filetype')
    expect(filetype).to eq 'typescript'
  end
end
