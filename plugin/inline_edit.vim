if exists('g:loaded_inline_edit') || &cp
  finish
endif

let g:loaded_inline_edit = '0.3.0' " version number
let s:keepcpo            = &cpo
set cpo&vim

if !exists('g:inline_edit_patterns')
  let g:inline_edit_patterns = []
endif

if !exists('g:inline_edit_autowrite')
  let g:inline_edit_autowrite = 0
endif

if !exists('g:inline_edit_python_guess_sql')
  let g:inline_edit_python_guess_sql = 1
endif

if !exists('g:inline_edit_html_like_filetypes')
  let g:inline_edit_html_like_filetypes = []
endif

if !exists('g:inline_edit_proxy_type')
  let g:inline_edit_proxy_type = 'scratch'
endif

if index(['scratch', 'tempfile', 'vscode'], g:inline_edit_proxy_type) < 0
  echoerr 'Inline Edit: Proxy type can''t be "'.g:inline_edit_proxy_type.'". Needs to be one of: scratch, tempfile, vscode'
endif

if !exists('g:inline_edit_new_buffer_command')
  let g:inline_edit_new_buffer_command = 'new'
endif

if !exists('g:inline_edit_modify_statusline')
  let g:inline_edit_modify_statusline = 1
endif

" Built in HTML-like filetypes, maps to the special "*html" pseudo-filetype
let s:html_like_filetypes = ['html', 'eruby', 'php', 'eco', 'vue']

" Default patterns
call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'markdown',
      \ 'callback':      'inline_edit#MarkdownFencedCode',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'rmd',
      \ 'callback':      'inline_edit#MarkdownFencedCode',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'vim',
      \ 'callback':      'inline_edit#VimEmbeddedScript'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'python',
      \ 'callback':      'inline_edit#PythonMultilineString'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'ruby',
      \ 'sub_filetype':      'sql',
      \ 'indent_adjustment': 1,
      \ 'start':             '<<[-~]\?SQL',
      \ 'end':               '^\s*SQL',
      \ })

call add(g:inline_edit_patterns, {
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
      \ 'main_filetype':     'vue',
      \ 'sub_filetype':      'typescript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script[^>]*lang=["'']ts["''][^>]*>',
      \ 'end':               '</script>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     '*html',
      \ 'sub_filetype':      'javascript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script\>[^>]*>',
      \ 'end':               '</script>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'vue',
      \ 'sub_filetype':      'scss',
      \ 'indent_adjustment': 1,
      \ 'start':             '<style[^>]*lang=["'']scss["''][^>]*>',
      \ 'end':               '</style>',
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

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'haml',
      \ 'sub_filetype':  'javascript',
      \ 'start':         '^\s*:javascript\>',
      \ 'indent_based':  1,
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'haml',
      \ 'sub_filetype':  'css',
      \ 'start':         '^\s*:css\>',
      \ 'indent_based':  1,
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'typescript',
      \ 'sub_filetype':  'html',
      \ 'callback':      'inline_edit#AngularHtmlTemplate'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype': 'typescript',
      \ 'sub_filetype':  'css',
      \ 'callback':      'inline_edit#AngularCssTemplate'
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'snakemake',
      \ 'sub_filetype':      'bash',
      \ 'indent_adjustment': 1,
      \ 'start':             '^\s*shell:\s*\%("""\|''''''\)$',
      \ 'end':               '^\s*\%("""\|''''''\)$',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'scala',
      \ 'sub_filetype':      'sql',
      \ 'indent_adjustment': 1,
      \ 'include_margins':   1,
      \ 'start':             '\(sql\|SQL\)"""',
      \ 'end':               '"""',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'templ',
      \ 'sub_filetype':      'typescript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script[^>]*lang=["'']ts["''][^>]*>',
      \ 'end':               '</script>',
      \ })

call add(g:inline_edit_patterns, {
      \ 'main_filetype':     'templ',
      \ 'sub_filetype':      'javascript',
      \ 'indent_adjustment': 1,
      \ 'start':             '<script\>[^>]*>',
      \ 'end':               '</script>',
      \ })

command! -range=0 -nargs=* -complete=filetype
      \ InlineEdit call s:InlineEdit(<count>, <q-args>)

function! s:InlineEdit(count, filetype)
  if !exists('b:inline_edit_controller')
    let b:inline_edit_controller = inline_edit#controller#New()
  endif

  let controller = b:inline_edit_controller

  if a:count > 0
    " then an area has been marked in visual mode
    call controller.VisualEdit(a:filetype)
  else
    for entry in g:inline_edit_patterns
      if has_key(entry, 'main_filetype')
        if entry.main_filetype == '*html'
          " treat "*html" as a special case
          let filetypes = s:html_like_filetypes + g:inline_edit_html_like_filetypes
          let pattern_filetype = join(filetypes, '\|')
        else
          let pattern_filetype = entry.main_filetype
        endif

        if &filetype !~ pattern_filetype
          continue
        endif
      endif

      if has_key(entry, 'callback')
        let result = call(entry.callback, [])

        if !empty(result)
          call call(controller.NewProxy, result, controller)

          if a:filetype != ''
            let &filetype = a:filetype
          endif

          return
        endif
      elseif get(entry, 'indent_based', 0) && controller.IndentEdit(entry, a:filetype)
        return
      elseif !get(entry, 'indent_based', 0) && controller.PatternEdit(entry, a:filetype)
        return
      endif
    endfor
  endif
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
