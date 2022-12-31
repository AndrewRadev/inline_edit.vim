require 'spec_helper'

describe "Shell" do
  let(:filename) { 'test.sh' }

  specify "templates" do
    set_file_contents <<~HTML
      cat <<-RUBY
        #! /usr/bin/env ruby

        puts "OK"
      RUBY
    HTML

    vim.search 'RUBY'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'ruby'
    expect(buffer_contents).to eq <<~HTML
      #! /usr/bin/env ruby

      puts "OK"
    HTML
  end
end
