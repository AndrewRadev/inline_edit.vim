function! inline_edit#proxy#New(controller, start_line, end_line, start_col, end_col, filetype, indent) abort
  let proxy = {
        \ 'controller':      a:controller,
        \ 'original_buffer': expand('%:p'),
        \ 'proxy_buffer':    -1,
        \ 'filetype':        a:filetype,
        \ 'start_line':      a:start_line,
        \ 'end_line':        a:end_line,
        \ 'start_prefix':    (a:start_col > 0 ? strpart(getline(a:start_line), 0, a:start_col - 1) : ''),
        \ 'end_suffix':      (a:end_col   > 0 ? strpart(getline(a:end_line), a:end_col - 1) : ''),
        \ 'indent':          (&et ? a:indent : a:indent / &ts),
        \
        \ 'UpdateOriginalBuffer': function('inline_edit#proxy#UpdateOriginalBuffer')
        \ }

  let existing_content = join(getbufline(proxy.original_buffer, a:start_line, a:end_line), ' ')
  if existing_content =~ '\S' && proxy.start_prefix == ''
    " then there's already some code, use its indent, if it's smaller
    let common_indent = s:GetCommonIndent(a:start_line, a:end_line)
    let proxy.indent = min([proxy.indent, common_indent])
  endif

  let [lines, position] = s:LoadOriginalBufferContents(proxy)
  call s:CreateProxyBuffer(proxy, lines)
  call s:UpdateProxyBuffer(proxy)
  call s:SetStatusline(proxy)
  call s:PositionCursor(proxy, position)

  " On writing proxy buffer, update original one
  if g:inline_edit_proxy_type == 'scratch'
    autocmd BufWriteCmd <buffer> silent call b:inline_edit_proxy.UpdateOriginalBuffer()
  elseif g:inline_edit_proxy_type == 'tempfile'
    autocmd BufWritePost <buffer> silent call b:inline_edit_proxy.UpdateOriginalBuffer()
  endif

  return proxy
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
    if line =~ '^$'
      " blank line, no need for whitespace
    else
      let line = leading_whitespace.line
    endif
    call add(new_lines, line)
  endfor

  if self.start_prefix != ''
    let new_lines[0] = self.start_prefix .. strpart(new_lines[0], len(leading_whitespace))
  endif

  if self.end_suffix != ''
    let new_lines[-1] ..= self.end_suffix
  endif

  call inline_edit#PushCursor() " in proxy buffer

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  let saved_bufhidden = &bufhidden
  let &bufhidden = 'hide'

  setlocal nomodified
  let original_bufnr = bufnr(self.original_buffer)
  if original_bufnr < 0 " no buffer found
    call inline_edit#PopCursor()
    return
  endif
  exe 'buffer ' . original_bufnr

  call inline_edit#PushCursor()
  call cursor(self.start_line, 1)

  if self.start_line == 1 && self.end_line == line('$')
    let deleting_entire_file = 1
  else
    let deleting_entire_file = 0
  endif

  if self.end_line - self.start_line >= 0
    exe self.start_line . ',' . self.end_line . 'delete _'
  endif
  call append(self.start_line - 1, new_lines)

  if deleting_entire_file
    " After appending, we'll have one extra line
    $delete _
  endif

  if g:inline_edit_autowrite
    write
  endif
  call inline_edit#PopCursor()
  exe 'buffer ' . self.proxy_buffer

  let &bufhidden = saved_bufhidden

  " Keep the difference in lines to know how to update the other proxies if
  " necessary.
  let line_count     = self.end_line - self.start_line + 1
  let new_line_count = len(new_lines)

  let self.end_line = self.start_line + new_line_count - 1
  call s:UpdateProxyBuffer(self)

  call inline_edit#PopCursor() " in proxy buffer

  call self.controller.SyncProxies(self, new_line_count - line_count)
endfunction

