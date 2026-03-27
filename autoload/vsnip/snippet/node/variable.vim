vim9script

var uid: number = 0

export class VariableNode
  var uid: number
  var type: string
  var name: string
  var unknown: bool
  var resolver: any
  var children: list<any>
  var transform: any

  def new(ast: dict<any>)
    uid += 1
    this.uid = uid
    this.type = 'variable'
    this.name = ast.name
    var resolver = vsnip#variable#get(ast.name)
    this.unknown = empty(resolver)
    this.resolver = resolver
    this.children = vsnip#snippet#node#create_from_ast(get(ast, 'children', []))
    this.transform = vsnip#snippet#node#create_transform(get(ast, 'transform', null))
  enddef

  def text(): string
    return this.transform.text(join(mapnew(this.children, (_, n) => n.text()), ''))
  enddef

  def resolve(context: dict<any>): any
    if !this.unknown
      var resolved = this.transform.text(this.resolver.func({node: this}))
      if resolved != null
        # Fix indent when one variable returns multiple lines
        var base_indent = vsnip#indent#get_base_indent(split(context.before_text, "\n", true)[-1])
        return substitute(resolved, "\n\\zs", base_indent, 'g')
      endif
    endif
    return null
  enddef

  def to_string(): string
    return printf('%s(name=%s, unknown=%s, text=%s)',
      this.type,
      this.name,
      this.unknown ? 'true' : 'false',
      this.text()
    )
  enddef
endclass

export def New(ast: dict<any>): VariableNode
  return VariableNode.new(ast)
enddef
