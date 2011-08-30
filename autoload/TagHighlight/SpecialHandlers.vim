" Tag Highlighter:
"   Author:  A. S. Budden <abudden _at_ gmail _dot_ com>
" Copyright: Copyright (C) 2009-2011 A. S. Budden
"            Permission is hereby granted to use and distribute this code,
"            with or without modifications, provided that this copyright
"            notice is copied with it. Like anything else that's free,
"            the TagHighlight plugin is provided *as is* and comes with no
"            warranty of any kind, either expressed or implied. By using
"            this plugin, you agree that in no event will the copyright
"            holder be liable for any damages resulting from the use
"            of this software.

" ---------------------------------------------------------------------
try
	if &cp || (exists('g:loaded_TagHLSpecialHandlers') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLSpecialHandlers = 1

function! TagHighlight#SpecialHandlers#CRainbowHandler()
	call TagHLDebug("Language handler for rainbow.vim compatibility", "Information")
	if exists("b:hlrainbow") && ! exists("g:nohlrainbow")
		" Use a dictionary as a set (a unique item list)
		let hl_dict = {}
		for key in ["c","c++"]
			if has_key(g:TagHighlightPrivate['Kinds'], key)
				for kind in values(g:TagHighlightPrivate['Kinds'][key])
					let hl_dict[kind] = ""
				endfor
			endif
		endfor
		let all_kinds = keys(hl_dict)
		for cluster in ["cBracketGroup","cCppBracketGroup","cCurlyGroup","cParenGroup","cCppParenGroup"]
			exe 'syn cluster' cluster 'add=' . join(all_kinds, ',')
		endfor
	endif
endfunction

function! TagHighlight#SpecialHandlers#JavaTopHandler()
	call TagHLDebug("Language handler for javaTop compatibility", "Information")
	if has_key(g:TagHighlightPrivate['Kinds'], 'java')
		exe 'syn cluster javaTop add=' . join(values(g:TagHighlightPrivate['Kinds']['java']), ',')
	endif
endfunction
