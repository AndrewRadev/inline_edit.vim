if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = [
        \ ['```\s*ruby',      '```',       'ruby'],
        \ ['<<-\?SQL',        '^\s*SQL',   'sql'],
        \ ['<script\>[^>]*>', '</script>', 'javascript'],
        \ ]
endif

command! InlineEdit call s:InlineEdit()
function! s:InlineEdit()
  for entry in g:inline_edit_patterns
    call s:PushCursor()

    let [start_pattern, end_pattern, filetype] = entry

    " find start of area
    if searchpair(start_pattern, '', end_pattern, 'Wb') <= 0
      call s:PopCursor()
      continue
    endif

    let start = line('.') + 1

    " find end of area
    if searchpair(start_pattern, '', end_pattern, 'W') <= 0
      call s:PopCursor()
      continue
    endif

    let end = line('.') - 1

    call s:PopCursor()
    call s:InitProxyBuffer(start, end, filetype)

    return
  endfor
endfunction

function! s:InitProxyBuffer(start_line, end_line, filetype)
  let original_buffer = bufnr('%')
  let lines           = getbufline('%', a:start_line, a:end_line)
  let temp_file       = tempname()

  exe 'split '.temp_file
  call append(0, lines)
  normal! Gdd
  set nomodified
  let &filetype = a:filetype

  let b:original_buffer = original_buffer
  let b:start           = a:start_line
  let b:end             = a:end_line

  autocmd BufWrite <buffer> silent call s:UpdateOriginalBuffer()
endfunction

function! s:UpdateOriginalBuffer()
  let new_lines       = getbufline('%', 0, '$')
  let start           = b:start
  let end             = b:end
  let proxy_buffer    = bufnr('%')
  let original_buffer = b:original_buffer

  " Switch to the original buffer, delete the relevant lines, add the new
  " ones, switch back to the diff buffer.
  exe "buffer ".original_buffer
  call s:PushCursor()
  call cursor(start, 1)
  exe "normal! ".(end - start + 1)."dd"
  call append(start - 1, new_lines)
  call s:PopCursor()
  exe "buffer ".proxy_buffer
endfunction

" function! s:PushCursor() {{{2
"
" Adds the current cursor position to the cursor stack.
function! s:PushCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call add(b:cursor_position_stack, getpos('.'))
endfunction

" function! s:PopCursor() {{{2
"
" Restores the cursor to the latest position in the cursor stack, as added
" from the s:PushCursor function. Removes the position from the stack.
function! s:PopCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call setpos('.', remove(b:cursor_position_stack, -1))
endfunction

" function! s:PeekCursor() {{{2
"
" Returns the last saved cursor position from the cursor stack.
" Note that if the cursor hasn't been saved at all, this will raise an error.
function! s:PeekCursor()
  return b:cursor_position_stack[-1]
endfunction
