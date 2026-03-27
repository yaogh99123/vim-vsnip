vim9script

var uid: number = 0

export class TextNode
  var uid: number
  var type: string
  var value: string
  var children: list<any>

  def new(ast: dict<any>)
    uid += 1
    this.uid = uid
    this.type = 'text'
    this.value = ast.escaped
    this.children = []
  enddef

  def text(): string
    return this.value
  enddef

  def to_string(): string
    return printf('%s(%s)', this.type, this.value)
  enddef
endclass

export def New(ast: dict<any>): TextNode
  return TextNode.new(ast)
enddef
