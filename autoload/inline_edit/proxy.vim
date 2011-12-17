function! inline_edit#proxy#New(start_line, end_line, filetype, indent)
  let proxy = {
        \ 'original_buffer': bufnr('%'),
        \ 'proxy_buffer':    -1,
        \ 'filetype':        a:filetype,
        \ 'start':           a:start_line,
        \ 'end':             a:end_line,
        \ 'indent':          (&et ? a:indent : a:indent / &ts),
        \
        \ 'Init':                 function('inline_edit#proxy#Init'),
        \ 'UpdateOriginalBuffer': function('inline_edit#proxy#UpdateOriginalBuffer'),
        \ 'UpdateOtherProxies':   function('inline_edit#proxy#UpdateOtherProxies'),
        \ }

  " Store all proxy buffers in the original one
  if !exists('b:proxy_buffers')
    let b:proxy_buffers = []
  endif
  call add(b:proxy_buffers, proxy)

  " Collect data from original buffer
  let lines = []
  for line in getbufline(proxy.original_buffer, proxy.start, proxy.end)
    call add(lines, substitute(line, '^\s\{'.proxy.indent.'}', '', ''))
  endfor
  let position = getpos('.')

  " Create proxy buffer
  exe 'silent split ' . tempname()
  call append(0, lines)
  $delete _
  write
  set foldlevel=99
  let proxy.proxy_buffer = bufnr('%')
  call s:SetupBuffer(proxy)

  " Position cursor correctly
  let position[0] = bufnr(proxy.proxy_buffer)
  let position[1] = position[1] - proxy.start + 1
  call setpos('.', position)

  " On writing proxy buffer, update original one
  autocmd BufWritePost <buffer> silent call b:proxy.UpdateOriginalBuffer()

  return proxy
endfunction

function! inline_edit#proxy#Init(start_line, end_line, filetype, indent) dict
endfunction

" This function updates the original buffer with the contents of the proxy
" one. Care is taken to synchronize all of the other proxy buffers that may be
" open.
function! inline_edit#proxy#UpdateOriginalBuffer() dict
  " Prepare lines for moving around
  if getbufvar(self.original_buffer, '&expandtab')
    let leading_whitespace = repeat(' ', self.indent)
  else
    let leading_whitespace = repeat("\t", self.indent)
  endif

  let new_lines = []
  for line in getbufline('%', 0, '$')
    call add(new_lines, leading_whitespace.line)
  endfor

  call inline_edit#PushCursor() " in proxy buffer

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  exe 'buffer ' . self.original_buffer

  call inline_edit#PushCursor()
  call cursor(self.start, 1)
  exe self.start . ',' . self.end . 'delete _'
  call append(self.start - 1, new_lines)
  if g:inline_edit_autowrite
    write
  endif
  call inline_edit#PopCursor()
  exe 'buffer ' . self.proxy_buffer

  " Keep the difference in lines to know how to update the other proxies if
  " necessary.
  let line_count     = self.end - self.start + 1
  let new_line_count = len(new_lines)

  let self.end = self.start + new_line_count - 1
  call s:SetupBuffer(self)

  call inline_edit#PopCursor() " in proxy buffer

  call self.UpdateOtherProxies(new_line_count - line_count)
endfunction

" If any of the other proxies are located below this one, we need to update
" their starting and ending lines, since any change would result in a line
" shift.
"
" a:delta is the change in the number of lines.
function! inline_edit#proxy#UpdateOtherProxies(delta) dict
  if a:delta == 0
    return
  endif

  " Iterate through all proxies by asking the original buffer for the list
  for other in getbufvar(self.original_buffer, 'proxy_buffers')
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
