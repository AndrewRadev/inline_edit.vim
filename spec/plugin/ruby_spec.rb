require 'spec_helper'

describe "Ruby" do
  let(:filename) { 'test.rb' }

  specify "SQL" do
    set_file_contents <<~HTML
      def some_heavy_query
        execute <<~SQL
          SELECT * FROM users WHERE something = 'other';
        SQL
      end
    HTML

    vim.search 'SQL'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'sql'
    expect(buffer_contents).to eq <<~HTML
      SELECT * FROM users WHERE something = 'other';
    HTML
  end
end
