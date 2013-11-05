" SetupHelper:
function! EasyMotion#InitOptions(options) "{{{1
  for [varname, value] in items(a:options)
    if !exists(varname)
      let {varname} = value
    endif
  endfor
endfunction

function! EasyMotion#InitHL(group, colors) "{{{1
  let group_default = a:group . 'Default'

  " Prepare highlighting variables
  let gui      = a:colors.gui
  let cterm256 = a:colors.cterm256
  let cterm    = a:colors.cterm
  let guihl = printf('guibg=%s guifg=%s gui=%s', gui[0], gui[1], gui[2])
  if !exists('g:CSApprox_loaded')
    let ctermhl = &t_Co == 256
          \ ? printf('ctermbg=%s ctermfg=%s cterm=%s', cterm256[0], cterm256[1], cterm256[2])
          \ : printf('ctermbg=%s ctermfg=%s cterm=%s',    cterm[0], cterm[1],       cterm[2])
  else
    let ctermhl = ''
  endif

  " Create default highlighting group
  execute printf('hi default %s %s %s', group_default, guihl, ctermhl)

  " Check if the hl group exists
  if hlexists(a:group)
    redir => hlstatus | exec 'silent hi ' . a:group | redir END
    " Return if the group isn't cleared
    if hlstatus !~ 'cleared'
      return
    endif
  endif

  " No colors are defined for this group, link to defaults
  exec printf('hi default link %s %s', a:group, group_default)
endfunction

function! EasyMotion#InitMappings(motions) "{{{1
  let opts = {}
  for motion in keys(a:motions)
    let opts['g:EasyMotion_mapping_' . motion] = g:EasyMotion_leader_key . motion
  endfor
  call EasyMotion#InitOptions(opts)

  if !g:EasyMotion_do_mapping
    return
  endif

  for [motion, fn] in items(a:motions)
    if empty(g:EasyMotion_mapping_{motion})
      continue
    endif

    silent exec 'nnoremap <silent> ' . g:EasyMotion_mapping_{motion} . '      :call EasyMotion#' . fn.name . '(0, ' . fn.dir . ')<CR>'
    silent exec 'onoremap <silent> ' . g:EasyMotion_mapping_{motion} . '      :call EasyMotion#' . fn.name . '(0, ' . fn.dir . ')<CR>'
    silent exec 'vnoremap <silent> ' . g:EasyMotion_mapping_{motion} . ' :<C-U>call EasyMotion#' . fn.name . '(1, ' . fn.dir . ')<CR>'
  endfor
