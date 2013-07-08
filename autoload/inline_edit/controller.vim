function! inline_edit#controller#New()
  let controller = {
        \ 'proxies': [],
        \
        \ 'NewProxy':            function('inline_edit#controller#NewProxy'),
        \ 'SyncProxies':         function('inline_edit#controller#SyncProxies'),
        \ 'VisualEdit':          function('inline_edit#controller#VisualEdit'),
        \ 'PatternEdit':         function('inline_edit#controller#PatternEdit'),
        \ 'CallbackEdit':        function('inline_edit#controller#CallbackEdit'),
        \ 'Edit':                function('inline_edit#controller#Edit'),
        \ 'PreparePatternEdit':  function('inline_edit#controller#PreparePatternEdit'),
        \ 'PrepareCallbackEdit': function('inline_edit#controller#PrepareCallbackEdit'),
        \ 'PrepareEdit':         function('inline_edit#controller#PrepareEdit'),
        \ }

  return controller
endfunction

function! inline_edit#controller#NewProxy(start_line, end_line, filetype, indent) dict
  let proxy = inline_edit#proxy#New(self, a:start_line, a:end_line, a:filetype, a:indent)
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

    if a:changed_proxy.end <= proxy.start
      let proxy.start += a:delta
      let proxy.end   += a:delta
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

" Tries to locate the necessary points of reference for a pattern edit.
function! inline_edit#controller#PreparePatternEdit(pattern) dict
  let pattern = extend({
        \ 'sub_filetype':      &filetype,
        \ 'indent_adjustment': 0,
        \ }, a:pattern)

  call inline_edit#PushCursor()

  " find start of area
  if searchpair(pattern.start, '', pattern.end, 'Wb') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let start = line('.') + 1

  " find end of area
  if searchpair(pattern.start, '', pattern.end, 'W') <= 0
    call inline_edit#PopCursor()
    return []
  endif
  let end    = line('.') - 1
  let indent = indent(line('.')) + pattern.indent_adjustment * (&et ? &sw : &ts)

  call inline_edit#PopCursor()

  return [start, end, pattern.sub_filetype, indent]
endfunction

function! inline_edit#controller#PatternEdit(pattern) dict
  let edit_attempt = self.PreparePatternEdit(a:pattern)

  if empty(edit_attempt)
    return 0
  else
    let [start, end, filetype, indent] = edit_attempt
    call self.NewProxy(start, end, filetype, indent)
    return 1
  endif
endfunction

function! inline_edit#controller#CallbackEdit(pattern) dict
  let result = self.PrepareCallbackEdit(a:pattern)

  if !empty(result)
    call call(self.NewProxy, result, self)
    return 1
  endif

  return 0
endfunction

function! inline_edit#controller#PrepareCallbackEdit(pattern) dict
  return call(a:pattern.callback, [])
endfunction

function! inline_edit#controller#PrepareEdit(pattern) dict
  if has_key(a:pattern, 'callback')
    return self.PrepareCallbackEdit(a:pattern)
  else
    return self.PreparePatternEdit(a:pattern)
  endif
endfunction

function! inline_edit#controller#Edit(pattern) dict
  if has_key(a:pattern, 'callback')
    if self.CallbackEdit(a:pattern)
      return
    endif
  elseif self.PatternEdit(a:pattern)
    return
  endif
endfunction
