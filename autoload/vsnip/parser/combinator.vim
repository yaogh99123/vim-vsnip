vim9script

# A Parser wraps a parse function. Each factory function returns a Parser built
# from a closure, avoiding method calls on `any`-typed variables at runtime.
export class Parser
  var Parsefn: func(string, number): list<any>

  def new(Fn: func(string, number): list<any>)
    this.Parsefn = Fn
  enddef

  def Parse(text: string, pos: number): list<any>
    return this.Parsefn(text, pos)
  enddef
endclass

def Getchar(text: string, pos: number): string
  var nr = strgetchar(text, pos)
  if nr != -1
    return nr2char(nr)
  endif
  return ''
enddef

# Matches a run of characters, stopping at stop chars and handling backslash escapes.
export def Skip(stop: list<string>, escape: list<string>): Parser
  return Parser.new((text: string, pos: number): list<any> => {
    var cur_pos = pos
    var value = ''
    var len = strchars(text)
    while cur_pos < len
      var char = Getchar(text, cur_pos)
      if char ==# '\'
        cur_pos += 1
        char = Getchar(text, cur_pos)
        if index(stop + escape + ['\'], char) == -1
          value ..= '\'
          continue  # ignore unrecognised escape; re-process next char
        endif
        cur_pos += 1
        value ..= char
        continue
      endif
      if index(stop, char) >= 0
        if pos != cur_pos
          return [true, [strcharpart(text, pos, cur_pos - pos), value], cur_pos]
        else
          return [false, null, pos]
        endif
      endif
      value ..= char
      cur_pos += 1
    endwhile
    return [true, [strcharpart(text, pos), value], len]
  })
enddef

# Matches an exact literal token string.
export def Token(token: string): Parser
  var token_len = strchars(token)
  return Parser.new((text: string, pos: number): list<any> => {
    var value = strcharpart(text, pos, token_len)
    if value ==# token
      return [true, token, pos + token_len]
    endif
    return [false, null, pos]
  })
enddef

# Matches one or more repetitions of the inner parser.
export def Many(parser: Parser): Parser
  var Fn = parser.Parse
  return Parser.new((text: string, pos: number): list<any> => {
    var cur_pos = pos
    var values: list<any> = []
    var len = strchars(text)
    while cur_pos < len
      var parsed: list<any> = Fn(text, cur_pos)
      if parsed[0]
        add(values, parsed[1])
        cur_pos = parsed[2]
      else
        break
      endif
    endwhile
    return len(values) > 0 ? [true, values, cur_pos] : [false, null, cur_pos]
  })
enddef

# Tries each parser in order, returning the first success.
export def Or(...parsers: list<Parser>): Parser
  var Fns: list<func(string, number): list<any>> = []
  for _p in parsers
    add(Fns, _p.Parse)
  endfor
  return Parser.new((text: string, pos: number): list<any> => {
    for Fn in Fns
      var parsed: list<any> = Fn(text, pos)
      if parsed[0]
        return parsed
      endif
    endfor
    return [false, null, pos]
  })
enddef

# Runs all parsers in sequence; all must succeed.
export def Seq(...parsers: list<Parser>): Parser
  var Fns: list<func(string, number): list<any>> = []
  for _p in parsers
    add(Fns, _p.Parse)
  endfor
  return Parser.new((text: string, pos: number): list<any> => {
    var cur_pos = pos
    var values: list<any> = []
    for Fn in Fns
      var parsed: list<any> = Fn(text, cur_pos)
      if !parsed[0]
        return [false, null, pos]
      endif
      add(values, parsed[1])
      cur_pos = parsed[2]
    endfor
    return [true, values, cur_pos]
  })
enddef

# Defers parser construction until first use (supports forward/circular references).
export def Lazy(Callback: func(): any): Parser
  var Fn: func(string, number): list<any>
  var initialized = false
  return Parser.new((text: string, pos: number): list<any> => {
    if !initialized
      var p: Parser = Callback()
      Fn = p.Parse
      initialized = true
    endif
    return Fn(text, pos)
  })
enddef

# Matches text against a regex pattern anchored to the current position.
export def Pattern(pattern: string): Parser
  var pat = pattern[0] ==# '^' ? pattern : '^' .. pattern
  return Parser.new((text: string, pos: number): list<any> => {
    var substr = strcharpart(text, pos)
    var matches = matchstrpos(substr, pat, 0, 1)
    if matches[0] !=# ''
      return [true, matches[0], pos + matches[2]]
    endif
    return [false, null, pos]
  })
enddef

# Transforms the parsed value through a callback on success.
export def Map(parser: Parser, Callback: func(any): any): Parser
  var Fn = parser.Parse
  return Parser.new((text: string, pos: number): list<any> => {
    var parsed: list<any> = Fn(text, pos)
    if parsed[0]
      return [true, Callback(parsed[1]), parsed[2]]
    endif
    return parsed
  })
enddef

# Always succeeds; returns null value when the inner parser fails.
export def Option_(parser: Parser): Parser
  var Fn = parser.Parse
  return Parser.new((text: string, pos: number): list<any> => {
    var parsed: list<any> = Fn(text, pos)
    return parsed[0] ? parsed : [true, null, pos]
  })
enddef

# Backward-compatible import function for legacy VimScript callers.
export def Import(): dict<any>
  return {
    skip: Skip,
    token: Token,
    many: Many,
    or: Or,
    seq: Seq,
    lazy: Lazy,
    pattern: Pattern,
    map: Map,
    option: Option_,
  }
enddef
