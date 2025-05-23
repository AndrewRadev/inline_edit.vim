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

  call add(b:cursor_position_stack, winsaveview())
endfunction

" function! inline_edit#PopCursor() {{{2
"
" Restores the cursor to the latest position in the cursor stack, as added
" from the inline_edit#PushCursor function. Removes the position from the stack.
function! inline_edit#PopCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call winrestview(remove(b:cursor_position_stack, -1))
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
  " Note: Optional `{` to handle Rmarkdown
  let start_pattern = '^\s*```\s*{\=\(\k\+\)'
  let end_pattern   = '^\s*```\s*$'

  call inline_edit#PushCursor()

  " find start of area
  if searchpair(start_pattern, '', end_pattern, 'Wb') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let start    = line('.') + 1
  let filetype_match = matchlist(getline('.'), start_pattern, 0)

  if len(filetype_match) > 0
    let filetype = filetype_match[1]
    let filetype = tolower(filetype)
  else
    " The start pattern doesn't match, the end one does. It's a weird
    " scenario, but it works out in practice.
    let filetype = ''
  endif

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

" function! inline_edit#VimEmbeddedScript() {{{2
"
" Opens up a new proxy buffer with ruby, python, perl, lua or mzscheme code
" embedded in vimscript.
function! inline_edit#VimEmbeddedScript()
  let start_pattern = '^\s*\(\%(rub\|py\|pe\|mz\|lua\)\S*\)\s*<<\s*\(.*\)$'

  if search(start_pattern, 'Wb') <= 0
    return []
  endif

  let start     = line('.') + 1
  let indent    = indent(start)
  let language  = substitute(getline('.'), start_pattern, '\1', '')
  let delimiter = substitute(getline('.'), start_pattern, '\2', '')

  if len(delimiter) == 0
    let delimiter = '.'
  endif

  if language =~ '^rub'
    let sub_filetype = 'ruby'
  elseif language =~ '^py'
    let sub_filetype = 'python'
  elseif language =~ '^pe'
    let sub_filetype = 'perl'
  elseif language =~ '^mz'
    let sub_filetype = 'scheme'
  elseif language == 'lua'
    let sub_filetype = 'lua'
  endif

  if search('^\V'.delimiter.'\$', 'W') <= 0
    return []
  endif
  let end = line('.') - 1

  return [start, end, sub_filetype, indent]
endfunction

" function! inline_edit#HereDoc() {{{2
"
" Opens up a new proxy buffer with the contents of a shell script here
" document.
function! inline_edit#HereDoc()
  " The beginning of a 'here doc' could be variations on any of these
  " forms:
  "   <<- "EOF"
  "   << 'ABC'
  "   <<WXYZ
  "   cat <<-EOF > newfile
  let start_pattern = '<<[-~]\?\s*\(["'']\?\)\(\S*\)\1'

  call inline_edit#PushCursor()

  " find the start of the inline area,
  " first on the current line, then on any previous lines
  if search(start_pattern, 'Wc', line('.')) <= 0
    if search(start_pattern, 'Wcb') <= 0
      call inline_edit#PopCursor()
      return []
    endif
  endif

  let start = line('.') + 1

  " define the end_pattern based on the token found in start_pattern
  let end_pattern = '^\s*' . matchlist(getline('.'), start_pattern)[2]

  " This should allow the command to run on the opening << EOF line,
  " in the middle of the heredoc, or on the closing EOF line.
  "
  " Go to the cursor's original position before searching for
  " end_pattern, but not the line indicating the start of the here doc,
  " otherwise the ending token might be matched on the opening line.
  call inline_edit#PopCursor()
  call inline_edit#PushCursor()
  " if the start of the new document is after the current line, then move
  " down one, otherwise stay put.
  if line('.') < start
    normal! j
  endif

  " find the end of the inline area
  if search(end_pattern, 'Wc') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let end = line('.') - 1

  call inline_edit#PopCursor()

  " automatic filetype detection
  let filetype = ''
  let indent = indent(start)

  return [start, end, filetype, indent]
endfunction

" function! inline_edit#PythonQuotedString() {{{2

