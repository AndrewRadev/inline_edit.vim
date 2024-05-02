require 'spec_helper'

describe "Scala (include-margin patterns)" do
  let(:filename) { 'test.scala' }

  specify "fully inline pattern" do
    set_file_contents <<~HTML
      something = sql"""SELECT id, foo, bar baz
                        FROM schema.table
                        WHERE id = $id"""
                    .queryBy(row => ???)
    HTML

    vim.search 'FROM'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'sql'
    expect(buffer_contents).to eq <<~HTML
      SELECT id, foo, bar baz
      FROM schema.table
      WHERE id = $id
    HTML

    vim.search 'FROM'
    vim.normal 'oINNER JOIN other_table ON...'
    vim.write
    vim.command :quit
    vim.write

    assert_file_contents <<~HTML
      something = sql"""SELECT id, foo, bar baz
                        FROM schema.table
                        INNER JOIN other_table ON...
                        WHERE id = $id"""
                    .queryBy(row => ???)
    HTML
  end

  specify "one-line pattern" do
    set_file_contents <<~HTML
      sql = SQL"""SELECT id, name FROM foo""".as(parser.*)
    HTML

    vim.search 'SELECT'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'sql'
    expect(buffer_contents).to eq <<~HTML
      SELECT id, name FROM foo
    HTML

    vim.normal 'A, bar'
    vim.write
    vim.command :quit
    vim.write

    assert_file_contents <<~HTML
      sql = SQL"""SELECT id, name FROM foo, bar""".as(parser.*)
    HTML
  end

  specify "indentation maintenance" do
    set_file_contents <<~HTML
      foo =
        SQL"""
          SELECT id, name
          FROM studier.teaching_location
          WHERE id = any(${ids.map(x => x: java.lang.Long)})
        """
    HTML

    vim.search 'SELECT'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'sql'
    expect(buffer_contents).to eq <<~HTML
      SELECT id, name
      FROM studier.teaching_location
      WHERE id = any(${ids.map(x => x: java.lang.Long)})
    HTML

    vim.search 'FROM'
    vim.normal 'oINNER JOIN other_table ON ...'
    vim.write
    vim.command :quit
    vim.write

    assert_file_contents <<~HTML
      foo =
        SQL"""
          SELECT id, name
          FROM studier.teaching_location
          INNER JOIN other_table ON ...
          WHERE id = any(${ids.map(x => x: java.lang.Long)})
        """
    HTML
  end
end
