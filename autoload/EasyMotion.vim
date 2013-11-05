
unlet! g:V
" DefaultConfigurationFunctions:
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
" MotionFunctions:
function! EasyMotion#F(visualmode, direction) "{{{1
  let char = s:GetSearchChar(a:visualmode)

  if empty(char)
    return
  endif

  let re = '\C' . escape(char, '.$^~')

  " call s:EasyMotion(re, a:direction, a:visualmode ? visualmode() : '', mode(1))
  call s:em.start(re, a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! EasyMotion#T(visualmode, direction) "{{{1
  let char = s:GetSearchChar(a:visualmode)

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
" HelperFunctions:
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


function! s:VarReset(var, ...) "{{{1
  if ! exists('s:var_reset')
    let s:var_reset = {}
  endif

  let buf = bufname("")

  if a:0 == 0 && has_key(s:var_reset, a:var)
    " Reset var to original value
    call setbufvar(buf, a:var, s:var_reset[a:var])
  elseif a:0 == 1
    let new_value = a:0 == 1 ? a:1 : ''

    " Store original value
    let s:var_reset[a:var] = getbufvar(buf, a:var)

    " Set new var value
    call setbufvar(buf, a:var, new_value)
  endif
endfunction


function! s:SetLines(lines, key) "{{{1
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

function! s:GetChar() "{{{1
  let char = getchar()
  if char == char2nr("\<Esc>")
    " Escape key pressed
    redraw
    call s:msg('Cancelled')
    return ''
  endif
  return nr2char(char)
endfunction

function! s:GetSearchChar(visualmode) "{{{1
  call s:prompt('Search for character')
  let char = s:GetChar()
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

" GroupingAlgorithms:
let s:grouping_algorithms = {
      \   1: 'SCTree'
      \ , 2: 'Original'
      \ }

" Single-key/closest target priority tree {{{
" This algorithm tries to assign one-key jumps to all the targets closest to the cursor.
" It works recursively and will work correctly with as few keys as two.
function! s:GroupingAlgorithmSCTree(targets, keys) "{{{1
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
      let groups[a:keys[key]] = s:GroupingAlgorithmSCTree(a:targets[i : i + key_count - 1], a:keys)
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
" Original:
function! s:GroupingAlgorithmOriginal(targets, keys) "{{{1
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
" Coord/key dictionary creation {{{

function! s:CreateCoordKeyDict(groups, ...) "{{{1
  " Dict structure:
  " 1,2 : a
  " 2,3 : b
  let sort_list = []
  let coord_keys = {}
  let group_key = a:0 == 1 ? a:1 : ''

  for [key, item] in items(a:groups)
    let key = ( ! empty(group_key) ? group_key : key)

    if type(item) == 3
      " Destination coords

      " The key needs to be zero-padded in order to
      " sort correctly
      let dict_key = printf('%05d,%05d', item[0], item[1])
      let coord_keys[dict_key] = key

      " We need a sorting list to loop correctly in
      " PromptUser, dicts are unsorted
      call add(sort_list, dict_key)
    else
      " Item is a dict (has children)
      let coord_key_dict = s:CreateCoordKeyDict(item, key)

      " Make sure to extend both the sort list and the
      " coord key dict
      call extend(sort_list, coord_key_dict[0])
      call extend(coord_keys, coord_key_dict[1])
    endif

    unlet item
  endfor

  return [sort_list, coord_keys]
endfunction
" }}}
" Core:
function! s:PromptUser(groups) "{{{1
  let group_values = values(a:groups)

  if len(group_values) == 1
    redraw
    return group_values[0]
  endif

  let lines = {}
  let hl_coords = []
  let coord_key_dict = s:CreateCoordKeyDict(a:groups)
  unlet! g:E
  let g: = coord_key_dict

  for dict_key in sort(coord_key_dict[0])
    let target_key = coord_key_dict[1][dict_key]
    let [line_num, col_num] = split(dict_key, ',')

    let line_num = str2nr(line_num)
    let col_num = str2nr(col_num)

    " Add original line and marker line
    if ! has_key(lines, line_num)
      let current_line = getline(line_num)
      let lines[line_num] = { 'orig': current_line, 'marker': current_line, 'mb_compensation': 0 }
    endif

    " Compensate for byte difference between marker
    " character and target character
    "
    " This has to be done in order to match the correct
    " column; \%c matches the byte column and not display
    " column.
    let target_char_len = strlen(matchstr(lines[line_num]['marker'], '\%' . col_num . 'c.'))
    let target_key_len = strlen(target_key)

    " Solve multibyte issues by matching the byte column
    " number instead of the visual column
    let col_num -= lines[line_num]['mb_compensation']

    if strlen(lines[line_num]['marker']) > 0
      " Substitute marker character if line length > 0
      let lines[line_num]['marker'] = substitute(lines[line_num]['marker'], '\%' . col_num . 'c.', target_key, '')
    else
      " Set the line to the marker character if the line is empty
      let lines[line_num]['marker'] = target_key
    endif

    " Add highlighting coordinates
    call add(hl_coords, '\%' . line_num . 'l\%' . col_num . 'c')

    " Add marker/target lenght difference for multibyte
    " compensation
    let lines[line_num]['mb_compensation'] += (target_char_len - target_key_len)
  endfor

" lines is like this, key is line number
"  '30': {
"    'marker':
"      '      \ ''aui''     : [''bONE'', ''c777777'' , ''dONE''],',
"    'mb_compensation': 0,
"    'orig':
"      '      \ ''gui''     : [''NONE'', ''#777777'' , ''NONE''],'
"  },
  let g:V = lines
  let lines_items = items(lines)
  " }}}
  " Highlight targets {{{
  let target_hl_id = matchadd(g:EasyMotion_hl_group_target, join(hl_coords, '\|'), 1)
  " }}}

  try
    call s:SetLines(lines_items, 'marker')
    redraw
    call s:prompt('Target key')
    let char = s:GetChar()
  finally
    call s:SetLines(lines_items, 'orig')
    if exists('target_hl_id')
      call matchdelete(target_hl_id)
    endif
    redraw
  endtry
  if empty(char)
    throw 'Cancelled'
  endif
  if ! has_key(a:groups, char)
    throw 'Invalid target'
  endif

  let target = a:groups[char]

  if type(target) == type([])
    return target
  else
    return s:PromptUser(target)
  endif
endfunction
" }}}

" EM:
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
  let self.orig_pos = s:pos.new(line('.'), col('.'))
  let self.direction = a:direction
  let self.vmode = a:visualmode
  let targets = []
  let funcname = 's:GroupingAlgorithm'
        \ . s:grouping_algorithms[g:EasyMotion_grouping] 
  " varname for funcref must begin Captal
  let GroupingFn = function(funcname)

  try
    call self.set_opts()
  " target = [[line, col], [line, col] ... ]
    let targets = self.gatherTargets(a:regexp)
    if empty(targets)
      throw 'No matches'
    endif
    " }}}
    let groups = GroupingFn(targets, split(g:EasyMotion_keys, '\zs'))
    " let g:V = groups
"  groups is like below, key is the Jump key and value is pos which gather in
"  gatherTargets()
"    {
"      'W': [22, 7],
"      'X': [22, 14],
"      'Y': {
"        'a': [22, 18],
"        'b': [22, 22],
"        'c': [22, 26], 
"      }
"    }
    call self.shade()

    " Prompt user for target group/character
    " coords = [line, col]
    let [l, c] =  s:PromptUser(groups)
    let coords = s:pos.new(l,c)

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

" POS:
let s:pos = {}
function! s:pos.new(line,col) "{{{1
  let o = deepcopy(self)
  let o.line = a:line
  let o.col = a:col
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



" vim: foldmethod=marker
