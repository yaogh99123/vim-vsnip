vim9script

const max_tabstop: number = 1000000
var Position: dict<any> = vital#vsnip#import('VS.LSP.Position')

export class SnippetNode
  var type: string
  var position: dict<any>
  var before_text: string
  var children: list<any>

  def new(pos: dict<any>, text: string)
    var lpos = Position.lsp_to_vim('%', pos)
    this.type = 'snippet'
    this.position = pos
    this.before_text = getline(lpos[0])[0 : lpos[1] - 2]
    this.children = vsnip#snippet#node#create_from_ast(
      vsnip#snippet#parser#Parse(text)
    )
    this.init()
    this.sync()
  enddef

  def init()
    var group: dict<any> = {}
    var variable_placeholder: dict<any> = {}
    var has_final_tabstop = false

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder'
        if !has_key(group, context.node.id)
          group[context.node.id] = context.node
        else
          context.node.follower = true
        endif
        if context.node.is_final
          has_final_tabstop = true
        endif
      elseif context.node.type ==# 'variable'
        if context.node.unknown
          context.node.type = 'placeholder'
          context.node.choice = []
          if !has_key(variable_placeholder, context.node.name)
            variable_placeholder[context.node.name] = max_tabstop - (len(variable_placeholder) + 1)
            context.node.id = variable_placeholder[context.node.name]
            context.node.follower = false
            context.node.children = empty(context.node.children) ? [vsnip#snippet#node#create_text(context.node.name)] : context.node.children
            group[context.node.id] = context.node
          else
            context.node.id = variable_placeholder[context.node.name]
            context.node.follower = true
            context.node.children = [vsnip#snippet#node#create_text(group[context.node.id].text())]
          endif
        else
          var txt: any = context.node.resolve(context)
          txt = txt is v:null ? context.text : txt
          var idx = index(context.parent.children, context.node)
          remove(context.parent.children, idx)
          insert(context.parent.children, vsnip#snippet#node#create_text(txt), idx)
        endif
      endif
      return false
    })

    if !has_final_tabstop && g:vsnip_append_final_tabstop
      this.children += [vsnip#snippet#node#create_from_ast({
        'type': 'placeholder',
        'id': 0,
        'choice': [],
      })]
    endif
  enddef

  def follow(current_tabstop: number, diff: dict<any>): bool
    if !this.is_followable(current_tabstop, diff)
      return false
    endif

    diff.range = [
      this.position_to_offset(diff.range.start),
      this.position_to_offset(diff.range.end),
    ]

    var is_target_context_fixed = false
    var target_context: any = null
    var contexts: list<any> = []

    this.traverse((context: dict<any>): any => {
      if diff.range[1] < context.range[0]
        return true
      endif
      if context.node.type !=# 'text'
        return false
      endif

      var included = false
      included = included || context.range[0] <= diff.range[0] && diff.range[0] < context.range[1]
      included = included || context.range[0] < diff.range[1] && diff.range[1] <= context.range[1]
      included = included || diff.range[0] <= context.range[0] && context.range[1] <= diff.range[1]
      if included
        if !is_target_context_fixed && (empty(target_context) && context.parent.type ==# 'placeholder' || get(context.parent, 'id', -1) == current_tabstop)
          is_target_context_fixed = get(context.parent, 'id', -1) == current_tabstop
          target_context = context
        endif
        add(contexts, context)
      endif
      return false
    })

    if empty(contexts)
      return false
    endif

    target_context = empty(target_context) ? contexts[-1] : target_context

    var diff_text = diff.text
    for ctx in contexts
      var diff_range = [max([diff.range[0], ctx.range[0]]), min([diff.range[1], ctx.range[1]])]
      var start = diff_range[0] - ctx.range[0]
      var end_ = diff_range[1] - ctx.range[0]

      var new_text = strcharpart(ctx.text, 0, start)
      if target_context is ctx
        new_text ..= diff_text
      endif
      new_text ..= strcharpart(ctx.text, end_, ctx.length - end_)

      ctx.node.value = new_text
    endfor

    var squashed: list<any> = []
    for ctx in contexts
      var squash_targets = ctx.parents + [ctx.node]
      for i in range(len(squash_targets) - 1, 1, -1)
        var node = squash_targets[i]
        var parent = squash_targets[i - 1]

        var should_squash = false
        should_squash = should_squash || get(node, 'follower', false)
        should_squash = should_squash || get(parent, 'id', -1) == current_tabstop
        should_squash = should_squash || (ctx isnot target_context) && strlen(node.text()) == 0
        if should_squash && index(squashed, node) == -1
          var idx = index(parent.children, node)
          remove(parent.children, idx)
          insert(parent.children, vsnip#snippet#node#create_text(node.text()), idx)
          add(squashed, node)
        endif
      endfor
    endfor

    return true
  enddef

  def sync(): list<any>
    var new_texts: dict<any> = {}
    var targets: list<any> = []

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder'
        if !has_key(new_texts, context.node.id)
          new_texts[context.node.id] = context.text
        else
          if new_texts[context.node.id] !=# context.text
            add(targets, {
              range: context.range,
              node: context.node,
              new_text: context.node.transform.text(new_texts[context.node.id]),
            })
          endif
        endif
      endif
      return false
    })

    var text_edits: list<any> = []
    for target in targets
      add(text_edits, {
        node: target.node,
        range: {
          start: this.offset_to_position(target.range[0]),
          end: this.offset_to_position(target.range[1]),
        },
        newText: target.new_text
      })
    endfor

    for text_edit in text_edits
      text_edit.node.children = [vsnip#snippet#node#create_text(text_edit.newText)]
    endfor

    return text_edits
  enddef

  def range(): dict<any>
    return {
      start: this.offset_to_position(0),
      end: this.offset_to_position(strchars(this.text())),
    }
  enddef

  def text(): string
    return join(mapnew(this.children, (_, n) => n.text()), '')
  enddef

  def is_followable(current_tabstop: number, diff: dict<any>): bool
    if g:['vsnip#DeactivateOn']['OutsideOfSnippet'] == g:vsnip_deactivate_on
      return vsnip#range#cover(this.range(), diff.range)
    elseif g:['vsnip#DeactivateOn']['OutsideOfCurrentTabstop'] == g:vsnip_deactivate_on
      var ctx = this.get_placeholder_context_by_tabstop(current_tabstop)
      if empty(ctx)
        return false
      endif
      return vsnip#range#cover({
        start: this.offset_to_position(ctx.range[0]),
        end: this.offset_to_position(ctx.range[1]),
      }, diff.range)
    endif
    return false
  enddef

  def get_placeholder_nodes(): list<any>
    var nodes: list<any> = []

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder'
        add(nodes, context.node)
      endif
      return false
    })

    return sort(nodes, (a, b) => a.id - b.id)
  enddef

  def get_placeholder_context_by_tabstop(current_tabstop: number): any
    var result: any = null

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder' && context.node.id == current_tabstop
        result = context
        return true
      endif
      return false
    })

    return result
  enddef

  def get_next_jump_point(current_tabstop: number): any
    var result: any = null

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder' && current_tabstop < context.node.id
        if !empty(result) && result.node.id <= context.node.id
          return false
        endif
        result = copy(context)
      endif
      return false
    })

    if empty(result)
      return {}
    endif

    return {
      placeholder: result.node,
      range: {
        start: this.offset_to_position(result.range[0]),
        end: this.offset_to_position(result.range[1]),
      }
    }
  enddef

  def get_prev_jump_point(current_tabstop: number): any
    var result: any = null

    this.traverse((context: dict<any>): any => {
      if context.node.type ==# 'placeholder' && current_tabstop > context.node.id
        if !empty(result) && result.node.id >= context.node.id
          return false
        endif
        result = copy(context)
      endif
      return false
    })

    if empty(result)
      return {}
    endif

    return {
      placeholder: result.node,
      range: {
        start: this.offset_to_position(result.range[0]),
        end: this.offset_to_position(result.range[1]),
      }
    }
  enddef

  def normalize()
    var prev_context: any = null

    this.traverse((context: dict<any>): any => {
      if !empty(prev_context)
        if prev_context.node.type ==# 'text' && context.node.type ==# 'text' && prev_context.parent is context.parent
          context.node.value = prev_context.node.value .. context.node.value
          remove(prev_context.parent.children, index(prev_context.parent.children, prev_context.node))
        endif
      endif
      prev_context = copy(context)
      return false
    })
  enddef

  def merge(tabstop: number, snippet: SnippetNode)
    var offset = 1
    var tabstop_map: dict<any> = {}
    var tail: any = null
    for node in snippet.get_placeholder_nodes()
      if !has_key(tabstop_map, node.id)
        tabstop_map[node.id] = tabstop + offset
      endif
      node.id = tabstop_map[node.id]
      offset += 1
      tail = node
    endfor
    if empty(tabstop_map)
      return
    endif

    offset = 1
    tabstop_map = {}
    for node in this.get_placeholder_nodes()
      if node.id > tabstop
        if !has_key(tabstop_map, node.id)
          tabstop_map[node.id] = tail.id + offset
        endif
        node.id = tabstop_map[node.id]
        offset += 1
      endif
    endfor
  enddef

  def insert(pos: dict<any>, nodes_to_insert: list<any>)
    var offset_ = this.position_to_offset(pos)

    var result: any = null

    this.traverse((context: dict<any>): any => {
      if context.range[0] <= offset_ && offset_ <= context.range[1] && context.node.type ==# 'text'
        if empty(result) || result.depth <= context.depth
          result = copy(context)
        endif
      endif
      return false
    })

    if empty(result)
      return
    endif

    var idx = index(result.parent.children, result.node)
    remove(result.parent.children, idx)

    var nodes_rev = reverse(copy(nodes_to_insert))
    if result.node.value !=# ''
      var off = offset_ - result.range[0]
      var before = vsnip#snippet#node#create_text(strcharpart(result.node.value, 0, off))
      var after = vsnip#snippet#node#create_text(strcharpart(result.node.value, off, strchars(result.node.value) - off))
      nodes_rev = [after] + nodes_rev + [before]
    endif

    for node in nodes_rev
      insert(result.parent.children, node, idx)
    endfor

    this.normalize()
  enddef

  def offset_to_position(offset: number): dict<any>
    var lines = split(strcharpart(this.text(), 0, offset), "\n", true)
    return {
      line: this.position.line + len(lines) - 1,
      character: strchars(lines[-1]) + (len(lines) == 1 ? this.position.character : 0),
    }
  enddef

  def position_to_offset(position: dict<any>): number
    var line = position.line - this.position.line
    var char = position.character - (line == 0 ? this.position.character : 0)
    var lines = split(this.text(), "\n", true)[0 : line]
    lines[-1] = strcharpart(lines[-1], 0, char)
    return strchars(join(lines, "\n"))
  enddef

  def traverse(Callback: func(dict<any>): any)
    var state: dict<any> = {
      offset: 0,
      before_text: this.before_text,
    }
    var context: dict<any> = {
      depth: 0,
      parent: null,
      parents: [],
    }
    Traverse(this, Callback, state, context)
  enddef

  def debug()
    echomsg 'snippet.text()'
    for line in split(this.text(), "\n", true)
      echomsg string(line)
    endfor
    echomsg '-----'

    this.traverse((context: dict<any>): any => {
      echomsg repeat('    ', context.depth - 1) .. context.node.to_string()
      return false
    })
    echomsg ' '
  enddef
endclass

# Recursive traversal helper
def Traverse(node: any, Callback: func(dict<any>): any, state: dict<any>, context: dict<any>): bool
  var text = ''
  var length = 0
  if node.type !=# 'snippet'
    text = node.text()
    length = strchars(text)
    if Callback({
      node: node,
      text: text,
      length: length,
      parent: context.parent,
      parents: context.parents,
      depth: context.depth,
      offset: state.offset,
      before_text: state.before_text,
      range: [state.offset, state.offset + length],
    })
      return true
    endif
  endif

  if len(node.children) > 0
    var next_context: dict<any> = {
      parent: node,
      parents: context.parents + [node],
      depth: len(context.parents) + 1,
    }
    for child in copy(node.children)
      if Traverse(child, Callback, state, next_context)
        return true
      endif
    endfor
  else
    state.before_text ..= text
    state.offset += length
  endif
  return false
enddef

# Backward-compatible import function used by legacy callers and specs
export def import(): dict<any>
  return {new: New}
enddef

# Primary vim9 API
export def New(pos: dict<any>, text: string): SnippetNode
  return SnippetNode.new(pos, text)
enddef
