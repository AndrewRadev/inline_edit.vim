require 'spec_helper'

describe "Vimscript" do
  let(:filename) { 'test.vim' }

  specify "embedded python" do
    set_file_contents <<~HTML
      python << EOF
        print("OK")
      EOF
    HTML

    vim.search 'EOF'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'python'
    expect(buffer_contents).to eq <<~HTML
      print("OK")
    HTML
  end

  specify "embedded ruby" do
    set_file_contents <<~HTML
      ruby << EOF
        puts "OK"
      EOF
    HTML

    vim.search 'EOF'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'ruby'
    expect(buffer_contents).to eq <<~HTML
      puts "OK"
    HTML
  end
end
