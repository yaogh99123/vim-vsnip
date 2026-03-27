vim9script

const max_tabstop: number = 1000000
var uid: number = 0

export class PlaceholderNode
  var uid: number
  var type: string
  var id: number
  var is_final: bool
  var follower: bool
  var choice: list<any>
  var children: list<any>
  var transform: any

  def new(ast: dict<any>)
    uid += 1
    this.uid = uid
    this.type = 'placeholder'
    this.id = ast.id
    this.is_final = ast.id == 0
    this.follower = false
    this.choice = get(ast, 'choice', [])
    this.children = vsnip#snippet#node#create_from_ast(get(ast, 'children', []))
    this.transform = vsnip#snippet#node#create_transform(get(ast, 'transform', null))

    if this.is_final
      this.id = max_tabstop
    endif

    if len(this.children) == 0
      this.children = [vsnip#snippet#node#create_text('')]
    endif
  enddef

  def text(): string
    return join(mapnew(this.children, (_, n) => n.text()), '')
  enddef

  def to_string(): string
    return printf('%s(id=%s, follower=%s, choise=%s)',
      this.type,
      this.id,
      this.follower ? 'true' : 'false',
      this.choice
    )
  enddef
endclass

export def New(ast: dict<any>): PlaceholderNode
  return PlaceholderNode.new(ast)
enddef
