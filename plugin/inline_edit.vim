if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.0.1' " version number
let s:keepcpo            = &cpo
set cpo&vim

if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = []

  call add(g:inline_edit_patterns, {
        \ 'main_filetype': 'markdown',
        \ 'sub_filetype':  'ruby',
        \ 'start_pattern': '```\s*ruby',
        \ 'end_pattern':   '```',
        \ })

  call add(g:inline_edit_patterns, {
        \ 'main_filetype': 'ruby',
        \ 'sub_filetype':  'sql',
        \ 'start_pattern': '<<-\?SQL',
        \ 'end_pattern':   '^\s*SQL',
        \ })

  call add(g:inline_edit_patterns, {
        \ 'main_filetype': 'html',
        \ 'sub_filetype':  'javascript',
        \ 'start_pattern': '<script\>[^>]*>',
        \ 'end_pattern':   '</script>',
        \ })

  call add(g:inline_edit_patterns, {
        \ 'main_filetype': 'html',
        \ 'sub_filetype':  'css',
        \ 'start_pattern': '<style\>[^>]*>',
        \ 'end_pattern':   '</style>',
        \ })

  call add(g:inline_edit_patterns, {
        \ 'main_filetype': 'htmldjango',
        \ 'sub_filetype':  'htmldjango',
        \ 'start_pattern': '{%\s*block\>.*%}',
        \ 'end_pattern':   '{%\s*endblock\s*%}',
        \ })
endif

if !exists('g:inline_edit_autowrite')
  let g:inline_edit_autowrite = 0
endif

command! -count=0 -nargs=* InlineEdit call s:InlineEdit(<count>, <q-args>)
function! s:InlineEdit(count, filetype)
  if a:count > 0
    " then an area has been marked in visual mode
    let [start, end] = [line("'<"), line("'>")]
    let indent = indent(end)

    if a:filetype != ''
      let filetype = a:filetype
    else
      let filetype = &filetype
    endif

    let proxy = inline_edit#proxy#New()
    call proxy.Init(start, end, filetype, indent)

    return
  endif

  for entry in g:inline_edit_patterns
    if entry.main_filetype !~ &filetype
      continue
    endif

    call inline_edit#PushCursor()

    " find start of area
    if searchpair(entry.start_pattern, '', entry.end_pattern, 'Wb') <= 0
      call inline_edit#PopCursor()
      continue
    endif

    let start = line('.') + 1

    " find end of area
    if searchpair(entry.start_pattern, '', entry.end_pattern, 'W') <= 0
      call inline_edit#PopCursor()
      continue
    endif

    let end    = line('.') - 1
    let indent = indent(end) " TODO (2011-11-27) Do something smarter here?

    call inline_edit#PopCursor()

    let proxy = inline_edit#proxy#New()
    call proxy.Init(start, end, entry.sub_filetype, indent)

    return
  endfor
endfunction
