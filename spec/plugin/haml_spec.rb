require 'spec_helper'

describe "HTML" do
  let(:filename) { 'test.haml' }

  specify "javascript" do
    set_file_contents <<~HTML
      %body
        :javascript
          alert("OK");

        :css
          .content { border: 1px solid black; }
    HTML

    vim.search ':javascript'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'javascript'
    expect(buffer_contents).to eq <<~HTML
      alert("OK");
    HTML
  end

  specify "CSS" do
    set_file_contents <<~HTML
      %body
        :javascript
          alert("OK");

        :css
          .content { border: 1px solid black; }
    HTML

    vim.search ':css'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'css'
    expect(buffer_contents).to eq <<~HTML
      .content { border: 1px solid black; }
    HTML
  end

  specify "explicit filetype" do
    set_file_contents <<~HTML
      %body
        :javascript
          alert("OK");
    HTML

    vim.search 'alert'
    vim.command 'InlineEdit typescript'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'typescript'
  end
end
