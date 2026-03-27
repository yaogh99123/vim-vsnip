vim9script

var variables: dict<any> = {}

# vsnip#variable#register
export def Register(name: string, Func: func, ...args: list<any>): void
  var option = get(args, 0, {})
  variables[name] = {
    func: Func,
    once: get(option, 'once', false)
  }
enddef

# vsnip#variable#get
export def Get(name: string): any
  return get(variables, name, null)
enddef

# Register built-in variables.
# @see https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables

def TM_SELECTED_TEXT(context: dict<any>): any
  var selected_text = vsnip#selected_text()
  if empty(selected_text)
    return null
  endif
  return vsnip#indent#trim_base_indent(selected_text)
enddef
Register('TM_SELECTED_TEXT', TM_SELECTED_TEXT)

def TM_CURRENT_LINE(context: dict<any>): any
  return getline('.')
enddef
Register('TM_CURRENT_LINE', TM_CURRENT_LINE)

def TM_CURRENT_WORD(context: dict<any>): any
  return null
enddef
Register('TM_CURRENT_WORD', TM_CURRENT_WORD)

def TM_LINE_INDEX(context: dict<any>): any
  return line('.') - 1
enddef
Register('TM_LINE_INDEX', TM_LINE_INDEX)

def TM_LINE_NUMBER(context: dict<any>): any
  return line('.')
enddef
Register('TM_LINE_NUMBER', TM_LINE_NUMBER)

def TM_FILENAME(context: dict<any>): any
  return expand('%:p:t')
enddef
Register('TM_FILENAME', TM_FILENAME)

def TM_FILENAME_BASE(context: dict<any>): any
  return substitute(expand('%:p:t'), '^\@<!\..*$', '', '')
enddef
Register('TM_FILENAME_BASE', TM_FILENAME_BASE)

def TM_DIRECTORY(context: dict<any>): any
  return expand('%:p:h:t')
enddef
Register('TM_DIRECTORY', TM_DIRECTORY)

def TM_FILEPATH(context: dict<any>): any
  return expand('%:p')
enddef
Register('TM_FILEPATH', TM_FILEPATH)

def RELATIVE_FILEPATH(context: dict<any>): any
  return expand('%')
enddef
Register('RELATIVE_FILEPATH', RELATIVE_FILEPATH)

def CLIPBOARD(context: dict<any>): any
  var clipboard = getreg(v:register)
  if empty(clipboard)
    return null
  endif
  return vsnip#indent#trim_base_indent(clipboard)
enddef
Register('CLIPBOARD', CLIPBOARD)

def WORKSPACE_NAME(context: dict<any>): any
  return null
enddef
Register('WORKSPACE_NAME', WORKSPACE_NAME)

def CURRENT_YEAR(context: dict<any>): any
  return strftime('%Y')
enddef
Register('CURRENT_YEAR', CURRENT_YEAR)

def CURRENT_YEAR_SHORT(context: dict<any>): any
  return strftime('%y')
enddef
Register('CURRENT_YEAR_SHORT', CURRENT_YEAR_SHORT)

def CURRENT_MONTH(context: dict<any>): any
  return strftime('%m')
enddef
Register('CURRENT_MONTH', CURRENT_MONTH)

def CURRENT_MONTH_NAME(context: dict<any>): any
  return strftime('%B')
enddef
Register('CURRENT_MONTH_NAME', CURRENT_MONTH_NAME)

def CURRENT_MONTH_NAME_SHORT(context: dict<any>): any
  return strftime('%b')
enddef
Register('CURRENT_MONTH_NAME_SHORT', CURRENT_MONTH_NAME_SHORT)

def CURRENT_DATE(context: dict<any>): any
  return strftime('%d')
enddef
Register('CURRENT_DATE', CURRENT_DATE)

def CURRENT_DAY_NAME(context: dict<any>): any
  return strftime('%A')
enddef
Register('CURRENT_DAY_NAME', CURRENT_DAY_NAME)

def CURRENT_DAY_NAME_SHORT(context: dict<any>): any
  return strftime('%a')
enddef
Register('CURRENT_DAY_NAME_SHORT', CURRENT_DAY_NAME_SHORT)

def CURRENT_HOUR(context: dict<any>): any
  return strftime('%H')
enddef
Register('CURRENT_HOUR', CURRENT_HOUR)

def CURRENT_MINUTE(context: dict<any>): any
  return strftime('%M')
enddef
Register('CURRENT_MINUTE', CURRENT_MINUTE)

def CURRENT_SECOND(context: dict<any>): any
  return strftime('%S')
enddef
Register('CURRENT_SECOND', CURRENT_SECOND)

def CURRENT_SECONDS_UNIX(context: dict<any>): any
  return localtime()
enddef
Register('CURRENT_SECONDS_UNIX', CURRENT_SECONDS_UNIX)

def BLOCK_COMMENT_START(context: dict<any>): any
  return split(&commentstring, '%s')[0]
enddef
Register('BLOCK_COMMENT_START', BLOCK_COMMENT_START)

def BLOCK_COMMENT_END(context: dict<any>): any
  var chars = split(&commentstring, '%s')
  var comment = len(chars) > 1 ? chars[1] : chars[0]
  return trim(comment)
enddef
Register('BLOCK_COMMENT_END', BLOCK_COMMENT_END)

def LINE_COMMENT(context: dict<any>): any
  var comment = &commentstring =~# '^/\*' ? '//' : substitute(&commentstring, '%s', '', 'g')
  return trim(comment)
enddef
Register('LINE_COMMENT', LINE_COMMENT)

def VIM(context: dict<any>): any
  var script = join(mapnew(context.node.children, (_, n) => n.text()), '')
  try
    return eval(script)
  catch /.*/
  endtry
  return null
enddef
Register('VIM', VIM)

def VSNIP_CAMELCASE_FILENAME(context: dict<any>): any
  var basename = substitute(expand('%:p:t'), '^\@<!\..*$', '', '')
  return substitute(basename, '\(\%(\<\l\+\)\%(_\)\@=\)\|_\(\l\)', '\u\1\2', 'g')
enddef
Register('VSNIP_CAMELCASE_FILENAME', VSNIP_CAMELCASE_FILENAME)
