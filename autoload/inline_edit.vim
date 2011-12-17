" vim: set foldmethod=marker

" Cursor stack manipulation {{{1
"
" In order to make the pattern of saving the cursor and restoring it
" afterwards easier, these functions implement a simple cursor stack. The
" basic usage is:
"
"   call inline_edit#PushCursor()
"   " Do stuff that move the cursor around
"   call inline_edit#PopCursor()

" function! inline_edit#PushCursor() {{{2
"
" Adds the current cursor position to the cursor stack.
function! inline_edit#PushCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call add(b:cursor_position_stack, getpos('.'))
endfunction

" function! inline_edit#PopCursor() {{{2
"
" Restores the cursor to the latest position in the cursor stack, as added
" from the inline_edit#PushCursor function. Removes the position from the stack.
function! inline_edit#PopCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call setpos('.', remove(b:cursor_position_stack, -1))
endfunction

" function! inline_edit#PeekCursor() {{{2
"
" Returns the last saved cursor position from the cursor stack.
" Note that if the cursor hasn't been saved at all, this will raise an error.
function! inline_edit#PeekCursor()
  return b:cursor_position_stack[-1]
endfunction

" Callback functions {{{1

" function! inline_edit#MarkdownFencedCode() {{{2
"
" Opens up a new proxy buffer with the contents of a fenced code block in
" github-flavoured markdown.
function! inline_edit#MarkdownFencedCode()
  let start_pattern = '^\s*``` \(.\+\)'
  let end_pattern   = '^\s*```\s*$'

  call inline_edit#PushCursor()

  " find start of area
  if searchpair(start_pattern, '', end_pattern, 'Wb') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let start    = line('.') + 1
  let filetype = matchlist(getline('.'), start_pattern, 0)[1]

  " find end of area
  if searchpair(start_pattern, '', end_pattern, 'W') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let end    = line('.') - 1
  let indent = indent('.')

  call inline_edit#PopCursor()

  return [start, end, filetype, indent]
endfunction
