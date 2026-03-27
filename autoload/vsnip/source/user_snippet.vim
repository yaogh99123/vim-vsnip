vim9script

var cache: dict<any> = {}

# vsnip#source#user_snippet#find.
export def Find(bufnr: number): list<any>
  var sources: list<any> = []
  for path in GetSourcePaths(bufnr)
    if !has_key(cache, path)
      cache[path] = vsnip#source#create(path)
    endif
    add(sources, cache[path])
  endfor
  return sources
enddef

# vsnip#source#user_snippet#refresh.
export def Refresh(path: string): void
  if has_key(cache, path)
    unlet cache[path]
  endif
enddef

def GetSourceDirs(bufnr: number): list<any>
  var dirs: list<any> = []
  var buf_dir = getbufvar(bufnr, 'vsnip_snippet_dir', null)
  if buf_dir != null
    dirs += [buf_dir]
  endif
  dirs += getbufvar(bufnr, 'vsnip_snippet_dirs', [])
  dirs += [g:vsnip_snippet_dir]
  dirs += g:vsnip_snippet_dirs
  return dirs
enddef

# get_source_paths.
def GetSourcePaths(bufnr: number): list<any>
  var filetypes = vsnip#source#filetypes(bufnr)

  var paths: list<any> = []
  for dir in GetSourceDirs(bufnr)
    for filetype in filetypes
      var path = resolve(expand(printf('%s/%s.json', dir, filetype)))
      if has_key(cache, path) || filereadable(path)
        add(paths, path)
      endif
    endfor
  endfor
  return paths
enddef

# vsnip#source#user_snippet#dirs
export def Dirs(...args: list<any>): list<any>
  return GetSourceDirs(get(args, 0, bufnr('')))
enddef

# vsnip#source#user_snippet#paths
export def Paths(...args: list<any>): list<any>
  return GetSourcePaths(get(args, 0, bufnr('')))
enddef
