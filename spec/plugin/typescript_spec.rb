require 'spec_helper'

describe "Typescript (Angular.js)" do
  let(:filename) { 'test.ts' }

  specify "templates" do
    set_file_contents <<~HTML
      @Component({
        selector: 'my-component',
        template: `
          <p class="my-p">My component works!</p>
        `,
        styles: [
          `
            .my-p {
              color: orange;
            }
          `,
        ],
      })
    HTML

    vim.search '"my-p"'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'html'
    expect(buffer_contents).to eq <<~HTML
      <p class="my-p">My component works!</p>
    HTML
  end

  specify "style blocks" do
    set_file_contents <<~HTML
      @Component({
        selector: 'my-component',
        template: `
          <p class="my-p">My component works!</p>
        `,
        styles: [
          `
            .my-p {
              color: orange;
            }
          `,
        ],
      })
    HTML

    vim.search '\.my-p'
    vim.command 'InlineEdit'

    buffer_contents = get_buffer_contents

    expect(vim.echo('&filetype')).to eq 'css'
    expect(buffer_contents).to eq <<~HTML
      .my-p {
        color: orange;
      }
    HTML
  end
end
