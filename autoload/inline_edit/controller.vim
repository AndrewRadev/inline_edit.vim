let s:type_list = type([])

function! inline_edit#controller#New()
  let controller = {
        \ 'proxies': [],
        \
        \ 'NewProxy':    function('inline_edit#controller#NewProxy'),
        \ 'SyncProxies': function('inline_edit#controller#SyncProxies'),
        \ 'VisualEdit':  function('inline_edit#controller#VisualEdit'),
        \ 'PatternEdit': function('inline_edit#controller#PatternEdit'),
        \ 'IndentEdit':  function('inline_edit#controller#IndentEdit'),
        \ }

  return controller
endfunction

function! inline_edit#controller#NewProxy(start, end, filetype, indent) dict
  if type(a:start) == s:type_list
    let [start_line, start_col] = a:start
  else
    let start_line = a:start
    let start_col = 0
  endif

  if type(a:end) == s:type_list
    let [end_line, end_col] = a:end
  else
    let end_line = a:end
    let end_col = 0
  endif

  let proxy = inline_edit#proxy#New(self, start_line, end_line, start_col, end_col, a:filetype, a:indent)
  call add(self.proxies, proxy)

  return proxy
endfunction

" If any of the other proxies are located below the given one, we need to
" update their starting and ending lines, since any change would result in a
" line shift.
"
" a:changed_proxy is the proxy that changed
" a:delta is the change in the number of lines.
function! inline_edit#controller#SyncProxies(changed_proxy, delta) dict
  if a:delta == 0
    return
  endif

  for proxy in self.proxies
    if proxy == a:changed_proxy
      continue
    endif

    if a:changed_proxy.end_line <= proxy.start_line
      let proxy.start_line += a:delta
      let proxy.end_line   += a:delta
    endif
  endfor
endfunction

function! inline_edit#controller#VisualEdit(filetype) dict
  let [start, end] = [line("'<"), line("'>")]
  let indent = indent(end)

  if a:filetype != ''
    let filetype = a:filetype
  else
    let filetype = &filetype
  endif

  call self.NewProxy(start, end, filetype, indent)
endfunction

function! inline_edit#controller#PatternEdit(pattern, filetype_override) dict
  let pattern = extend({
        \ 'sub_filetype':      &filetype,
        \ 'indent_adjustment': 0,
        \ }, a:pattern)

  if a:filetype_override != ''
    let pattern.sub_filetype = a:filetype_override
  endif

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
  let end = line('.') - 1

  if get(pattern, 'include_margins', 0)
    " Take the indent from the second line, if there is one, otherwise we have
    " a fully inline pattern, so indent isn't going to matter
    if end - start >= 0
      let indent = indent(start + 1)
    else
      let indent = 0
    endif

    let end_col_start = 0

    " If start pattern has any non-whitespace afterwards, take its column:
    let [_m, _ms, match_end] = matchstrpos(getline(start - 1), pattern.start .. '\s*\S')
    if match_end > 0
      let start = [start - 1, match_end]

      if start[0] == end + 1
        " then the start line is the same as the end line, so we should start
        " searching for the end pattern after the end of this match
        let end_col_start = match_end
      endif
    endif

    " If end pattern is preceded by any non-whitespace, take its column:
    let [_m, match_start, _me] = matchstrpos(getline(end + 1), '\S\s*\zs'.pattern.end, end_col_start)
    if match_start > 0
      let end = [end + 1, match_start + 1]
    endif
  else
    " Take the indent of the current (end) line as the baseline
    let indent = indent(line('.')) + pattern.indent_adjustment * (&et ? &sw : &ts)
  endif

  call inline_edit#PopCursor()
  call self.NewProxy(start, end, pattern.sub_filetype, indent)
  return 1
endfunction

function! inline_edit#controller#IndentEdit(pattern, filetype_override) dict
  let pattern = extend({
        \ 'sub_filetype':      &filetype,
        \ 'indent_adjustment': 0,
        \ }, a:pattern)

  if a:filetype_override != ''
    let pattern.sub_filetype = a:filetype_override
  endif

  call inline_edit#PushCursor()

  " find start of area
  if search(pattern.start, 'Wb') <= 0
    call inline_edit#PopCursor()
    return 0
  endif
  let start = line('.') + 1

  " find end of area
  let end = s:LowerIndentLimit(start)
  if end - start < 0
    return 0
  endif
  let indent = indent(end) + pattern.indent_adjustment * (&et ? &sw : &ts)

  call inline_edit#PopCursor()

  if line('.') < (start - 1) || line('.') > end
    " then we're not inside the section
    return 0
  endif

  call self.NewProxy(start, end, pattern.sub_filetype, indent)
  return 1
endfunction

function! s:LowerIndentLimit(lineno)
  let base_indent  = indent(a:lineno)
  let current_line = a:lineno
  let next_line    = nextnonblank(current_line + 1)

  while current_line < line('$') && indent(next_line) >= base_indent
    let current_line = next_line
    let next_line    = nextnonblank(current_line + 1)
  endwhile

  return current_line
endfunction
