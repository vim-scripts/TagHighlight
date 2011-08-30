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
	if &cp || (exists('g:loaded_TagHighlight') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHighlight = 1

let old_versions = globpath(&rtp, 'plugin/ctags_highlighting.vim')
if len(old_versions) > 0
	echoerr "Legacy ctags highlighter found.  This highlighter is"
				\ "intended to replace ctags_highlighter.  See the"
				\ "user documentation in doc/TagHighlight.txt for"
				\ "more information."
	finish
endif

if ! exists('g:TagHighlightSettings')
	let g:TagHighlightSettings = {}
endif

let g:TagHighlightPrivate = {}

let s:plugin_paths = split(globpath(&rtp, 'plugin/TagHighlight/TagHighlight.py'), '\n')
if len(s:plugin_paths) == 1
	let g:TagHighlightPrivate['PluginPath'] = fnamemodify(s:plugin_paths[0], ':p:h')
elseif len(s:plugin_paths) == 0
	echoerr "Cannot find TagHighlight.py"
else
	echoerr "Multiple plugin installs found: something has gone wrong!"
endif

" Update types & tags
command! -bar UpdateTypesFile 
			\ silent call TagHighlight#Generation#UpdateAndRead(0)

command! -bar UpdateTypesFileOnly 
			\ silent call TagHighlight#Generation#UpdateAndRead(1)

command! -nargs=1 UpdateTypesFileDebug 
			\ call TagHighlight#Debug#DebugUpdateTypesFile(<f-args>)

function! s:LoadLanguages()
	" This loads the language data files.
	let language_files = split(glob(g:TagHighlightPrivate['PluginPath'] . '/data/languages/*.txt'), '\n')
	let g:TagHighlightPrivate['ExtensionLookup'] = {}
	let g:TagHighlightPrivate['FileTypeLookup'] = {}
	let g:TagHighlightPrivate['SyntaxLookup'] = {}
	let g:TagHighlightPrivate['SpecialSyntaxHandlers'] = {}
	for language_file in language_files
		let entries = TagHighlight#LoadDataFile#LoadFile(language_file)
		if has_key(entries, 'Suffix') && has_key(entries, 'VimExtensionMatcher') 
					\ && has_key(entries, 'VimFileTypes') && has_key(entries, 'VimSyntaxes')
			let g:TagHighlightPrivate['ExtensionLookup'][entries['VimExtensionMatcher']] = entries['Suffix']

			if type(entries['VimFileTypes']) == type([])
				let ftkey = join(entries['VimFileTypes'], ",")
			else
				let ftkey = entries['VimFileTypes']
			endif
			let g:TagHighlightPrivate['FileTypeLookup'][ftkey] = entries['Suffix']

			if type(entries['VimSyntaxes']) == type([])
				let stkey = join(entries['VimSyntaxes'], ",")
			else
				let stkey = entries['VimSyntaxes']
			endif
			let g:TagHighlightPrivate['SyntaxLookup'][stkey] = entries['Suffix']
		else
			echoerr "Could not load language from file " . language_file
		endif
		if has_key(entries, 'SpecialSyntaxHandlers')
			if type(entries['SpecialSyntaxHandlers']) == type([])
				let handlers = entries['SpecialSyntaxHandlers']
			else
				let handlers = [entries['SpecialSyntaxHandlers']]
			endif
			let g:TagHighlightPrivate['SpecialSyntaxHandlers'][entries['Suffix']] = handlers
		endif
	endfor
endfunction

function! s:LoadKinds()
	" Load the list of kinds (ignoring ctags information) into
	" Vim.  This is used to make the default links
	let g:TagHighlightPrivate['Kinds'] = TagHighlight#LoadDataFile#LoadDataFile('kinds.txt')
	" Use a dictionary to get all unique entries
	let tag_names_dict = {}
	for entry in keys(g:TagHighlightPrivate['Kinds'])
		for key in keys(g:TagHighlightPrivate['Kinds'][entry])
			let tag_names_dict[g:TagHighlightPrivate['Kinds'][entry][key]] = ""
		endfor
	endfor
	let g:TagHighlightPrivate['AllTypes'] = sort(keys(tag_names_dict))
endfunction

function! TagHLDebug(str, level)
	if TagHighlight#Debug#DebugLevelIncludes(a:level)
		try
			let debug_file = TagHighlight#Option#GetOption('DebugFile')
			let print_time = TagHighlight#Option#GetOption('DebugPrintTime')
		catch /Unrecognised option/
			" Probably haven't loaded the option definitions
			" yet, so assume no debug log file
			let debug_file = 'None'
		endtry
		if debug_file == 'None'
			echomsg a:str
		else
			exe 'redir >>' debug_file
			if print_time && exists("*strftime")
				silent echo strftime("%H.%M.%S") . ": " . a:str
			else
				silent echo a:str
			endif
			redir END
		endif
	endif
endfunction

call s:LoadLanguages()
call s:LoadKinds()

for tagname in g:TagHighlightPrivate['AllTypes']
	let simplename = substitute(tagname, '^CTags', '', '')
	exe 'hi default link' tagname simplename
	" Highlight everything as a keyword by default
	exe 'hi default link' simplename 'Keyword'
endfor

if ! has_key(g:TagHighlightPrivate, 'AutoCommandsLoaded')
	let g:TagHighlightPrivate['AutoCommandsLoaded'] = 1
	autocmd BufRead,BufNewFile * call TagHighlight#ReadTypes#ReadTypesByExtension()
	autocmd Syntax * call TagHighlight#ReadTypes#ReadTypesBySyntax()
	autocmd FileType * call TagHighlight#ReadTypes#ReadTypesByFileType()
endif
command! ReadTypes call TagHighlight#ReadTypes#ReadTypesByOption()
