map <SID>xx <SID>xx
let s:sid = maparg("<SID>xx")
unmap <SID>xx
let s:sid = substitute(s:sid, 'xx', '', '')

function! s:msg(message) "{{{1
  echohl PreProc
  echon 'EasyMotion: '
  echohl None
  echon a:message
endfunction
function! s:ensure(expr, err) "{{{1
  if ! a:expr
    throw a:err
  endif
endfunction

function! s:prompt(msg) "{{{1
  echohl Question
  echo a:msg . ': '
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
    call eazymotion#util#msg('Cancelled')
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

function! easymotion#util#use(list) "{{{1
  let u = {}
  for fname in a:list
    let u[fname] = function(s:sid . fname)
  endfor
  return u
endfunction
" vim: foldmethod=marker
