function! easymotion#helper#InitOptions(options) "{{{1
  for [varname, value] in items(a:options)
    if !exists(varname)
      let {varname} = value
    endif
  endfor
endfunction

function! easymotion#helper#InitHL(group, colors) "{{{1
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

function! easymotion#helper#InitMappings(motions) "{{{1
  let opts = {}
  for motion in keys(a:motions)
    let opts['g:EasyMotion_mapping_' . motion] = g:EasyMotion_leader_key . motion
  endfor
  call easymotion#helper#InitOptions(opts)

  if !g:EasyMotion_do_mapping
    return
  endif

  for [motion, fn] in items(a:motions)
    if empty(g:EasyMotion_mapping_{motion})
      continue
    endif

    silent exec 'nnoremap <silent> ' . g:EasyMotion_mapping_{motion} . '      :call easymotion#' . fn.name . '(0, ' . fn.dir . ')<CR>'
    silent exec 'onoremap <silent> ' . g:EasyMotion_mapping_{motion} . '      :call easymotion#' . fn.name . '(0, ' . fn.dir . ')<CR>'
    silent exec 'vnoremap <silent> ' . g:EasyMotion_mapping_{motion} . ' :<C-U>call easymotion#' . fn.name . '(1, ' . fn.dir . ')<CR>'
  endfor
endfunction "}}}
" vim: foldmethod=marker
