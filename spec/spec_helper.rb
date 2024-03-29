require 'vimrunner'
require 'vimrunner/rspec'
require_relative './support/vim'

Vimrunner::RSpec.configure do |config|
  config.reuse_server = true

  plugin_path = File.expand_path('.')

  config.start_vim do
    vim = Vimrunner.start_gvim
    vim.add_plugin(plugin_path, 'plugin/inline_edit.vim')

    vim.command('set expandtab')
    vim.command('set shiftwidth=2')

    vim
  end
end

RSpec.configure do |config|
  config.include Support::Vim

  config.before :each do
    vim.command('only')
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = true
  config.default_formatter = "doc"

  config.order = :random
  Kernel.srand config.seed
end
