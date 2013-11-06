" ScriptInitialization:
if exists('g:EasyMotion_loaded') || &compatible || version < 702
  " finish
endif

let g:EasyMotion_loaded = 1

" DefaultConfiguration:
"=================================================================
" DefaultOptions:
call easymotion#helper#InitOptions({
      \ 'g:EasyMotion_leader_key'      : '<Leader><Leader>',
      \ 'g:EasyMotion_keys'            : 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
      \ 'g:EasyMotion_do_shade'        : 1,
      \ 'g:EasyMotion_do_mapping'      : 1,
      \ 'g:EasyMotion_grouping'        : 'SCTree',
      \ 'g:EasyMotion_hl_group_target' : 'EasyMotionTarget',
      \ 'g:EasyMotion_hl_group_shade'  : 'EasyMotionShade',
      \ })

" DefaultHighlighting:
" [ guibg, guifg, qui ]
let s:target_hl_defaults = {
      \ 'gui'     : ['NONE', '#ff0000' , 'bold'],
      \ 'cterm256': ['NONE', '196'     , 'bold'],
      \ 'cterm'   : ['NONE', 'red'     , 'bold'],
      \ }

let s:shade_hl_defaults = {
      \ 'gui'     : ['NONE', '#777777' , 'NONE'],
      \ 'cterm256': ['NONE', '242'     , 'NONE'],
      \ 'cterm'   : ['NONE', 'grey'    , 'NONE'],
      \ }

function! s:init_hl_target() "{{{1
  call easymotion#helper#InitHL(g:EasyMotion_hl_group_target, s:target_hl_defaults)
endfunction
function! s:init_hl_shade() "{{{1
  call easymotion#helper#InitHL(g:EasyMotion_hl_group_shade,  s:shade_hl_defaults)
endfunction

call s:init_hl_target()
call s:init_hl_shade()

augroup EasyMotionInitHL
  autocmd!
  autocmd ColorScheme * call s:init_hl_target()
  autocmd ColorScheme * call s:init_hl_shade()
augroup END

" 'name' is function name
call easymotion#helper#InitMappings({
      \ 'f':  { 'name': 'F',      'dir': 0 },
      \ 'F':  { 'name': 'F',      'dir': 1 },
      \ 't':  { 'name': 'T',      'dir': 0 },
      \ 'T':  { 'name': 'T',      'dir': 1 },
      \ 'w':  { 'name': 'WB',     'dir': 0 },
      \ 'W':  { 'name': 'WBW',    'dir': 0 },
      \ 'b':  { 'name': 'WB',     'dir': 1 },
      \ 'B':  { 'name': 'WBW',    'dir': 1 },
      \ 'e':  { 'name': 'E',      'dir': 0 },
      \ 'E':  { 'name': 'EW',     'dir': 0 },
      \ 'ge': { 'name': 'E',      'dir': 1 },
      \ 'gE': { 'name': 'EW',     'dir': 1 },
      \ 'j':  { 'name': 'JK',     'dir': 0 },
      \ 'k':  { 'name': 'JK',     'dir': 1 },
      \ 'n':  { 'name': 'Search', 'dir': 0 },
      \ 'N':  { 'name': 'Search', 'dir': 1 },
      \ })

" vim: foldmethod=marker
