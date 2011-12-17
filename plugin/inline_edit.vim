if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.1.0' " version number
let s:keepcpo            = &cpo
set cpo&vim

if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = []
endif

if !exists('g:inline_edit_autowrite')
  let g:inline_edit_autowrite = 0
endif

" Default patterns
call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'markdown',
      \ 'callback':      'inline_edit#MarkdownFencedCode',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'ruby',
      \ 'sub_filetype':      'sql',
      \ 'indent_adjustment': 1,
      \ 'start':             '<<-\?SQL',
      \ 'end':               '^\s*SQL',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'html\|eruby\|php',
      \ 'sub_filetype':      'javascript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script\>[^>]*>',
      \ 'end':               '</script>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'html\|eruby\|php',
      \ 'sub_filetype':      'css',
      \ 'indent_adjustment': 1,
      \ 'start':             '<style\>[^>]*>',
      \ 'end':               '</style>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'htmldjango',
      \ 'start':         '{%\s*block\>.*%}',
      \ 'end':           '{%\s*endblock\s*%}',
      \ })

command! -count=0 -nargs=* InlineEdit call s:InlineEdit(<count>, <q-args>)
function! s:InlineEdit(count, filetype)
  if a:count > 0
    " then an area has been marked in visual mode
    call s:VisualInlineEdit(a:filetype)
  else
    for entry in g:inline_edit_patterns
      if has_key(entry, 'main_filetype') && &filetype !~ entry.main_filetype
        continue
      endif

      if has_key(entry, 'callback')
        let result = call(entry.callback, [])

        if !empty(result)
          call call('inline_edit#proxy#New', result)
          return
        endif
      elseif s:PatternInlineEdit(entry)
        return
      endif
    endfor
  endif
endfunction

function! s:VisualInlineEdit(filetype)
  let [start, end] = [line("'<"), line("'>")]
  let indent = indent(end)

  if a:filetype != ''
    let filetype = a:filetype
  else
    let filetype = &filetype
  endif

  call inline_edit#proxy#New(start, end, filetype, indent)
endfunction

function! s:PatternInlineEdit(pattern)
  let pattern = extend({
        \ 'sub_filetype':      &filetype,
        \ 'indent_adjustment': 0,
        \ }, a:pattern)

  call inline_edit#PushCursor()

  " find start of area
  if searchpair(pattern.start, '', pattern.end, 'Wb') <= 0
    call inline_edit#PopCursor()
    return 0
  endif
  let start = line('.') + 1

  " find end of area
  if searchpair(pattern.start, '', pattern.end, 'W') <= 0
    call inline_edit#PopCursor()
    return 0
  endif
  let end    = line('.') - 1
  let indent = indent(line('.')) + pattern.indent_adjustment * (&et ? &sw : &ts)

  call inline_edit#PopCursor()

  call inline_edit#proxy#New(start, end, pattern.sub_filetype, indent)

  return 1
endfunction
