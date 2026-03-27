vim9script

# vsnip#range#cover
export def cover(whole_range: dict<any>, target_range: dict<any>): bool
  var cover = true
  cover = cover && (whole_range.start.line < target_range.start.line || whole_range.start.line == target_range.start.line && whole_range.start.character <= target_range.start.character)
  cover = cover && (target_range.end.line < whole_range.end.line || target_range.end.line == whole_range.end.line && target_range.end.character <= whole_range.end.character)
  return cover
enddef
