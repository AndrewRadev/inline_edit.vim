function! inline_edit#proxy_buffer#New()
  let proxy_buffer = {
        \ 'original_buffer': -1,
        \ 'proxy_buffer':    -1,
        \ 'filetype':        '',
        \ 'start':           -1,
        \ 'end':             -1,
        \ 'is_blank':        1,
        \
        \ 'Init':                 function('inline_edit#proxy_buffer#Init'),
        \ 'UpdateOriginalBuffer': function('inline_edit#proxy_buffer#UpdateOriginalBuffer'),
        \ }

  return proxy_buffer
endfunction

function! inline_edit#proxy_buffer#Init(start_line, end_line, filetype) dict
  let self.original_buffer = bufnr('%')
  let self.start           = a:start_line
  let self.end             = a:end_line
  let self.filetype        = a:filetype
  let self.is_blank        = 0

  let lines     = getbufline('%', self.start, self.end)
  let temp_file = tempname()

  exe 'split ' . temp_file
  call append(0, lines)
  normal! Gdd
  set nomodified
  let &filetype = self.filetype

  let self.proxy_buffer = bufnr('%')
  let b:proxy_buffer    = self

  autocmd BufWrite <buffer> silent call b:proxy_buffer.UpdateOriginalBuffer()
endfunction

function! inline_edit#proxy_buffer#UpdateOriginalBuffer() dict
  let new_lines = getbufline('%', 0, '$')

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  exe 'buffer ' . self.original_buffer
  call inline_edit#PushCursor()
  call cursor(self.start, 1)
  exe 'normal! ' . (self.end - self.start + 1) . 'dd'
  call append(self.start - 1, new_lines)
  call inline_edit#PopCursor()
  exe 'buffer ' . self.proxy_buffer
endfunction
