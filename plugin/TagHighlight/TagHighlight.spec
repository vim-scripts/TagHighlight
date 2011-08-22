# -*- mode: python -*-
# Work out what language files are needed
a = Analysis([os.path.join(HOMEPATH,'support/_mountzlib.py'), os.path.join(HOMEPATH,'support/useUnicode.py'), 'TagHighlight.py'],
        pathex=['.'])
version_data = []#[('version_info.txt','data/version_info.txt','DATA')]
pyz = PYZ(a.pure)
import sys
if sys.platform.startswith('win'):
    exe_name = 'TagHighlight.exe'
    compile_dir = 'Compiled/Win32'
elif sys.platform.startswith('linux'):
    exe_name = 'TagHighlight'
    compile_dir = 'Compiled/Linux'

exe = EXE(pyz,
        a.scripts,
        exclude_binaries=1,
        name=os.path.join('build/', exe_name),
        debug=False,
        strip=False,
        upx=True,
        console=True )
coll = COLLECT( exe,
        a.binaries,
        a.zipfiles,
        a.datas,
        version_data,
        strip=False,
        upx=True,
        name=compile_dir)

# vim: ft=python
