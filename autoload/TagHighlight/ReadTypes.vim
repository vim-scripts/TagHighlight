" Tag Highlighter:
"   Author:  A. S. Budden <abudden _at_ gmail _dot_ com>
"   Date:    02/08/2011
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
	if &cp || (exists('g:loaded_TagHLReadTypes') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLReadTypes = 1

function! TagHighlight#ReadTypes#ReadTypesAutoDetect()
	let extension = expand('%:e')
	if TagHighlight#Debug#DebugLevelIncludes('Information')
		call TagHLDebug("Reading types for extension " . extension . " at " . strftime("%Y%m%d-%H%M%S"), "Information")
	endif
	for key in keys(g:TagHighlightPrivate['ExtensionLookup'])
		let regex = '^'.key.'$'
		if extension =~ regex
			call TagHighlight#ReadTypes#ReadTypes(g:TagHighlightPrivate['ExtensionLookup'][key])
		endif
	endfor
endfunction

function! TagHighlight#ReadTypes#ReadTypes(suffix)
	let savedView = winsaveview()

	call TagHighlight#Option#LoadOptionFileIfPresent()

	let file = expand('<afile>')
	if len(file) == 0
		let file = expand('%')
	endif

	call TagHLDebug("Reading types of suffix " . a:suffix . " for file " . file, "Information")

	if TagHighlight#Option#GetOption('DisableTypeParsing') == 1
		call TagHLDebug("Type file parsing disabled", 'Status')
		return
	endif

	let fullname = expand(file . ':p')

	let skiplist = TagHighlight#Option#GetOption('ParsingSkipList')
	if len(skiplist) > 0
		let basename = expand(file . ':p:t')
		if index(skiplist, basename) != -1
			call TagHLDebug("Skipping file due to basename match", 'Status')
			return
		endif
		if index(skiplist, fullname) != -1
			call TagHLDebug("Skipping file due to fullname match", 'Status')
			return
		endif
	endif
	"
	" Call Pre Read hooks (if any)
	let preread_hooks = TagHighlight#Option#GetOption('PreReadHooks')
	for preread_hook in preread_hooks
		call TagHLDebug("Calling pre-read hook " . preread_hook, 'Information')
		exe 'call' preread_hook . '(fullname, a:suffix)'
	endfor

	call TagHLDebug("Searching for types file", 'Status')

	" Clear any existing syntax entries
	for group in g:TagHighlightPrivate['AllTypes']
		exe 'syn clear' group
	endfor

	let b:TagHighlightLoadedLibraries = []
	
	let type_files = TagHighlight#ReadTypes#FindTypeFiles(a:suffix)
	for fname in type_files
		call TagHLDebug("Loading type highlighter file " . fname, 'Information')
		exe 'so' fname
		let b:TagHighlightLoadedLibraries +=
					\ [{
					\     'Name': 'Local',
					\     'Filename': fnamemodify(fname, ':t'),
					\     'Path': fnamemodify(fname, ':p'),
					\ }]
	endfor

	" Load user libraries
	let user_library_files = TagHighlight#Libraries#FindUserLibraries()
	for lib in user_library_files
		call TagHLDebug("Loading user library type highlighter file " . lib['Path'], 'Information')
		exe 'so' lib['Path']
		let b:TagHighlightLoadedLibraries += [lib]
	endfor

	" Now load any libraries that are relevant
	let library_files = TagHighlight#Libraries#FindLibraryFiles(a:suffix)
	for lib in library_files
		call TagHLDebug("Loading standard library type highlighter file " . lib['Path'], 'Information')
		exe 'so' lib['Path']
		let b:TagHighlightLoadedLibraries += [lib]
	endfor

	" Handle any special cases
	if has_key(g:TagHighlightPrivate['SpecialSyntaxHandlers'], a:suffix)
		for handler in g:TagHighlightPrivate['SpecialSyntaxHandlers'][a:suffix]
			call TagHLDebug("Calling special handler " . handler, 'Information')
			exe 'call' handler . '()'
		endfor
	endif

	" Call Post Read Hooks (if any)
	let postread_hooks = TagHighlight#Option#GetOption('PostReadHooks')
	for postread_hook in postread_hooks
		call TagHLDebug("Calling post-read hook " . postread_hook, 'Information')
		exe 'call' postread_hook . '(fullname, a:suffix)'
	endfor

	" Restore the view
	call winrestview(savedView)
endfunction

function! TagHighlight#ReadTypes#FindTypeFiles(suffix)
	let results = []
	let search_result = TagHighlight#Find#LocateFile('TYPES', a:suffix)
	if search_result['Found'] == 1 && search_result['Exists'] == 1
		let results += [search_result['FullPath']]
	endif
	return results
endfunction
