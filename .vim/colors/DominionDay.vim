" Vim color file
" Converted from Textmate theme Dominion Day using Coloration v0.3.3 (http://github.com/sickill/coloration)

set background=dark
highlight clear

if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "dominion_day"

hi Cursor ctermfg=0 ctermbg=157 cterm=NONE guifg=#000000 guibg=#a3ffa6 gui=NONE
hi Visual ctermfg=NONE ctermbg=22 cterm=NONE guifg=NONE guibg=#2d462e gui=NONE
hi CursorLine ctermfg=NONE ctermbg=233 cterm=NONE guifg=NONE guibg=#121115 gui=NONE
hi CursorColumn ctermfg=NONE ctermbg=233 cterm=NONE guifg=NONE guibg=#121115 gui=NONE
hi ColorColumn ctermfg=NONE ctermbg=233 cterm=NONE guifg=NONE guibg=#121115 gui=NONE
hi LineNr ctermfg=59 ctermbg=233 cterm=NONE guifg=#5d576c guibg=#121115 gui=NONE
hi VertSplit ctermfg=59 ctermbg=59 cterm=NONE guifg=#36323e guibg=#36323e gui=NONE
hi MatchParen ctermfg=63 ctermbg=NONE cterm=underline guifg=#5b55fe guibg=NONE gui=underline
hi StatusLine ctermfg=146 ctermbg=59 cterm=bold guifg=#b9add7 guibg=#36323e gui=bold
hi StatusLineNC ctermfg=146 ctermbg=59 cterm=NONE guifg=#b9add7 guibg=#36323e gui=NONE
hi Pmenu ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi PmenuSel ctermfg=NONE ctermbg=22 cterm=NONE guifg=NONE guibg=#2d462e gui=NONE
hi IncSearch ctermfg=0 ctermbg=97 cterm=NONE guifg=#000000 guibg=#83529d gui=NONE
hi Search ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
hi Directory ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Folded ctermfg=61 ctermbg=0 cterm=NONE guifg=#554d9d guibg=#000000 gui=NONE

hi Normal ctermfg=146 ctermbg=0 cterm=NONE guifg=#b9add7 guibg=#000000 gui=NONE
hi Boolean ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Character ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Comment ctermfg=61 ctermbg=NONE cterm=NONE guifg=#554d9d guibg=NONE gui=NONE
hi Conditional ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi Constant ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Define ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi DiffAdd ctermfg=146 ctermbg=64 cterm=bold guifg=#b9add7 guibg=#3e7b05 gui=bold
hi DiffDelete ctermfg=88 ctermbg=NONE cterm=NONE guifg=#830000 guibg=NONE gui=NONE
hi DiffChange ctermfg=146 ctermbg=17 cterm=NONE guifg=#b9add7 guibg=#102544 gui=NONE
hi DiffText ctermfg=146 ctermbg=24 cterm=bold guifg=#b9add7 guibg=#204a87 gui=bold
hi ErrorMsg ctermfg=157 ctermbg=16 cterm=NONE guifg=#a3ffa6 guibg=#2e0000 gui=NONE
hi WarningMsg ctermfg=157 ctermbg=16 cterm=NONE guifg=#a3ffa6 guibg=#2e0000 gui=NONE
hi Float ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Function ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi Identifier ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi Keyword ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi Label ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi NonText ctermfg=53 ctermbg=232 cterm=NONE guifg=#461560 guibg=#09090b gui=NONE
hi Number ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Operator ctermfg=146 ctermbg=NONE cterm=NONE guifg=#a5a4c5 guibg=NONE gui=NONE
hi PreProc ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi Special ctermfg=146 ctermbg=NONE cterm=NONE guifg=#b9add7 guibg=NONE gui=NONE
hi SpecialKey ctermfg=53 ctermbg=233 cterm=NONE guifg=#461560 guibg=#121115 gui=NONE
hi Statement ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi StorageClass ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi String ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi Tag ctermfg=53 ctermbg=NONE cterm=NONE guifg=#471062 guibg=NONE gui=NONE
hi Title ctermfg=146 ctermbg=NONE cterm=bold guifg=#b9add7 guibg=NONE gui=bold
hi Todo ctermfg=61 ctermbg=NONE cterm=inverse,bold guifg=#554d9d guibg=NONE gui=inverse,bold
hi Type ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
hi rubyClass ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi rubyFunction ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyInterpolationDelimiter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubySymbol ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi rubyConstant ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyStringDelimiter ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi rubyBlockParameter ctermfg=65 ctermbg=NONE cterm=NONE guifg=#5d935d guibg=NONE gui=NONE
hi rubyInstanceVariable ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyInclude ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi rubyGlobalVariable ctermfg=65 ctermbg=NONE cterm=NONE guifg=#5d935d guibg=NONE gui=NONE
hi rubyRegexp ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi rubyRegexpDelimiter ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi rubyEscape ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi rubyControl ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi rubyClassVariable ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyOperator ctermfg=146 ctermbg=NONE cterm=NONE guifg=#a5a4c5 guibg=NONE gui=NONE
hi rubyException ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi rubyPseudoVariable ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyRailsUserClass ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyRailsARAssociationMethod ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyRailsARMethod ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyRailsRenderMethod ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi rubyRailsMethod ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi erubyDelimiter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi erubyComment ctermfg=61 ctermbg=NONE cterm=NONE guifg=#554d9d guibg=NONE gui=NONE
hi erubyRailsMethod ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi htmlTag ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi htmlEndTag ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi htmlTagName ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi htmlArg ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi htmlSpecialChar ctermfg=134 ctermbg=NONE cterm=NONE guifg=#b36fd6 guibg=NONE gui=NONE
hi javaScriptFunction ctermfg=63 ctermbg=NONE cterm=NONE guifg=#5b55fe guibg=NONE gui=NONE
hi javaScriptRailsFunction ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi javaScriptBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi yamlKey ctermfg=53 ctermbg=NONE cterm=NONE guifg=#471062 guibg=NONE gui=NONE
hi yamlAnchor ctermfg=65 ctermbg=NONE cterm=NONE guifg=#5d935d guibg=NONE gui=NONE
hi yamlAlias ctermfg=65 ctermbg=NONE cterm=NONE guifg=#5d935d guibg=NONE gui=NONE
hi yamlDocumentHeader ctermfg=97 ctermbg=NONE cterm=NONE guifg=#83529d guibg=NONE gui=NONE
hi cssURL ctermfg=182 ctermbg=NONE cterm=NONE guifg=#c5a1d7 guibg=NONE gui=NONE
hi cssFunctionName ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi cssColor ctermfg=182 ctermbg=NONE cterm=NONE guifg=#c5a1d7 guibg=NONE gui=NONE
hi cssPseudoClassId ctermfg=65 ctermbg=NONE cterm=NONE guifg=#5d935d guibg=NONE gui=NONE
hi cssClassName ctermfg=54 ctermbg=NONE cterm=NONE guifg=#651e8a guibg=NONE gui=NONE
hi cssValueLength ctermfg=182 ctermbg=NONE cterm=NONE guifg=#c5a1d7 guibg=NONE gui=NONE
hi cssCommonAttr ctermfg=91 ctermbg=NONE cterm=NONE guifg=#971ba1 guibg=NONE gui=NONE
hi cssBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