" Called once upon setup. Returns the lines from the original buffer and the
" position of the cursor in that buffer.
function! s:LoadOriginalBufferContents(proxy)
  let proxy          = a:proxy
  let position       = getpos('.')
  let lines          = []
  let indent_pattern = '^\s\{'.proxy.indent.'}'

  if proxy.start_prefix == ''
    let start_line = proxy.start_line
  else
    call add(lines, strpart(getline(proxy.start_line), len(proxy.start_prefix)))
    let start_line = proxy.start_line + 1
  endif
  let end_line = proxy.end_line - 1

  for line in getbufline(proxy.original_buffer, start_line, end_line)
    call add(lines, substitute(line, indent_pattern, '', ''))
  endfor

  if proxy.end_suffix == ''
    call add(lines, substitute(getline(proxy.end_line), indent_pattern, '', ''))
  elseif proxy.start_line == proxy.end_line
    let lines[0] = strpart(lines[0], 0, len(lines[0]) - len(proxy.end_suffix))
  else
    let last_line = getline(proxy.end_line)
    let last_line = strpart(last_line, 0, len(last_line) - len(proxy.end_suffix))
    call add(lines, substitute(last_line, indent_pattern, '', ''))
  endif

  return [lines, position]
endfunction

" Called once upon setup. Creates the actual buffer and writes the given lines
" to it.
function! s:CreateProxyBuffer(proxy, lines)
  let proxy = a:proxy
  let lines = a:lines

  " avoid warnings
  let saved_readonly = &readonly
  let &readonly = 0

  if g:inline_edit_proxy_type == 'scratch'
    exe 'silent noswapfile ' . g:inline_edit_new_buffer_command

    setlocal buftype=acwrite
    setlocal bufhidden=wipe
    call append(0, lines)
    $delete _
    set nomodified
  elseif g:inline_edit_proxy_type == 'tempfile'
    exe 'silent noswapfile split ' . tempname()
    call append(0, lines)
    $delete _
    write
  endif

  let &readonly = saved_readonly

  set foldlevel=99
  let proxy.proxy_buffer = bufnr('%')
endfunction

" Called once upon setup and then after every write. After the actual updating
" logic is finished, this sets up some needed buffer properties.
function! s:UpdateProxyBuffer(proxy)
  let b:inline_edit_proxy = a:proxy
  let b:proxy = b:inline_edit_proxy " for compatibility's sake

  let a:proxy.description = printf('[%s:%d-%d]',
        \ fnamemodify(a:proxy.original_buffer, ':~:.'),
        \ a:proxy.start_line,
        \ a:proxy.end_line)

  if g:inline_edit_proxy_type == 'scratch'
    silent exec 'keepalt file ' . fnameescape(a:proxy.description)
  elseif g:inline_edit_proxy_type == 'tempfile'
    if g:inline_edit_modify_statusline
      if &statusline =~ '%[fF]'
        let statusline = substitute(&statusline, '%[fF]', '%{b:inline_edit_proxy.description}', '')
        exe "setlocal statusline=" . escape(statusline, ' |')
      endif
    endif
  endif

  if a:proxy.filetype == ''
    " attempt autodetection
    filetype detect
    let a:proxy.filetype = &filetype
  endif

  let &filetype = a:proxy.filetype
endfunction

" Called once upon setup. Manipulates the statusline to show information for
" the proxy. Does nothing if the proxy type is not "tempfile"
function! s:SetStatusline(proxy)
  if g:inline_edit_proxy_type != 'tempfile'
    return
  endif

  if !g:inline_edit_modify_statusline
    return
  endif

endfunction

" Called once upon setup. Positions the cursor where it was in the original
" buffer, relative to the extracted contents.
function! s:PositionCursor(proxy, position)
  let proxy       = a:proxy
  let position    = a:position
  let position[0] = bufnr(proxy.proxy_buffer)
  let position[1] = position[1] - proxy.start_line + 1

  call setpos('.', position)
endfunction

function! s:GetCommonIndent(start_line, end_line)
  let common_indent = indent(a:start_line)
  for lineno in range(a:start_line + 1, a:end_line)
    if getline(lineno) !~ '^\s*$' && indent(lineno) < common_indent
      let common_indent = indent(lineno)
    endif
  endfor

  if !&expandtab
    let common_indent = common_indent / &ts
  endif
  return common_indent
endfunction
