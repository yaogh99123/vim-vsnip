vim9script

# vsnip#indent#get_one_indent
export def get_one_indent(): string
  return !&expandtab ? "\t" : repeat(' ', &shiftwidth ? &shiftwidth : &tabstop)
enddef

# vsnip#indent#get_base_indent
export def get_base_indent(text: string): string
  return matchstr(text, '^\s*')
enddef

# vsnip#indent#adjust_snippet_body
export def adjust_snippet_body(line: string, text: string): string
  var one_indent = get_one_indent()
  var base_indent = get_base_indent(line)
  var result = text
  if one_indent != "\t"
    while match(result, "\\%(^\\|\n\\)\\s*\\zs\\t") != -1
      result = substitute(result, "\\%(^\\|\n\\)\\s*\\zs\\t", one_indent, 'g') # convert \t as one indent
    endwhile
  endif
  result = substitute(result, "\n\\zs", base_indent, 'g') # add base_indent for all lines
  result = substitute(result, "\n\\s*\\ze\n", "\n", 'g') # remove empty line's indent
  return result
enddef

# vsnip#indent#trim_base_indent
export def trim_base_indent(text: string): string
  var is_char_wise = match(text, "\n$") == -1
  var result = substitute(text, "\n$", '', 'g')

  var is_first_line = true
  var base_indent = ''
  for line in split(result, "\n", true)
    # Ignore the first line when the text created as char-wise.
    if is_char_wise && is_first_line
      is_first_line = false
      continue
    endif

    # Ignore empty line.
    if line == ''
      continue
    endif

    # Detect most minimum base indent.
    var line_indent = matchstr(line, '^\s*')
    if base_indent == '' || strlen(line_indent) < strlen(base_indent)
      base_indent = line_indent
    endif
  endfor
  return substitute(result, "\\%(^\\|\n\\)\\zs\\V" .. base_indent, '', 'g')
enddef
