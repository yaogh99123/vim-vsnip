vim9script

# @see https://github.com/Microsoft/language-server-protocol/blob/master/snippetSyntax.md

import autoload 'vsnip/parser/combinator.vim' as C

export def Parse(text: string): list<any>
  if strlen(text) == 0
    return []
  endif

  var parsed: list<any> = parser.Parse(text, 0)
  if !parsed[0]
    throw json_encode({text: text, result: parsed})
  endif
  return parsed[1]
enddef

def TextParser(stop: list<string>, escape_: list<string>): C.Parser
  return C.Map(C.Skip(stop, escape_), (value: any): any => {
    var r: dict<any> = {type: 'text', raw: value[0], escaped: value[1]}
    return r
  })
enddef

# primitives
var dollar: C.Parser = C.Token('$')
var open: C.Parser   = C.Token('{')
var close: C.Parser  = C.Token('}')
var colon: C.Parser  = C.Token(':')
var slash: C.Parser  = C.Token('/')
var comma: C.Parser  = C.Token(',')
var pipe: C.Parser   = C.Token('|')
var varname: C.Parser = C.Pattern('[_[:alpha:]]\w*')
var int_: C.Parser = C.Map(C.Pattern('\d\+'), (value: any): any => str2nr(value))
var regex_: C.Parser = C.Map(TextParser(['/'], []), (value: any): any => {
  var r: dict<any> = {type: 'regex', pattern: value.raw}
  return r
})

# Forward declarations for mutually recursive parsers
var choice: C.Parser = C.Token('')
var variable: C.Parser = C.Token('')
var tabstop: C.Parser = C.Token('')
var placeholder: C.Parser = C.Token('')

# any (without text) - uses Lazy to defer resolution of forward-declared parsers
var any_parser: C.Parser = C.Or(
  C.Lazy((): any => choice),
  C.Lazy((): any => variable),
  C.Lazy((): any => tabstop),
  C.Lazy((): any => placeholder),
)

# format
var format1: C.Parser = C.Map(C.Seq(dollar, int_), (value: any): any => {
  var r: dict<any> = {type: 'format', id: value[1]}
  return r
})
var format2: C.Parser = C.Map(C.Seq(dollar, open, int_, close), (value: any): any => {
  var r: dict<any> = {type: 'format', id: value[2]}
  return r
})
var format3: C.Parser = C.Map(
  C.Seq(
    dollar,
    open,
    int_,
    colon,
    C.Or(
      C.Token('/upcase'),
      C.Token('/downcase'),
      C.Token('/capitalize'),
      C.Token('/camelcase'),
      C.Token('/pascalcase'),
      C.Token('+if'),
      C.Token('?if:else'),
      C.Token('-else'),
      C.Token('else')
    ),
    close
  ),
  (value: any): any => {
    var r: dict<any> = {type: 'format', id: value[2], modifier: value[4]}
    return r
  }
)
var format: C.Parser = C.Or(format1, format2, format3)

# transform
var transform: C.Parser = C.Map(
  C.Seq(
    slash,
    regex_,
    slash,
    C.Many(C.Or(format, TextParser(['/', '$'], []))),
    slash,
    C.Option_(C.Many(C.Or(C.Token('i'), C.Token('g'))))
  ),
  (value: any): any => {
    var r: dict<any> = {type: 'transform', regex: value[1], format: value[3], option: value[5]}
    return r
  }
)

# variable
var variable1: C.Parser = C.Map(C.Seq(dollar, varname), (value: any): any => {
  var r: dict<any> = {type: 'variable', name: value[1], children: []}
  return r
})
var variable2: C.Parser = C.Map(C.Seq(dollar, open, varname, close), (value: any): any => {
  var r: dict<any> = {type: 'variable', name: value[2], children: []}
  return r
})
var variable3: C.Parser = C.Map(
  C.Seq(
    dollar,
    open,
    varname,
    colon,
    C.Many(C.Or(any_parser, TextParser(['$', '}'], []))),
    close
  ),
  (value: any): any => {
    var r: dict<any> = {type: 'variable', name: value[2], children: value[4]}
    return r
  }
)
var variable4: C.Parser = C.Map(
  C.Seq(dollar, open, varname, transform, close),
  (value: any): any => {
    var r: dict<any> = {type: 'variable', name: value[2], transform: value[3], children: []}
    return r
  }
)
variable = C.Or(variable1, variable2, variable3, variable4)

# placeholder
placeholder = C.Map(
  C.Seq(
    dollar,
    open,
    int_,
    colon,
    C.Many(C.Or(any_parser, TextParser(['$', '}'], []))),
    close
  ),
  (value: any): any => {
    var r: dict<any> = {type: 'placeholder', id: value[2], children: value[4]}
    return r
  }
)

# tabstop
var tabstop1: C.Parser = C.Map(C.Seq(dollar, int_), (value: any): any => {
  var r: dict<any> = {type: 'placeholder', id: value[1], children: []}
  return r
})
var tabstop2: C.Parser = C.Map(
  C.Seq(dollar, open, int_, C.Option_(colon), close),
  (value: any): any => {
    var r: dict<any> = {type: 'placeholder', id: value[2], children: []}
    return r
  }
)
var tabstop3: C.Parser = C.Map(
  C.Seq(dollar, open, int_, transform, close),
  (value: any): any => {
    var r: dict<any> = {type: 'placeholder', id: value[2], children: [], transform: value[3]}
    return r
  }
)
tabstop = C.Or(tabstop1, tabstop2, tabstop3)

# choice
choice = C.Map(
  C.Seq(
    dollar,
    open,
    int_,
    pipe,
    C.Many(
      C.Map(
        C.Seq(TextParser([',', '|'], []), C.Option_(comma)),
        (value: any): any => value[0]
      )
    ),
    pipe,
    close
  ),
  (value: any): any => {
    var r: dict<any> = {
      type: 'placeholder',
      id: value[2],
      choice: value[4],
      children: [copy(value[4][0])],
    }
    return r
  }
)

# top-level parser
var parser: C.Parser = C.Many(C.Or(any_parser, TextParser(['$'], ['}'])))
