if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.2.1' " version number
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

if !exists('g:inline_edit_new_buffer_command')
  let g:inline_edit_new_buffer_command = 'new'
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
      \ 'main_filetype':     'vue',
      \ 'sub_filetype':      'html',
      \ 'indent_adjustment': 1,
      \ 'start':             '<template\>[^>]*>',
      \ 'end':               '</template>'
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
command! InlineEditJumpPrev call s:InlineEditJump(-1)
command! InlineEditJumpNext call s:InlineEditJump(1)

nnoremap <Plug>InlineEditJumpPrev :InlineEditJumpPrev<cr>
nnoremap <Plug>InlineEditJumpNext :InlineEditJumpNext<cr>

function! s:InlineEdit(count, filetype)
  let controller = s:Controller()

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
  endif
endfunction

function! s:Controller()
  if !exists('b:inline_edit_controller')
    let b:inline_edit_controller = inline_edit#controller#New()
  endif

  return b:inline_edit_controller
endfunction

function! s:InlineEditJump(direction)
  let controller        = s:Controller()
  let relevant_patterns = s:PatternsForFiletype(&filetype)
  let current_line      = line('.')
  let saved_cursor      = winsaveview()
  let found_entries     = {}

  for entry in relevant_patterns
    if !has_key(entry, 'start')
      " there's no "start" pattern to look for
      continue
    end

    call cursor(1, 1)

    " special case: beginning of file
    call search(entry.start. 'Wc')
    let found = controller.PrepareEdit(entry)
    if !empty(found)
      let [start, end, _f, _i] = found
      " attempt to locate based on start line
      let found_entries[start] = entry
    endif

    while search(entry.start, 'We') > 0
      let found = controller.PrepareEdit(entry)
      if !empty(found)
        let [start, end, _f, _i] = found
        " attempt to locate based on start line
        let found_entries[start] = entry
      endif
    endwhile
  endfor

  let found_lines  = map(keys(found_entries), 'str2nr(v:val)')

  if a:direction > 0
    let found_lines = filter(found_lines, 'v:val > '.current_line)
  else
    let found_lines = filter(found_lines, 'v:val < '.current_line)
  endif

  if empty(found_lines)
    call winrestview(saved_cursor)
    return {}
  endif

  let closest_line = found_lines[0]
  let min_distance = abs(closest_line - current_line)

  for line in found_lines
    if abs(line - current_line) < min_distance
      let closest_line = line
      let min_distance = abs(line - current_line)
    endif
  endfor

  exe closest_line
  " normal! $

  return found_entries[closest_line]
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

let &cpo = s:keepcpo
unlet s:keepcpo
