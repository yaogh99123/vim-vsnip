vim9script

# vsnip#source#refresh.
export def refresh(path: string)
  vsnip#source#user_snippet#refresh(path)
  vsnip#source#vscode#refresh(path)
  vsnip#source#snipmate#refresh(path)
enddef

# vsnip#source#find.
export def find(bufnr: number): list<any>
  var sources: list<any> = []
  sources += vsnip#source#user_snippet#find(bufnr)
  sources += vsnip#source#vscode#find(bufnr)
  sources += vsnip#source#snipmate#find(bufnr)
  return sources
enddef

# vsnip#source#filetypes
export def filetypes(bufnr: number): list<any>
  if has('nvim')
    var ft_result = v:lua.require'vsnip.treesitter'.get_ft_at_cursor(bufnr)

    # buffer has no filetype defined
    if ft_result.filetype == ""
      return ["global"]

    # buffer has filetype
    else
      return get(g:vsnip_filetypes, ft_result.injected_filetype,
               get(g:vsnip_filetypes, ft_result.filetype,
               [ft_result.filetype]
               )) + ["global"]
    endif
  else
    var filetype = getbufvar(bufnr, "&filetype", "")

    return split(filetype, '\.') + get(g:vsnip_filetypes, filetype, []) + ["global"]
  endif
enddef

# vsnip#source#create.
export def create(path: string): list<any>
  var json: any = {}
  try
    var file_lines = readfile(path)
    var file_content = iconv(join(file_lines, "\n"), 'utf-8', &encoding)
    json = json_decode(file_content)

    if type(json) != v:t_dict
      throw printf('%s is not valid json.', path)
    endif
  catch /.*/
    json = {}
    echohl ErrorMsg
    echomsg printf('[vsnip] Parsing error occurred on: %s', path)
    echohl None
    echomsg string({'exception': v:exception, 'throwpint': v:throwpoint})
  endtry

  # @see https://github.com/microsoft/vscode/blob/0ba9f6631daec96a2b71eeb337e29f50dd21c7e1/src/vs/workbench/contrib/snippets/browser/snippetsFile.ts#L216
  var source: list<any> = []
  for [key, value] in items(json)
    if IsSnippet(value)
      add(source, FormatSnippet(key, value))
    else
      for [inner_key, value_] in items(value)
        if IsSnippet(value_)
          add(source, FormatSnippet(inner_key, value_))
        endif
      endfor
    endif
  endfor
  return sort(source, (a, b) => strlen(b.prefix[0]) - strlen(a.prefix[0]))
enddef

# format_snippet
def FormatSnippet(label: string, snippet: any): dict<any>
  var [prefixes, prefixes_alias] = vsnip#source#resolve_prefix(snippet.prefix)
  var description = get(snippet, 'description', '')

  return {
    'label': label,
    'prefix': prefixes,
    'prefix_alias': prefixes_alias,
    'body': type(snippet.body) == v:t_list ? snippet.body : [snippet.body],
    'description': type(description) == v:t_list ? join(description, '') : description,
  }
enddef

# is_snippet
def IsSnippet(snippet_or_source: any): bool
  return type(snippet_or_source) == v:t_dict && has_key(snippet_or_source, 'prefix') && has_key(snippet_or_source, 'body')
enddef

# vsnip#source#resolve_prefix.
export def resolve_prefix(prefix: any): list<any>
  var prefixes: list<any> = []
  var prefixes_alias: list<any> = []

  for p in (type(prefix) == v:t_list ? prefix : [prefix])
    # namespace.
    if strlen(g:vsnip_namespace) > 0
      add(prefixes, g:vsnip_namespace .. p)
    endif

    # prefix.
    add(prefixes, p)

    # alias.
    if p =~ '^\h\w*\%(-\w\+\)\+$'
      add(prefixes_alias, join(map(split(p, '-'), (i, v) => v[0]), ''))
    endif
  endfor

  return [
    sort(prefixes, (a, b) => strlen(b) - strlen(a)),
    sort(prefixes_alias, (a, b) => strlen(b) - strlen(a))
  ]
enddef
