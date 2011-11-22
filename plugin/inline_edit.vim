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

    let end = line('.') - 1

    call inline_edit#PopCursor()

    let proxy_buffer = inline_edit#proxy_buffer#New()
    call proxy_buffer.Init(start, end, filetype)

    return
  endfor
endfunction
