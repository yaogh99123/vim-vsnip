vim9script

if exists('g:loaded_vsnip')
  finish
endif
g:loaded_vsnip = 1

#
# DeactivateOn constants (defined early for backward compat with user configs)
#
g:['vsnip#DeactivateOn'] = {OutsideOfSnippet: 1, OutsideOfCurrentTabstop: 2}

#
# variable
#
g:vsnip_extra_mapping = get(g:, 'vsnip_extra_mapping', true)
g:vsnip_deactivate_on = get(g:, 'vsnip_deactivate_on', g:['vsnip#DeactivateOn']['OutsideOfCurrentTabstop'])
g:vsnip_snippet_dir = get(g:, 'vsnip_snippet_dir', expand('~/.vsnip'))
g:vsnip_snippet_dirs = get(g:, 'vsnip_snippet_dirs', [])
g:vsnip_sync_delay = get(g:, 'vsnip_sync_delay', 0)
g:vsnip_choice_delay = get(g:, 'vsnip_choice_delay', 500)
g:vsnip_append_final_tabstop = get(g:, 'vsnip_append_final_tabstop', true)
g:vsnip_namespace = get(g:, 'vsnip_namespace', '')
g:vsnip_filetypes = get(g:, 'vsnip_filetypes', {})
g:vsnip_filetypes.typescriptreact = get(g:vsnip_filetypes, 'typescriptreact', ['typescript'])
g:vsnip_filetypes.javascriptreact = get(g:vsnip_filetypes, 'javascriptreact', ['javascript'])
g:vsnip_filetypes.vimspec = get(g:vsnip_filetypes, 'vimspec', ['vim'])

augroup vsnip#silent
  autocmd!
  autocmd User vsnip#expand silent
  autocmd User vsnip#jump silent
augroup END

#
# command
#
command -nargs=* -bang VsnipOpen call <SID>OpenCommand(<bang>0, 'vsplit', <q-args>)
command -nargs=* -bang VsnipOpenEdit call <SID>OpenCommand(<bang>0, 'edit', <q-args>)
command -nargs=* -bang VsnipOpenVsplit call <SID>OpenCommand(<bang>0, 'vsplit', <q-args>)
command -nargs=* -bang VsnipOpenSplit call <SID>OpenCommand(<bang>0, 'split', <q-args>)
def OpenCommand(bang: number, cmd: string, arg: string)
  var candidates = vsnip#source#filetypes(bufnr('%'))
  var idx: number
  if bang
    idx = 1
  else
    idx = inputlist(['Select type: '] + mapnew(candidates, (k, v) => printf('%s: %s', k + 1, v)))
    if idx == 0
      return
    endif
  endif

  var expanded_dir = expand(g:vsnip_snippet_dir)
  if !isdirectory(expanded_dir)
    var prompt = printf('`%s` does not exists, create? y(es)/n(o): ', g:vsnip_snippet_dir)
    if index(['y', 'ye', 'yes'], input(prompt)) >= 0
      mkdir(expanded_dir, 'p')
    else
      return
    endif
  endif

  var ext = arg =~# '-format\s\+snipmate' ? 'snippets' : 'json'

  execute printf('%s %s', cmd, fnameescape(printf('%s/%s.%s',
    resolve(expanded_dir),
    candidates[idx - 1],
    ext
  )))
enddef

command -range -nargs=? -bar VsnipYank call <SID>AddCommand(<line1>, <line2>, <q-args>)
def AddCommand(start: number, end_: number, name: string)
  var lines = mapnew(getbufline('%', start, end_), (key, val) => json_encode(substitute(val, '\$', '\\$', 'ge')))
  var format = "  \"%s\": {\n    \"prefix\": [\"%s\"],\n    \"body\": [\n      %s\n    ]\n  }"
  var the_name = empty(name) ? 'new' : name

  var reg = &clipboard =~# 'unnamed' ? '*' : '"'
  reg = &clipboard =~# 'unnamedplus' ? '+' : reg
  setreg(reg, printf(format, the_name, the_name, join(lines, ",\n      ")), 'l')
enddef

