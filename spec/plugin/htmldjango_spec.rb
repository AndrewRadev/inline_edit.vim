require 'spec_helper'

describe "HTML Django templates" do
  let(:filename) { 'test.html' }

  specify "blocks" do
    set_file_contents <<~HTML
      <body>
        {% block content %}
        <h1>{{ section.title }}</h1>
        {% endblock %}
      </body>
    HTML

    vim.search 'block content'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'htmldjango'
    expect(buffer_contents).to eq <<~HTML
      <h1>{{ section.title }}</h1>
    HTML
  end
end
