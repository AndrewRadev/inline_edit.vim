if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.0.1' " version number
let s:keepcpo            = &cpo
set cpo&vim

if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = [
        \ ['```\s*ruby',       '```',                'ruby'],
        \ ['<<-\?SQL',         '^\s*SQL',            'sql'],
        \ ['<script\>[^>]*>',  '</script>',          'javascript'],
        \ ['<style\>[^>]*>',   '</style>',           'css'],
        \ ['{%\s*block\>.*%}', '{%\s*endblock\s*%}', 'htmldjango'],
        \ ]
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
    call inline_edit#PushCursor()

    let [start_pattern, end_pattern, filetype] = entry

    " find start of area
    if searchpair(start_pattern, '', end_pattern, 'Wb') <= 0
      call inline_edit#PopCursor()
      continue
    endif

    let start = line('.') + 1

    " find end of area
    if searchpair(start_pattern, '', end_pattern, 'W') <= 0
      call inline_edit#PopCursor()
      continue
    endif

    let end    = line('.') - 1
    let indent = indent(end) " TODO (2011-11-27) Do something smarter here?

    call inline_edit#PopCursor()

    let proxy = inline_edit#proxy#New()
    call proxy.Init(start, end, filetype, indent)

    return
  endfor
endfunction
