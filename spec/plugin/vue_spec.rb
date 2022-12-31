require 'spec_helper'

describe "HTML" do
  let(:filename) { 'test.vue' }

  specify "templates" do
    set_file_contents <<~HTML
      <template>
        <p>{{ greeting }} World!</p>
      </template>
    HTML

    vim.search 'template'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'html'
    expect(buffer_contents).to eq <<~HTML
      <p>{{ greeting }} World!</p>
    HTML
  end
end
