vim9script

import autoload 'vsnip/snippet.vim' as SnippetMod

var TextEdit: dict<any> = vital#vsnip#import('VS.LSP.TextEdit')
var Position: dict<any> = vital#vsnip#import('VS.LSP.Position')
var Diff: dict<any> = vital#vsnip#import('VS.LSP.Diff')

export class Session
  var bufnr: number
  var buffer: list<any>
  var timer_id: number
  var changedtick: number
  var snippet: any
  var tabstop: number
  var changenr: number
  var changenrs: dict<any>

  def new(bufnr_: number, position: dict<any>, text: string)
    this.bufnr = bufnr_
    this.buffer = getbufline(bufnr_, '^', '$')
    this.timer_id = -1
    this.changedtick = getbufvar(bufnr_, 'changedtick', 0)
    this.snippet = SnippetMod.New(position, vsnip#indent#adjust_snippet_body(getline('.'), text))
    this.tabstop = -1
    this.changenr = changenr()
    this.changenrs = {}
  enddef

  def expand()
    TextEdit.apply(this.bufnr, [{
      range: {
        start: this.snippet.position,
        end: this.snippet.position,
      },
      newText: this.snippet.text(),
    }])
    this.store(changenr())
  enddef

  def merge(other_session: Session)
    TextEdit.apply(this.bufnr, this.snippet.sync())
    this.store(this.changenr)

    other_session.expand()
    this.snippet.merge(this.tabstop, other_session.snippet)
    this.snippet.insert(deepcopy(other_session.snippet.position), other_session.snippet.children)
    TextEdit.apply(this.bufnr, this.snippet.sync())
    this.store(changenr())
  enddef

  def jumpable(direction: number): bool
    if direction == 1
      return !empty(this.snippet.get_next_jump_point(this.tabstop))
    else
      return !empty(this.snippet.get_prev_jump_point(this.tabstop))
    endif
  enddef

  def jump(direction: number)
    this.flush_changes()

    var jump_point: any
    if direction == 1
      jump_point = this.snippet.get_next_jump_point(this.tabstop)
    else
      jump_point = this.snippet.get_prev_jump_point(this.tabstop)
    endif

    if empty(jump_point)
      return
    endif

    this.tabstop = jump_point.placeholder.id

    if len(jump_point.placeholder.choice) > 0
      this.choice(jump_point)
    elseif jump_point.range.start.character != jump_point.range.end.character
      this.select(jump_point)
    else
      this.move(jump_point)
    endif

    doautocmd <nomodeline> User vsnip#jump
  enddef

  def choice(jump_point: dict<any>)
    this.move(jump_point)

    var jp = jump_point
    timer_start(g:vsnip_choice_delay, (_) => {
      if mode()[0] ==# 'i'
        var pos = Position.lsp_to_vim('%', jp.range.start)
        complete(pos[1], mapnew(copy(jp.placeholder.choice), (k, v) => {
          return {word: v.escaped, abbr: v.escaped, menu: '[vsnip]', kind: 'Choice'}
        }))
      endif
    })
  enddef

  def select(jump_point: dict<any>)
    var start_pos = Position.lsp_to_vim('%', jump_point.range.start)
    var end_pos = Position.lsp_to_vim('%', jump_point.range.end)

    var cmd = ''
    cmd ..= "\<Cmd>set virtualedit=onemore\<CR>"
    cmd ..= mode()[0] ==# 'i' ? "\<Esc>" : ''
    cmd ..= printf("\<Cmd>call cursor(%s, %s)\<CR>", start_pos[0], start_pos[1])
    cmd ..= 'v'
    cmd ..= printf("\<Cmd>call cursor(%s, %s)\<CR>%s", end_pos[0], end_pos[1], &selection ==# 'exclusive' ? '' : 'h')
    if get(g:, 'vsnip_test_mode', false)
      cmd ..= "\<Esc>gv"
    endif
    cmd ..= printf("\<Cmd>set virtualedit=%s\<CR>", &virtualedit)
    cmd ..= "\<C-g>"
    feedkeys(cmd, 'ni')
  enddef

  def move(jump_point: dict<any>)
    var pos = Position.lsp_to_vim('%', jump_point.range.end)

    cursor(pos)

    if mode()[0] ==# 'n'
      if pos[1] != getcurpos()[2]
        feedkeys('a', 'ni')
      else
        feedkeys('i', 'ni')
      endif
    endif
  enddef

  def refresh()
    this.buffer = getbufline(this.bufnr, '^', '$')
    this.changedtick = getbufvar(this.bufnr, 'changedtick', 0)
  enddef

  def on_insert_leave()
    this.flush_changes()
  enddef

  def on_text_changed()
    if this.bufnr != bufnr('%')
      vsnip#deactivate()
      return
    endif

    var curr_changenr = changenr()

    if this.changenr != curr_changenr
      this.store(this.changenr)
      if has_key(this.changenrs, curr_changenr)
        this.tabstop = this.changenrs[curr_changenr].tabstop
        this.snippet = this.changenrs[curr_changenr].snippet
        this.changenr = curr_changenr
        this.buffer = getbufline(this.bufnr, '^', '$')
        return
      endif
    endif

    if g:vsnip_sync_delay == 0
      this.flush_changes()
    elseif g:vsnip_sync_delay > 0
      timer_stop(this.timer_id)
      this.timer_id = timer_start(g:vsnip_sync_delay, (_) => this.flush_changes(), {repeat: 1})
    endif
  enddef

  def flush_changes()
    var curr_changedtick = getbufvar(this.bufnr, 'changedtick', 0)
    if this.changedtick == curr_changedtick
      return
    endif
    this.changedtick = curr_changedtick

    var buf = getbufline(this.bufnr, '^', '$')
    var diff = Diff.compute(this.buffer, buf)
    this.buffer = buf
    if diff.rangeLength == 0 && diff.text ==# ''
      return
    endif

    if this.snippet.follow(this.tabstop, diff)
      try
        var text_edits = this.snippet.sync()
        if len(text_edits) > 0
          undojoin | call TextEdit.apply(this.bufnr, text_edits)
        endif
        this.refresh()
      catch /.*/
        vsnip#deactivate()
      endtry
    else
      vsnip#deactivate()
    endif
  enddef

  def store(nr: number)
    this.changenrs[nr] = {
      tabstop: this.tabstop,
      snippet: deepcopy(this.snippet),
    }
    this.changenr = nr
  enddef
endclass

# Backward-compatible import function used by legacy callers
export def import(): dict<any>
  return {new: New}
enddef

# Primary vim9 API
export def New(bufnr_: number, position: dict<any>, text: string): Session
  return Session.new(bufnr_, position, text)
enddef
