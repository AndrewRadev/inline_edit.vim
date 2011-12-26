function! Example()
  python << PYTHON
  print("OK")
PYTHON

  perl << PERL
  VIM::Msg("pearls are nice for necklaces");
PERL

  lua << LUA
  print("OK")
LUA
endfunction

function! Example()
  ruby << RUBY
  RUBY = 3
  puts RUBY
RUBY

  ruby <<
  puts "ruby <<"
.
endfunction
