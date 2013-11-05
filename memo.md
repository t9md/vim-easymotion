# hl match basic
\%23l\%10c => match line 23, 10col
    call add(hl_coords, '\%' . line_num . 'l\%' . col_num . 'c')
# gatherTarget
    self.gatherTargets(a:regexp)
       =>  target = [[line, col], [line, col] ... ]

# organize targets with grouping
"  groups is like below, key is the Jump key and value is pos which gather in
    let groups = GroupingFn(targets, split(g:EasyMotion_keys, '\zs'))
    {
      'W': [22, 7],
      'X': [22, 14],
      'Y': {
        'a': [22, 18],
        'b': [22, 22],
        'c': [22, 26], 
      }
    }
    
# in s:PromptUser()
# s:CreateCoordKeyDict(a:groups)
s:CreateCoordKeyDict(a:groups)
size is 2, first one is used for sorted list to emulated sorted hash(=dict)
    [
      [
        '00016,00001',
        '00017,00001',
        '00017,00011',
        '00018,00003',
        '00018,00010',
        '00019,00001',
        '00020,00001',
        '00020,00011'
      ],
      {
        '00016,00001': 'a',
        '00017,00001': 'b',
        '00017,00011': 'c',
        '00018,00003': 'd',
        '00018,00010': 'e',
        '00019,00001': 'f',
        '00020,00001': 'g',
        '00020,00011': 'h'
      }
    ]
# lines
    lines is like this, key is line number
     '30': {
       'marker':
         '      \ ''aui''     : [''bONE'', ''c777777'' , ''dONE''],',
       'mb_compensation': 0,
       'orig':
         '      \ ''gui''     : [''NONE'', ''#777777'' , ''NONE''],'
     },
