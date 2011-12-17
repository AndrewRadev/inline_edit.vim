function! inline_edit#proxy#New(start_line, end_line, filetype, indent)
  let proxy = {
        \ 'original_buffer': -1,
        \ 'proxy_buffer':    -1,
        \ 'filetype':        '',
        \ 'start':           -1,
        \ 'end':             -1,
        \ 'indent':          -1,
        \
        \ 'Init':                 function('inline_edit#proxy#Init'),
        \ 'UpdateOriginalBuffer': function('inline_edit#proxy#UpdateOriginalBuffer'),
        \ 'UpdateOtherProxies':   function('inline_edit#proxy#UpdateOtherProxies'),
        \ }

  call proxy.Init(a:start_line, a:end_line, a:filetype, a:indent)
  return proxy
endfunction

function! inline_edit#proxy#Init(start_line, end_line, filetype, indent) dict
  let self.original_buffer = bufnr('%')
  let self.start           = a:start_line
  let self.end             = a:end_line
  let self.filetype        = a:filetype
  let self.indent          = &et ? a:indent : a:indent / &ts

  " Store all proxy buffers in the original one
  if !exists('b:proxy_buffers')
    let b:proxy_buffers = []
  endif
  call add(b:proxy_buffers, self)

  let lines = []
  for line in getbufline('%', self.start, self.end)
    call add(lines, substitute(line, '^\s\{'.self.indent.'}', '', ''))
  endfor

  let position = getpos('.')
  exe 'split ' . tempname()
  call append(0, lines)
  normal! Gdd
  write
  set foldlevel=99
  let self.proxy_buffer = bufnr('%')

  call s:SetupBuffer(self)

  let position[0] = bufnr(self.proxy_buffer)
  let position[1] = position[1] - self.start + 1
  call setpos('.', position)

  autocmd BufWritePost <buffer> silent call b:proxy.UpdateOriginalBuffer()
endfunction

function! inline_edit#proxy#UpdateOriginalBuffer() dict
  if getbufvar(self.original_buffer, '&expandtab')
    let leading_whitespace = repeat(' ', self.indent)
  else
    let leading_whitespace = repeat("\t", self.indent)
  endif

  let new_lines = []
  for line in getbufline('%', 0, '$')
    call add(new_lines, leading_whitespace.line)
  endfor

  call inline_edit#PushCursor()

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  exe 'buffer ' . self.original_buffer
  call inline_edit#PushCursor()
  call cursor(self.start, 1)
  exe 'normal! ' . (self.end - self.start + 1) . 'dd'
  call append(self.start - 1, new_lines)
  if g:inline_edit_autowrite
    write
  endif
  " store other proxies for further updating
  let other_proxies = b:proxy_buffers
  call inline_edit#PopCursor()
  exe 'buffer ' . self.proxy_buffer

  " Keep the difference in lines to know how to update the other differ if
  " necessary.
  let line_count     = self.end - self.start + 1
  let new_line_count = len(new_lines)

  let self.end = self.start + new_line_count - 1
  call s:SetupBuffer(self)
  call inline_edit#PopCursor()

  call self.UpdateOtherProxies(other_proxies, new_line_count - line_count)
endfunction

" If any of the other proxies are located below this one, we need to update
" their starting and ending lines, since any change would result in a line
" shift.
"
" a:proxies is the list of related proxies, possibly including this one
" a:delta is the change in the number of lines.
function! inline_edit#proxy#UpdateOtherProxies(proxies, delta) dict
  if a:delta == 0
    return
  endif

  for other in a:proxies
    if other == self
      continue
    endif

    if self.original_buffer == other.original_buffer
          \ && self.end <= other.start
      let other.start = other.start + a:delta
      let other.end   = other.end   + a:delta
    endif
  endfor
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