" Opens up a new proxy buffer with the contents of a fenced code block in
" github-flavoured markdown.
function! inline_edit#PythonMultilineString()
  call inline_edit#PushCursor()

  try
    normal! 0

    if !s:CheckInsidePythonString()
      return []
    endif

    normal! $

    if !s:CheckInsidePythonString()
      return []
    endif

    " We are inside a Python multiline string, so we have to find the boundaries
    let quote_type = search('"""\|\(''''''\)', 'bWp')

    if quote_type == 0
      return []
    endif

    let start = line('.') + 1

    if quote_type == 1
      let end_quote = '"""'
    elseif quote_type == 2
      let end_quote = "'''"
    else
      echoerr "Invalid quote pattern found"
      return []
    endif

    let end = search(end_quote, 'W')

    if end == 0
      " No end quote was found
      return []
    endif

    let end -= 1
  finally
    call inline_edit#PopCursor()
  endtry

  let lines = join(getline(start, end), "\n")

  " We try to guess the filetype
  if g:inline_edit_python_guess_sql && (
      \ lines =~# '\<SELECT\>\_.*\<FROM\>'
      \ || lines =~# '\<CREATE\>\_s*\<OR\>\_s*\<REPLACE\>'
      \ )
    " This is a SQL file
    let filetype = 'sql'
  else
    let filetype = ''
  endif

  let indent = indent(start)
  for i in range(start + 1, end)
    let current_indent = indent(i)
    " Get the minimum indent of the non-blank lines
    if current_indent < indent && getline(i) !~? '^\s*$'
      let indent = current_indent
    endif
  endfor

  return [start, end, filetype, indent]
endfunction

" function! inline_edit#AngularHtmlTemplate() {{{2
function! inline_edit#AngularHtmlTemplate()
  call inline_edit#PushCursor()
  let cursor_line = line('.')

  try
    let [component_start, component_end] = s:CheckInsideAngularComponent()
    if component_start < 0
      return []
    endif

    let start_backtick = search('^\s*template:\s*`\s*$', 'bWe')
    if start_backtick == 0
      return []
    endif

    normal! j0
    let start = line('.')
    let end = search('^\s*`\(,\|$\)', 'W')

    if end == 0 || end < cursor_line
      " No end quote was found or end quote was above cursor
      return []
    endif

    let end -= 1
  finally
    call inline_edit#PopCursor()
  endtry

  let indent = s:GetCommonIndent(start, end)

  return [start, end, 'html', indent]
endfunction

" function! inline_edit#AngularCssTemplate() {{{2
function! inline_edit#AngularCssTemplate()
  call inline_edit#PushCursor()
  let cursor_line = line('.')

  try
    let [component_start, _] = s:CheckInsideAngularComponent()
    if component_start < 0
      return []
    endif

    let [array_start, array_end] = s:CheckInsideStylesArray()
    if array_start < 0
      return []
    endif

    let start_backtick = search('`', 'bWec', array_start)
    if start_backtick == 0
      return []
    endif

    normal! j0
    let start = line('.')
    let end = search('`\(,\|$\)', 'Wc', array_end)

    if end == 0 || end < cursor_line
      " No end quote was found or end quote was above cursor
      return []
    endif

    let end -= 1

    if end - start <= 0
      " no multiline content
      return []
    endif
  finally
    call inline_edit#PopCursor()
  endtry

  let indent = s:GetCommonIndent(start, end)

  return [start, end, 'css', indent]
endfunction

function s:CheckInsidePythonString()
  return index(map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")'), "pythonString") >= 0
endfunction

function s:CheckInsideAngularComponent()
  let current_pos = getpos('.')
  let saved_view = winsaveview()

  try
    if search('^\s*@Component({', 'bWe') <= 0
      return [-1, -1]
    endif

    let start_pos = getpos('.')

    let skip_syntax = s:SkipSyntax(['typescriptString', 'typescriptTemplate', 'typescriptComment'])
    if searchpair('{', '', '}', 'W', skip_syntax) <= 0
      return [-1, -1]
    endif

    let end_pos = getpos('.')

    if s:PosInside(current_pos, start_pos, end_pos)
      return [start_pos[1], end_pos[1]]
    else
      return [-1, -1]
    endif
  finally
    call winrestview(saved_view)
  endtry
endfunction

function s:CheckInsideStylesArray()
  let current_pos = getpos('.')
  let saved_view = winsaveview()

  try
    if search('^\s*styles:\s*[', 'bWe') <= 0
      return [-1, -1]
    endif

    let start_pos = getpos('.')

    let skip_syntax = s:SkipSyntax(['typescriptString', 'typescriptTemplate', 'typescriptComment'])
    if searchpair('\[', '', '\]', 'W', skip_syntax) <= 0
      return [-1, -1]
    endif

    let end_pos = getpos('.')

    if s:PosInside(current_pos, start_pos, end_pos)
      return [start_pos[1], end_pos[1]]
    else
      return [-1, -1]
    endif
  finally
    call winrestview(saved_view)
  endtry
endfunction

function s:GetCommonIndent(start, end)
  let indent = indent(a:start)

  for i in range(a:start + 1, a:end)
    let current_indent = indent(i)

    " Get the minimum indent of the non-blank lines
    if current_indent < indent && getline(i) !~? '^\s*$'
      let indent = current_indent
    endif
  endfor

  return indent
endfunction

function s:SkipSyntax(syntax_groups)
  let skip_pattern  = '\%('.join(a:syntax_groups, '\|').'\)'
  return "synIDattr(synID(line('.'),col('.'),1),'name') =~# '".skip_pattern."'"
endfunction

function! s:PosInside(current, start, end) abort
  let [_, current_line, current_col, _] = a:current
  let [_, start_line, start_col, _]     = a:start
  let [_, end_line, end_col, _]         = a:end

  " If the start and end are the same, we don't have anything to edit
  if start_line == end_line
    return 0
  endif

  if current_line > start_line && current_line < end_line
    return 1
  elseif current_line == start_line && current_line <= end_line && current_col > start_col
    return 1
  elseif current_line == end_line && current_line >= start_line && current_col < end_col
    return 1
  else
    return 0
  endif
endfunction