#
# extra mapping
#
if g:vsnip_extra_mapping
  snoremap <expr> <BS> ("\<BS>" .. (&virtualedit ==# '' && getcurpos()[2] >= col('$') - 1 ? 'a' : 'i'))
endif

#
# <Plug>(vsnip-expand-or-jump)
#
inoremap <silent> <Plug>(vsnip-expand-or-jump) <Esc>:<C-u>call <SID>ExpandOrJump()<CR>
snoremap <silent> <Plug>(vsnip-expand-or-jump) <Esc>:<C-u>call <SID>ExpandOrJump()<CR>
def ExpandOrJump()
  var maybe_complete_done = !empty(v:completed_item) && has_key(v:completed_item, 'user_data') && !empty(v:completed_item.user_data)
  if maybe_complete_done
    timer_start(0, (_) => DoExpandOrJump())
  else
    DoExpandOrJump()
  endif
enddef
def DoExpandOrJump()
  var ctx = vsnip#get_context()
  var sess = vsnip#get_session()
  if !empty(ctx)
    vsnip#expand()
  elseif !empty(sess) && sess.jumpable(1)
    sess.jump(1)
  endif
enddef

#
# <Plug>(vsnip-expand)
#
inoremap <silent> <Plug>(vsnip-expand) <Esc>:<C-u>call <SID>Expand()<CR>
snoremap <silent> <Plug>(vsnip-expand) <C-g><Esc>:<C-u>call <SID>Expand()<CR>
def Expand()
  var maybe_complete_done = !empty(v:completed_item) && has_key(v:completed_item, 'user_data') && !empty(v:completed_item.user_data)
  if maybe_complete_done
    timer_start(0, (_) => vsnip#expand())
  else
    vsnip#expand()
  endif
enddef

#
# <Plug>(vsnip-jump-next)
# <Plug>(vsnip-jump-prev)
#
inoremap <silent> <Plug>(vsnip-jump-next) <Esc>:<C-u>call <SID>Jump(1)<CR>
snoremap <silent> <Plug>(vsnip-jump-next) <Esc>:<C-u>call <SID>Jump(1)<CR>
inoremap <silent> <Plug>(vsnip-jump-prev) <Esc>:<C-u>call <Sid>Jump(-1)<CR>
snoremap <silent> <Plug>(vsnip-jump-prev) <Esc>:<C-u>call <SID>Jump(-1)<CR>
def Jump(direction: number)
  var sess = vsnip#get_session()
  if !empty(sess) && sess.jumpable(direction)
    sess.jump(direction)
  endif
enddef

#
# <Plug>(vsnip-select-text)
#
nnoremap <silent> <Plug>(vsnip-select-text) :set operatorfunc=<SID>VsnipSelectTextNormal<CR>g@
snoremap <silent> <Plug>(vsnip-select-text) <C-g>:<C-u>call <SID>VsnipVisualText(visualmode())<CR>gv<C-g>
xnoremap <silent> <Plug>(vsnip-select-text) :<C-u>call <SID>VsnipVisualText(visualmode())<CR>gv
def VsnipSelectTextNormal(type: string)
  VsnipSetText(type)
enddef

#
# <Plug>(vsnip-cut-text)
#
nnoremap <silent> <Plug>(vsnip-cut-text) :set operatorfunc=<SID>VsnipCutTextNormal<CR>g@
snoremap <silent> <Plug>(vsnip-cut-text) <C-g>:<C-u>call <SID>VsnipVisualText(visualmode())<CR>gv"_c
xnoremap <silent> <Plug>(vsnip-cut-text) :<C-u>call <SID>VsnipVisualText(visualmode())<CR>gv"_c

def VsnipCutTextNormal(type: string)
  feedkeys(VsnipSetText(type) .. '"_c', 'n')
enddef
def VsnipVisualText(type: string)
  VsnipSetText(type)
enddef
def VsnipSetText(type: string): string
  var oldreg = [getreg('"'), getregtype('"')]
  var select: string
  if type ==# 'v'
    select = '`<v`>'
  elseif type ==# 'V'
    select = "'<V'>"
  elseif type ==? "\<C-V>"
    select = "`<\<C-V>`>"
  elseif type ==# 'char'
    select = '`[v`]'
  elseif type ==# 'line'
    select = "'[V']"
  else
    return ''
  endif
  execute 'normal! ' .. select .. 'y'
  vsnip#selected_text(@")
  setreg('"', oldreg[0], oldreg[1])
  return select
enddef

#
# augroup
#
augroup vsnip
  autocmd!
  autocmd InsertLeave * call <SID>OnInsertLeave()
  autocmd TextChanged,TextChangedI,TextChangedP * call <SID>OnTextChanged()
  autocmd BufWritePost * call <SID>OnBufWritePost()
  autocmd BufRead,BufNewFile *.snippets setlocal filetype=snippets
augroup END

def OnInsertLeave()
  var sess = vsnip#get_session()
  if !empty(sess)
    sess.on_insert_leave()
  endif
enddef

def OnTextChanged()
  var sess = vsnip#get_session()
  if !empty(sess)
    sess.on_text_changed()
  endif
enddef

def OnBufWritePost()
  vsnip#source#refresh(resolve(fnamemodify(bufname('%'), ':p')))
enddef
