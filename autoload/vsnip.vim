vim9script

import autoload 'vsnip/session.vim' as SessionMod
import autoload 'vsnip/snippet.vim' as SnippetMod

var TextEdit: dict<any> = vital#vsnip#import('VS.LSP.TextEdit')
var Position: dict<any> = vital#vsnip#import('VS.LSP.Position')

var g_session: any = null
var g_selected_text: string = ''

# vsnip#selected_text
export def selected_text(...args: list<any>): string
  if len(args) == 1
    g_selected_text = args[0]
    return ''
  else
    return g_selected_text
  endif
enddef

# vsnip#available
export def available(...args: list<any>): bool
  var direction = get(args, 0, 1)
  return expandable() || jumpable(direction)
enddef

# vsnip#expandable
export def expandable(): bool
  return !empty(get_context())
enddef

# vsnip#jumpable
export def jumpable(...args: list<any>): bool
  var direction = get(args, 0, 1)
  return !empty(g_session) && g_session.jumpable(direction)
enddef

# vsnip#expand
export def expand()
  var ctx = get_context()
  if !empty(ctx)
    TextEdit.apply(bufnr('%'), [{
      range: ctx.range,
      newText: '',
    }])
    anonymous(join(ctx.snippet.body, "\n"), {
      position: ctx.range.start,
    })
  endif
enddef

# vsnip#anonymous
export def anonymous(text: string, ...args: list<any>)
  var option: dict<any> = get(args, 0, {})
  var prefix: any = get(option, 'prefix', null)
  var position: dict<any> = get(option, 'position', Position.cursor())

  if prefix isnot null
    position.character -= strchars(prefix)
    TextEdit.apply(bufnr('%'), [{
      range: {
        start: position,
        end: {
          line: position.line,
          character: position.character + strchars(prefix),
        },
      },
      newText: '',
    }])
  endif

  var new_session = SessionMod.New(bufnr('%'), position, text)

  selected_text('')

  if !empty(g_session)
    g_session.flush_changes()
  endif

  if empty(g_session)
    g_session = new_session
    g_session.expand()
  else
    g_session.merge(new_session)
  endif

  doautocmd <nomodeline> User vsnip#expand

  g_session.refresh()
  g_session.jump(1)
enddef

# vsnip#get_session
export def get_session(): any
  return g_session
enddef

# vsnip#deactivate
export def deactivate()
  g_session = null
enddef

# vsnip#get_context
export def get_context(): any
  var offset = mode()[0] ==# 'i' ? 2 : 1
  var before_text = getline('.')[0 : col('.') - offset]
  var before_text_len = strchars(before_text)

  if before_text_len == 0
    return {}
  endif

  var sources = vsnip#source#find(bufnr('%'))

  # Search prefix
  for source in sources
    for snippet in source
      for prefix in snippet.prefix
        var prefix_len = strchars(prefix)
        if strcharpart(before_text, before_text_len - prefix_len, prefix_len) !=# prefix
          continue
        endif
        if prefix =~# '^\h' && before_text !~# '\<\V' .. escape(prefix, '\/?') .. '\m$'
          continue
        endif
        return CreateContext(snippet, before_text_len, prefix_len)
      endfor
    endfor
  endfor

  # Search prefix-alias
  for source in sources
    for snippet in source
      for prefix in snippet.prefix_alias
        var prefix_len = strchars(prefix)
        if strcharpart(before_text, before_text_len - prefix_len, prefix_len) !=# prefix
          continue
        endif
        if prefix =~# '^\h' && before_text !~# '\<\V' .. escape(prefix, '\/?') .. '\m$'
          continue
        endif
        return CreateContext(snippet, before_text_len, prefix_len)
      endfor
    endfor
  endfor

  return {}
enddef

# vsnip#completefunc
export def completefunc(findstart: number, base: string): any
  if !findstart
    if base ==# ''
      return []
    endif
    return get_complete_items(bufnr('%'))
  endif

  var line = getline('.')
  var start = col('.') - 2
  while start >= 0 && line[start] =~# '\k'
    start -= 1
  endwhile
  return start + 1
enddef

# vsnip#get_complete_items
export def get_complete_items(bufnr_: number): list<any>
  var uniq: dict<any> = {}
  var candidates: list<any> = []

  for source in vsnip#source#find(bufnr_)
    for snippet in source
      for prefix in snippet.prefix
        if has_key(uniq, prefix)
          continue
        endif
        uniq[prefix] = true

        var menu = ''
        menu ..= '[v]'
        menu ..= ' '
        menu ..= (strlen(snippet.description) > 0 ? snippet.description : snippet.label)

        add(candidates, {
          word: prefix,
          abbr: prefix,
          kind: 'Snippet',
          menu: menu,
          dup: 1,
          user_data: json_encode({
            vsnip: {
              snippet: snippet.body
            }
          })
        })
      endfor
    endfor
  endfor

  return candidates
enddef

# vsnip#to_string
export def to_string(text: any): string
  var t: string
  if type(text) == v:t_list
    t = join(text as list<any>, "\n")
  else
    t = text as string
  endif
  return SnippetMod.New(Position.cursor(), t).text()
enddef

# vsnip#debug
export def debug()
  if !empty(g_session)
    g_session.snippet.debug()
  endif
enddef

# create_context (internal helper)
def CreateContext(snippet: any, before_text_len: number, prefix_len: number): dict<any>
  var line = line('.') - 1
  return {
    range: {
      start: {
        line: line,
        character: before_text_len - prefix_len,
      },
      end: {
        line: line,
        character: before_text_len,
      },
    },
    snippet: snippet,
  }
enddef
