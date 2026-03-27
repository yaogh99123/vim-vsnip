vim9script

import autoload 'vsnip/snippet/node/placeholder.vim' as PlaceholderMod
import autoload 'vsnip/snippet/node/variable.vim' as VariableMod
import autoload 'vsnip/snippet/node/text.vim' as TextMod
import autoload 'vsnip/snippet/node/transform.vim' as TransformMod

export def create_from_ast(ast: any): any
  if type(ast) == v:t_list
    return mapnew(ast, (_, v) => create_from_ast(v))
  endif

  if ast.type ==# 'placeholder'
    return PlaceholderMod.New(ast)
  endif
  if ast.type ==# 'variable'
    return VariableMod.New(ast)
  endif
  if ast.type ==# 'text'
    return TextMod.New(ast)
  endif

  throw 'vsnip: invalid node type'
enddef

export def create_text(text: string): any
  return TextMod.New({
    type: 'text',
    raw: text,
    escaped: text,
  })
enddef

export def create_transform(transform: any): any
  return TransformMod.New(transform)
enddef
