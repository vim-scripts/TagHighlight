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
	if &cp || (exists('g:loaded_TagHLVersion') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLVersion = 1

function! TagHighlight#Version#LoadVersionInfo()
	if has_key(g:TagHighlightPrivate, 'PluginVersion')
		return
	endif

	let g:TagHighlightPrivate['PluginVersion'] = {}
	
	let last_release_info = TagHighlight#LoadDataFile#LoadDataFile('release.txt')
	let g:TagHighlightPrivate['PluginVersion']['LastRelease'] = last_release_info['release']

	try
		let release_version_info = TagHighlight#LoadDataFile#LoadDataFile('version_info.txt')
		let g:TagHighlightPrivate['PluginVersion']['VersionInfo'] = release_version_info
	catch /^Vim\%((\a\+)\)\=:E484/
		" Not a release version
		let g:TagHighlightPrivate['PluginVersion']['VersionInfo'] =
					\ {
					\    'release_clean': 'N/A',
					\    'release_date': 'N/A',
					\    'release_revid': 'N/A'
					\ }
	endtry
endfunction
