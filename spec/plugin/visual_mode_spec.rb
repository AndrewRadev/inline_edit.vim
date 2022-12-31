require 'spec_helper'

describe "Visual mode" do
  let(:filename) { 'test.txt' }

  specify "Visual selection" do
    set_file_contents <<~HTML
      Some text here

      ## Markdown area
      Some *markdown* text _in particular_.

      Some more
    HTML

    vim.search 'Markdown area'
    vim.normal 'Vj:InlineEdit markdown<cr>'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'markdown'
    expect(buffer_contents).to eq <<~HTML
      ## Markdown area
      Some *markdown* text _in particular_.
    HTML
  end
end
