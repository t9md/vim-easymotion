" WORD DEFINITION
" * target_key or tgt: key to type to jump new_pos
" * pos: position which consists of [line, column]
" * pos_new: new cursor postion to jump to
" * pos_org: original cursor position
let s:u = easymotion#util#use([ "msg", "ensure" ])

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
  let curbuf = bufname("")
  for [var, val] in items(opts)
    let self._opts[var] = getbufvar(curbuf, var)
    call setbufvar(curbuf, var, val)
  endfor
endfunction



function! s:em.restore_opts() "{{{1
  for [var, val] in items(self._opts)
    call setbufvar(bufname(''), var, val)
  endfor
  let self._opts = {}
endfunction

function! s:em.start(regexp, direction, visualmode, mode) "{{{1
  let self.pos_org = easymotion#pos#new([line('.'), col('.')])
  let self.direction = a:direction
  let self.vmode = a:visualmode
  let targets = []
  try
    call self.set_opts()
  " target = [[line, col], [line, col] ... ]
    let targets = self.gatherTargets(a:regexp)
    call s:u.ensure( !empty(targets), "No candidate")

    let tgt2pos = easymotion#grouping#{g:EasyMotion_grouping}(
          \targets, split(g:EasyMotion_keys, '\zs'))

    call self.shade()
    let pos_new = easymotion#ui#start(tgt2pos)

    " operator-pending mode
    if a:mode == 'no' && a:direction == 0
      " This mode requires that we eat one more character to the right if
      " we're using a forward motion
      let pos_new.col += 1
    endif

    if ! empty(self.vmode)
      call self.pos_org.set('keepjump')
      exec 'normal! ' . self.vmode
    endif
    call self.pos_org.set()
    mark '
    call pos_new.set()

    call s:u.msg('Jumping to ' . pos_new.to_s())
  catch
    redraw
    call s:u.msg(v:exception)
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
    call self.pos_org.set('keepjump')
  endif
endfunction

function! s:em.shade() "{{{1
  if !g:EasyMotion_do_shade
    return
  endif
  let [line, col ] = [ self.pos_org.line, self.pos_org.col ]
  let hl_pos = '\%' . line . 'l\%'. col .'c'
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

" Public:
function! easymotion#F(visualmode, direction) "{{{1
  let char = s:getsearchchar(a:visualmode)
  if empty(char)
    return
  endif

  let re = '\C' . escape(char, '.$^~')
  call s:em.start(re, a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! easymotion#T(visualmode, direction) "{{{1
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

function! easymotion#WB(visualmode, direction) "{{{1
  call s:em.start('\(\<.\|^$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! easymotion#WBW(visualmode, direction) "{{{1
  call s:em.start('\(\(^\|\s\)\@<=\S\|^$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! easymotion#E(visualmode, direction) "{{{1
  call s:em.start('\(.\>\|^$\)', a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! easymotion#EW(visualmode, direction) "{{{1
  call s:em.start('\(\S\(\s\|$\)\|^$\)', a:direction, a:visualmode ? visualmode() : '', mode(1))
endfunction

function! easymotion#JK(visualmode, direction) "{{{1
  call s:em.start('^\(\w\|\s*\zs\|$\)', a:direction, a:visualmode ? visualmode() : '', '')
endfunction

function! easymotion#Search(visualmode, direction) "{{{1
  call s:em.start(@/, a:direction, a:visualmode ? visualmode() : '', '')
endfunction "}}}
" vim: foldmethod=marker
