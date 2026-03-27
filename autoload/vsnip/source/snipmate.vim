vim9script

var cache: dict<any> = {}

export def Refresh(path: string): void
  if has_key(cache, path)
    unlet cache[path]
  endif
enddef

export def Find(bufnr: number): list<any>
  var filetypes = vsnip#source#filetypes(bufnr)
  return FindByTypes(filetypes, bufnr)
enddef

def FindByTypes(filetypes: list<any>, bufnr: number): list<any>
  var sources: list<any> = []
  for path in GetSourcePaths(filetypes, bufnr)
    if !has_key(cache, path)
      cache[path] = Create(path, bufnr)
    endif
    add(sources, cache[path])
  endfor
  return sources
enddef

def GetSourcePaths(filetypes: list<any>, bufnr: number): list<any>
  var paths: list<any> = []
  for dir in GetSourceDirs(bufnr)
    for filetype in filetypes
      var path = resolve(expand(printf('%s/%s.snippets', dir, filetype)))
      if has_key(cache, path) || filereadable(path)
        add(paths, path)
      endif
    endfor
  endfor
  return paths
enddef

def GetSourceDirs(bufnr: number): list<any>
  var dirs: list<any> = []
  var buf_dir = getbufvar(bufnr, 'vsnip_snippet_dir', '')
  if buf_dir !=# ''
    dirs += [buf_dir]
  endif
  dirs += getbufvar(bufnr, 'vsnip_snippet_dirs', [])
  dirs += [g:vsnip_snippet_dir]
  dirs += g:vsnip_snippet_dirs
  return dirs
enddef

def Create(path: string, bufnr: number): list<any>
  var file = readfile(path)
  var filelist: list<string> = type(file) == v:t_list ? file : [file]
  filelist = mapnew(filelist, (_, f) => iconv(f, 'utf-8', &encoding))
  var source: list<any> = []
  var i = -1
  while i + 1 < len(filelist)
    i = i + 1
    var line = filelist[i]
    if line =~# '^\(#\|\s*$\)'
      # Comment, or blank line before snippets
    elseif line =~# '^extends\s\+\S'
      var filetypes = mapnew(split(line[7 :], ','), (_, v) => trim(v))
      source += flatten(FindByTypes(filetypes, bufnr))
    elseif line =~# '^snippet\s\+\S' && i + 1 < len(filelist)
      var matched = matchlist(line, '^snippet\s\+\(\S\+\)\s*\(.*\)')
      var prefix = matched[1]
      var description = matched[2]
      var body: list<string> = []
      var indent = matchstr(filelist[i + 1], '^\s\+')
      while i + 1 < len(filelist) && filelist[i + 1] =~# '^\(' .. indent .. '\|\s*$\)'
        i = i + 1
        line = filelist[i]
        add(body, line[strlen(indent) :])
      endwhile
      var [prefixes, prefixes_alias] = vsnip#source#resolve_prefix(prefix)
      add(source, {
        label: prefix,
        prefix: prefixes,
        prefix_alias: prefixes_alias,
        body: body,
        description: description
      })
    else
      echohl ErrorMsg
      echomsg printf('[vsnip] Parsing error occurred on: %s#L%s', path, i + 1)
      echohl None
      break
    endif
  endwhile
  return sort(source, (a, b) => strlen(b.prefix[0]) - strlen(a.prefix[0]))
enddef
