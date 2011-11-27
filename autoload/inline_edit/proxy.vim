function! inline_edit#proxy#New()
  return {
        \ 'original_buffer': -1,
        \ 'proxy_buffer':    -1,
        \ 'filetype':        '',
        \ 'start':           -1,
        \ 'end':             -1,
        \ 'indent':          -1,
        \
        \ 'Init':                 function('inline_edit#proxy#Init'),
        \ 'UpdateOriginalBuffer': function('inline_edit#proxy#UpdateOriginalBuffer'),
        \ }
endfunction

function! inline_edit#proxy#Init(start_line, end_line, filetype, indent) dict
  let self.original_buffer = bufnr('%')
  let self.start           = a:start_line
  let self.end             = a:end_line
  let self.filetype        = a:filetype
  let self.indent          = a:indent

  let lines = []
  for line in getbufline('%', self.start, self.end)
    call add(lines, substitute(line, '^\s\{'.self.indent.'}', '', ''))
  endfor

  exe 'split ' . tempname()
  call append(0, lines)
  normal! Gdd
  write
  set foldlevel=99
  let self.proxy_buffer = bufnr('%')

  call s:SetupBuffer(self)

  autocmd BufWritePost <buffer> silent call b:proxy.UpdateOriginalBuffer()
endfunction

" TODO (2011-11-26) Handle noexpandtab
function! inline_edit#proxy#UpdateOriginalBuffer() dict
  let leading_whitespace = repeat(' ', self.indent)

  let new_lines = []
  for line in getbufline('%', 0, '$')
    call add(new_lines, leading_whitespace.line)
  endfor

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  exe 'buffer ' . self.original_buffer
  call inline_edit#PushCursor()
  call cursor(self.start, 1)
  exe 'normal! ' . (self.end - self.start + 1) . 'dd'
  call append(self.start - 1, new_lines)
  call inline_edit#PopCursor()
  exe 'buffer ' . self.proxy_buffer

  let self.end = self.start + len(new_lines) - 1
  call s:SetupBuffer(self)
endfunction

function! s:SetupBuffer(proxy)
  let b:proxy   = a:proxy
  let &filetype = b:proxy.filetype

  let statusline = printf('[%s:%%{b:proxy.start}-%%{b:proxy.end}]', bufname(b:proxy.original_buffer))
  if &statusline =~ '%[fF]'
    let statusline = substitute(&statusline, '%[fF]', statusline, '')
  endif
  exe "setlocal statusline=" . escape(statusline, ' |')
endfunction