endfunction "}}}
" Motion:
function! EasyMotion#F(visualmode, direction) "{{{1
  let char = s:getsearchchar(a:visualmode)
  if empty(char)
    return
  endif

  let re = '\C' . escape(char, '.$^~')
  call s:em.start(re, a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! EasyMotion#T(visualmode, direction) "{{{1
  let char = s:getsearchchar(a:visualmode)

  if empty(char)
    return
  endif

  if a:direction == 1
    let re = '\C' . escape(char, '.$^~') . '\zs.'
  else
    let re = '\C.' . escape(char, '.$^~')
  endif

  call s:em.start(re, a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! EasyMotion#WB(visualmode, direction) "{{{1
  call s:em.start('\(\<.\|^$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! EasyMotion#WBW(visualmode, direction) "{{{1
  call s:em.start('\(\(^\|\s\)\@<=\S\|^$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! EasyMotion#E(visualmode, direction) "{{{1
  call s:em.start('\(.\>\|^$\)', a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! EasyMotion#EW(visualmode, direction) "{{{1
  call s:em.start('\(\S\(\s\|$\)\|^$\)', a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! EasyMotion#JK(visualmode, direction) "{{{1
  call s:em.start('^\(\w\|\s*\zs\|$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! EasyMotion#Search(visualmode, direction) "{{{1
  call s:em.start(@/, a:direction, a:visualmode ? visualmode() : '', '')
endfunction "}}}
" Helper:
function! s:msg(message) "{{{1
  echohl PreProc
  echon 'EasyMotion: '
  echohl None
  echon a:message
endfunction

function! s:prompt(message) "{{{1
  echohl Question
  echo a:message . ': '
  echohl None
endfunction




function! s:setlines(lines, key) "{{{1
  try
    " Try to join changes with previous undo block
    undojoin
  catch
  endtry

  " key is 'orig' or 'marker'
  for [line_num, line] in a:lines
    call setline(line_num, line[a:key])
  endfor
endfunction

function! s:getchar() "{{{1
  let char = getchar()
  if char == char2nr("\<Esc>")
    " Escape key pressed
    redraw
    call s:msg('Cancelled')
    return ''
  endif
  return nr2char(char)
endfunction

function! s:getsearchchar(visualmode) "{{{1
  call s:prompt('Search for character')
  let char = s:getchar()
  " Check that we have an input char
  if empty(char)
    " Restore selection
    if ! empty(a:visualmode)
      silent exec 'normal! gv'
    endif

    return ''
  endif

  return char
endfunction
" }}}

" GroupingAlgorithms:
let s:grouping = {}
function! s:grouping.SCTree(targets, keys) "{{{1
  " Single-key/closest target priority tree
  " This algorithm tries to assign one-key jumps to all the targets closest to the cursor.
  " It works recursively and will work correctly with as few keys as two.
  " Prepare variables for working
  let targets_len = len(a:targets)
  let keys_len = len(a:keys)

  let groups = {}

  let keys = reverse(copy(a:keys))

  " Semi-recursively count targets {{{
  " We need to know exactly how many child nodes (targets) this branch will have
  " in order to pass the correct amount of targets to the recursive function.

  " Prepare sorted target count list {{{
  " This is horrible, I know. But dicts aren't sorted in vim, so we need to
  " work around that. That is done by having one sorted list with key counts,
  " and a dict which connects the key with the keys_count list.

  let keys_count = []
  let keys_count_keys = {}

  let i = 0
  for key in keys
    call add(keys_count, 0)

    let keys_count_keys[key] = i

    let i += 1
  endfor
  " }}}

  let targets_left = targets_len
  let level = 0
  let i = 0

  while targets_left > 0
    " Calculate the amount of child nodes based on the current level
    let childs_len = (level == 0 ? 1 : (keys_len - 1) )

    for key in keys
      " Add child node count to the keys_count array
      let keys_count[keys_count_keys[key]] += childs_len

      " Subtract the child node count
      let targets_left -= childs_len

      if targets_left <= 0
        " Subtract the targets left if we added too many too
        " many child nodes to the key count
        let keys_count[keys_count_keys[key]] += targets_left

        break
      endif

      let i += 1
    endfor

    let level += 1
  endwhile
  " }}}
  " Create group tree {{{
  let i = 0
  let key = 0

  call reverse(keys_count)

  for key_count in keys_count
    if key_count > 1
      " We need to create a subgroup
      " Recurse one level deeper
      let groups[a:keys[key]] = self.SCTree(a:targets[i : i + key_count - 1], a:keys)
    elseif key_count == 1
      " Assign single target key
      let groups[a:keys[key]] = a:targets[i]
    else
      " No target
      continue
    endif

    let key += 1
    let i += key_count
  endfor
  " }}}

  " Finally!
  return groups
endfunction
" }}}
function! s:grouping.Original(targets, keys) "{{{1
  " Split targets into groups (1 level)
  let targets_len = len(a:targets)
  let keys_len = len(a:keys)

  let groups = {}

  let i = 0
  let root_group = 0
  try
    while root_group < targets_len
      let groups[a:keys[root_group]] = {}

      for key in a:keys
        let groups[a:keys[root_group]][key] = a:targets[i]

        let i += 1
      endfor

      let root_group += 1
    endwhile
  catch | endtry

  " Flatten the group array
  if len(groups) == 1
    let groups = groups[a:keys[0]]
  endif

  return groups
endfunction
" }}}
function! s:CreateCoordKeyDict(groups, ...) "{{{1
  " Dict structure:
  " 1,2 : a
  " 2,3 : b
  let coord_keys = {}
  let group_key = a:0 == 1 ? a:1 : ''

  " item = [line, col]
  " key = 'x','y'. etc
  for [key, item] in items(a:groups)
    let key = ( ! empty(group_key) ? group_key : key)
    if type(item) == type([])
      " zero-padded in order to sort correctly
      let line_col = printf('%05d,%05d', item[0], item[1])
      let coord_keys[line_col] = key
    elseif type(item) == type({})
      " Item is a dict (has children)
      call extend(coord_keys, s:CreateCoordKeyDict(item, key))
    else
      throw "NEVER HAPPEN"
    endif
    unlet item
  endfor
  return coord_keys
endfunction
" }}}

" POS:
let s:pos = {}
function! s:pos.new(pos) "{{{1
  " pos should size one List of [line, col]
  let o = deepcopy(self)
  let o.line = a:pos[0]
  let o.col = a:pos[1]
  return o
endfunction

function! s:pos.to_s() "{{{1
  return string([self.line, self.col])
endfunction

function! s:pos.set(...) "{{{1
  if a:0 == 0
    call cursor(self.line, self.col)
  else
    keepjump call cursor(self.line, self.col)
  endif
endfunction
" }}}

" UI:
let s:ui = {}
function! s:ui.read_target() "{{{1
  call s:prompt('Target key')
  return s:getchar()
endfunction
function! s:ui.show_jumpscreen()
  call self.setup_tareget_hl()
  call s:setlines(items(self.lines), 'marker')
  redraw
endfunction

function! s:ui.revert_screen() "{{{1
  call s:setlines(items(self.lines), 'orig')
  if has_key(self, "target_hl_id")
    call matchdelete(self.target_hl_id)
  endif
  redraw
endfunction

function! s:ui.prepare_display_lines(groups) "{{{1
  let lines = {}

  for col_line in self.sorted_col_line
    let target_key = self.c_dic[col_line]
    let [line_num, col_num] = split(col_line, ',')
    let line_num = str2nr(line_num)
    let col_num  = str2nr(col_num)

    if ! has_key(lines, line_num)
      let current_line = getline(line_num)
      let lines[line_num] = { 'orig': current_line, 'marker': current_line, 'mb_compensation': 0 }
    endif
    let target_char_len = strlen(matchstr(lines[line_num]['marker'], '\%' . col_num . 'c.'))
    let target_key_len = strlen(target_key)

    let col_num -= lines[line_num]['mb_compensation']
    if strlen(lines[line_num]['marker']) > 0
      let lines[line_num]['marker'] = substitute(lines[line_num]['marker'], '\%' . col_num . 'c.', target_key, '')
    else
      let lines[line_num]['marker'] = target_key
    endif
    let lines[line_num]['mb_compensation'] += (target_char_len - target_key_len)
  endfor
  return lines
endfunction

function! s:ui.setup_tareget_hl() "{{{1
  let hl_expr =  join(map(map(self.sorted_col_line, 'split(v:val, ",")'), 
        \ "'\\%' . v:val[0] . 'l\\%' . v:val[1] . 'c'"), '\|')
  let self.target_hl_id = matchadd(g:EasyMotion_hl_group_target, hl_expr , 1)
endfunction

function! s:ui.start(groups) "{{{1
  let group_values = values(a:groups)
  if len(group_values) == 1
    redraw
    return s:pos.new(group_values[0])
  endif
  let self.c_dic = s:CreateCoordKeyDict(a:groups)
  let self.sorted_col_line = sort(keys(self.c_dic))
  let self.lines = self.prepare_display_lines(a:groups)

  try
    call self.show_jumpscreen()
    let char = self.read_target()
    call s:ensure(!empty(char), "Cancelled")
    call s:ensure(has_key(a:groups, char), "Invalid target" )
  finally
    call self.revert_screen()
  endtry

  let target = a:groups[char]
  return type(target) == type([])
        \ ? s:pos.new(target)
        \ : self.start(target)
endfunction
" }}}

" Main:
let s:em = {}
function! s:em.set_opts() "{{{1
  let opts = {
          \ '&scrolloff':   0,
          \ '&modified':    0,
          \ '&modifiable':  1,
          \ '&readonly':    0,
          \ '&spell':       0,
          \ '&virtualedit': '',
          \ }
  let self._opts = {}
  let buf = bufname("")
  for [var, val] in items(opts)
    let self._opts[var] = getbufvar(buf, var)
    call setbufvar(buf, var, val)
  endfor
endfunction

function! s:em.restore_opts() "{{{1
  for [var, val] in items(self._opts)
    call setbufvar(bufname(''), var, val)
  endfor
  let self._opts = {}
endfunction

function! s:em.start(regexp, direction, visualmode, mode) "{{{1
  let self.orig_pos = s:pos.new([line('.'), col('.')])
  let self.direction = a:direction
  let self.vmode = a:visualmode
  let targets = []
  let group_funname = g:EasyMotion_grouping

  try
    call self.set_opts()
  " target = [[line, col], [line, col] ... ]
    let targets = self.gatherTargets(a:regexp)
    call s:ensure( !empty(targets), "No candidate")

    let groups = 
          \ s:grouping[group_funname](targets, split(g:EasyMotion_keys, '\zs'))

    call self.shade()
    let coords = s:ui.start(groups)

    " Update selection {{{
    if ! empty(self.vmode)
      call orig.pos.set('keepjump')
      exec 'normal! ' . self.vmode
    endif
    " }}}
    " Handle operator-pending mode {{{
    if a:mode == 'no'
      " This mode requires that we eat one more
      " character to the right if we're using
      " a forward motion
      if a:direction != 1
        let coords.col += 1
      endif
    endif
    " }}}

    " Update cursor position
    call self.orig_pos.set()
    mark '
    call coords.set()

    call s:msg('Jumping to ' . coords.to_s())
  catch
    redraw
    call s:msg(v:exception)
    call self.recover()
  finally
    call self.restore_opts()
    call self.shade_reset()
  endtry
endfunction

function! s:ensure(expr, err) "{{{1
  if ! a:expr
    throw a:err
  endif
endfunction

function! s:em.recover() "{{{1
  if ! empty(self.vmode)
    silent exec 'normal! gv'
  else
    call self.orig_pos.set('keepjump')
  endif
endfunction

function! s:em.shade() "{{{1
  if !g:EasyMotion_do_shade
    return
  endif
  let hl_pos = '\%' . self.orig_pos.line . 'l\%'. self.orig_pos.col .'c'
  let hl_re = self.direction ==# 1
        \ ? '\%'. line('w0') .'l\_.*' . hl_pos
        \ : hl_pos . '\_.*\%'. line('w$') .'l'
  let self.shade_hl_id = matchadd(g:EasyMotion_hl_group_shade, hl_re, 0)
endfunction

function! s:em.shade_reset() "{{{1
  if has_key(self, "shade_hl_id")
    call matchdelete(self.shade_hl_id)
    call remove(self, "shade_hl_id")
  endif
endfunction

function! s:em.gatherTargets(regexp) "{{{1
  " return array of pos like [[line, col], [line, col] ... ]
  let direction = self.direction == 1 ? 'b' : ''
  let stopline  = self.direction == 1 ? line('w0') : line('w$')
  let targets = []

  while 1
    let pos = searchpos(a:regexp, direction, stopline)
    " Reached end of search range
    if pos == [0, 0] | break | endif
    if foldclosed(pos[0]) != -1 | continue | endif
    call add(targets, pos)
  endwhile
  return targets
endfunction
" }}}

" vim: foldmethod=marker
