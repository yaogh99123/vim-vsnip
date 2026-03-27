vim9script

export class TransformNode
  var type: string
  var regex: any
  var replacements: list<any>
  var options: list<any>
  var is_noop: bool

  def new(ast: any)
    var transform: dict<any> = empty(ast) ? {} : ast
    this.type = 'transform'
    this.regex = get(transform, 'regex', null)
    this.replacements = get(transform, 'format', [])
    this.options = get(transform, 'option', [])
    this.is_noop = this.regex == null
  enddef

  def text(input_text: string): string
    if empty(input_text) || this.is_noop
      return input_text
    endif

    if (this.regex as dict<any>).pattern !=# '(.*)'
      # TODO: fully support regex
      return input_text
    endif

    var result = ''
    for replacement in this.replacements
      if replacement.type ==# 'format'
        if replacement.modifier ==# '/capitalize'
          result ..= Capitalize(input_text)
        elseif replacement.modifier ==# '/downcase'
          result ..= Downcase(input_text)
        elseif replacement.modifier ==# '/upcase'
          result ..= Upcase(input_text)
        elseif replacement.modifier ==# '/camelcase'
          result ..= Camelcase(input_text)
        elseif replacement.modifier ==# '/pascalcase'
          result ..= Capitalize(Camelcase(input_text))
        endif
      elseif replacement.type ==# 'text'
        result ..= replacement.escaped
      endif
    endfor

    return result
  enddef

  def to_string(): string
    if this.is_noop
      return ''
    endif

    return printf('%s(regex=%s, total_replacements=%s, options=%s)',
      this.type,
      get(this.regex as dict<any>, 'pattern', ''),
      len(this.replacements),
      join(this.options, ''),
    )
  enddef
endclass

export def New(ast: any): TransformNode
  return TransformNode.new(ast)
enddef

def Upcase(word: string): string
  return toupper(word)
enddef

def Downcase(word: string): string
  return tolower(word)
enddef

def Capitalize(word: string): string
  return Upcase(strpart(word, 0, 1)) .. strpart(word, 1)
enddef

# @see https://github.com/tpope/vim-abolish/blob/3f0c8faa/plugin/abolish.vim#L111-L118
def Camelcase(word: string): string
  var w = substitute(word, '-', '_', 'g')
  if w !~# '_' && w =~# '\l'
    return substitute(w, '^.', '\l&', '')
  else
    return substitute(w, '\C\(_\)\=\(.\)', '\=submatch(1)==""?tolower(submatch(2)) : toupper(submatch(2))', 'g')
  endif
enddef
