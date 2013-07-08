if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.2.0' " version number
let s:keepcpo            = &cpo
set cpo&vim

if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = []
endif

if !exists('g:inline_edit_autowrite')
  let g:inline_edit_autowrite = 0
endif

if !exists('g:inline_edit_html_like_filetypes')
  let g:inline_edit_html_like_filetypes = []
endif

if !exists('g:inline_edit_proxy_type')
  let g:inline_edit_proxy_type = 'scratch'
endif

if index(['scratch', 'tempfile'], g:inline_edit_proxy_type) < 0
  echoerr 'Inline Edit: Proxy type can''t be "'.g:inline_edit_proxy_type.'". Needs to be one of: scratch, tempfile'
endif

" Default patterns
call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'markdown',
      \ 'start':         '^\s*```\s*\(.\+\)',
      \ 'callback':      'inline_edit#MarkdownFencedCode',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'vim',
      \ 'start':         '^\s*\(\%(rub\|py\|pe\|mz\|lua\)\S*\)\s*<<\s*\(.*\)$',
      \ 'callback':      'inline_edit#VimEmbeddedScript'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'ruby',
      \ 'sub_filetype':      'sql',
      \ 'indent_adjustment': 1,
      \ 'start':             '<<-\?SQL',
      \ 'end':               '^\s*SQL',
      \ })

call add(g:inline_edit_patterns, {
      \ 'start':         '<<-\?\s*\(["'']\?\)\(\S*\)\1',
      \ 'main_filetype': 'sh\|ruby\|perl',
      \ 'callback':      'inline_edit#HereDoc'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     '*html',
      \ 'sub_filetype':      'javascript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script\>[^>]*>',
      \ 'end':               '</script>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     '*html',
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
  if !exists('b:inline_edit_controller')
    let b:inline_edit_controller = inline_edit#controller#New()
  endif

  let controller = b:inline_edit_controller

  if a:count > 0
    " then an area has been marked in visual mode
    call controller.VisualEdit(a:filetype)
  else
    let relevant_patterns = s:PatternsForFiletype(&filetype)

    for entry in relevant_patterns
      if controller.Edit(entry)
        return
      endif
    endfor

    " Nothing found, try to locate a pattern in the buffer
    let pattern = s:AutoLocate(controller, relevant_patterns)
    if !empty(pattern)
      call controller.Edit(pattern)
    endif
  endif
endfunction

function! s:PatternsForFiletype(filetype)
  let patterns = []

  for entry in g:inline_edit_patterns
    if has_key(entry, 'main_filetype')
      if entry.main_filetype == '*html'
        " treat "*html" as a special case
        let filetypes = ['html', 'eruby', 'php', 'eco'] + g:inline_edit_html_like_filetypes
        let regex = join(filetypes, '\|')
      else
        let regex = entry.main_filetype
      endif

      if a:filetype !~ regex
        continue
      endif
    endif

    call add(patterns, entry)
  endfor

  return patterns
endfunction

function! s:AutoLocate(controller, patterns)
  let current_line  = line('.')
  let saved_cursor  = winsaveview()
  let found_entries = {}

  for entry in a:patterns
    if !has_key(entry, 'start')
      " there's no "start" pattern to look for
      continue
    end

    call cursor(1, 1)

    " special case: beginning of file
    call search(entry.start. 'Wc')
    let found = a:controller.PrepareEdit(entry)
    if !empty(found)
      let [start, end, _f, _i] = found
      " attempt to locate based on both start and end lines.
      let found_entries[start] = entry
      let found_entries[end]   = entry
    endif

    while search(entry.start, 'We') > 0
      let found = a:controller.PrepareEdit(entry)
      if !empty(found)
        let [start, end, _f, _i] = found
        " attempt to locate based on both start and end lines.
        let found_entries[start] = entry
        let found_entries[end]   = entry
      endif
    endwhile
  endfor

  if !empty(found_entries)
    let found_lines  = map(keys(found_entries), 'str2nr(v:val)')
    let closest_line = found_lines[0]
    let min_distance = abs(closest_line - current_line)

    for line in found_lines
      if abs(line - current_line) < min_distance
        let closest_line = line
        let min_distance = abs(line - current_line)
      endif
    endfor

    " position in a nice place to trigger the edit
    exe closest_line
    normal! $

    return found_entries[closest_line]
  endif

  call winrestview(saved_cursor)
  return {}
endfunction
