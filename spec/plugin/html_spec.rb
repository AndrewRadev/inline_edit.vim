require 'spec_helper'

describe "HTML" do
  let(:filename) { 'test.html' }

  specify "javascript" do
    set_file_contents <<~HTML
      <head>
        <title>Foo</title>
        <script>
          function Foo() {
            console.log("bar");
          }
        </script>
      </head>
    HTML

    vim.search 'script'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'javascript'
    expect(buffer_contents).to eq <<~HTML
      function Foo() {
        console.log("bar");
      }
    HTML
  end

  specify "CSS" do
    set_file_contents <<~HTML
      <head>
        <title>Foo</title>
        <style>
          div {
            background-color: red;
          }
        </style>
      </head>
    HTML

    vim.search 'style'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'css'
    expect(buffer_contents).to eq <<~HTML
      div {
        background-color: red;
      }
    HTML
  end
end
