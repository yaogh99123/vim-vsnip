vim9script

var snippets: dict<any> = {}
var runtimepaths: dict<any> = {}

# vsnip#source#vscode#refresh.
export def Refresh(path: string): void
  if has_key(snippets, path)
    unlet snippets[path]

    for [rtp, v] in items(runtimepaths)
      if stridx(rtp, path) == 0
        unlet runtimepaths[rtp]
      endif
    endfor
  endif
enddef

# vsnip#source#vscode#find.
export def Find(bufnr: number): list<any>
  return FindByLanguages(mapnew(vsnip#source#filetypes(bufnr), (_, ft) => GetLanguage(ft)))
enddef

# find.
def FindByLanguages(languages: list<any>): list<any>
  # Load `package.json#contributes.snippets` if does not exist in cache.
  var rtp_list: list<string> = exists('*nvim_list_runtime_paths') ? nvim_list_runtime_paths() : split(&runtimepath, ',')
  for rtp in rtp_list
    if has_key(runtimepaths, rtp)
      continue
    endif
    runtimepaths[rtp] = true

    try
      var package_json_path = resolve(expand(rtp .. '/package.json'))
      if !filereadable(package_json_path)
        continue
      endif
      var package_json_lines = readfile(package_json_path)
      var package_json_str = type(package_json_lines) == v:t_list ? join(package_json_lines, "\n") : package_json_lines
      package_json_str = iconv(package_json_str, 'utf-8', &encoding)
      var package_json = json_decode(package_json_str)

      # if package.json has not `contributes.snippets` fields, skip it.
      if !has_key(package_json, 'contributes')
          || !has_key(package_json.contributes, 'snippets')
        continue
      endif

      # Create source if it does not exist in cache.
      for snippet in package_json.contributes.snippets
        var path = resolve(expand(rtp .. '/' .. snippet.path))
        var languages = type(snippet.language) == v:t_list ? snippet.language : [snippet.language]

        # if already cached `snippets.json`, add new language.
        if has_key(snippets, path)
          for language in languages
            if index(snippets[path].languages, language) == -1
              add(snippets[path].languages, language)
            endif
          endfor
          continue
        endif

        # register new snippet.
        snippets[path] = {
          languages: languages,
        }
      endfor
    catch /.*/
    endtry
  endfor

  # filter by language.
  var sources: list<any> = []
  for language in languages
    for [path, snippet] in items(snippets)
      if index(snippet.languages, language) >= 0
        if !has_key(snippet, 'source')
          snippet.source = vsnip#source#create(path)
        endif
        add(sources, snippet.source)
      endif
    endfor
  endfor
  return sources
enddef

# get_language.
def GetLanguage(filetype: string): string
  return get({
    'javascript.jsx': 'javascriptreact',
    'typescript.tsx': 'typescriptreact',
    'sh': 'shellscript',
    'cs': 'csharp',
  }, filetype, filetype)
enddef
