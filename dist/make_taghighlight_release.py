#!/usr/bin/python
from __future__ import print_function

import os
import sys
import zipfile
import fnmatch
import subprocess

vimfiles_dir = os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))

import socket
hostname = socket.gethostname()

GIT=["git"]

# Recursive glob function, from
# http://stackoverflow.com/questions/2186525/use-a-glob-to-find-files-recursively-in-python#2186565
def Rglob(path, match):
    matches = []
    for root, dirnames, filenames in os.walk(path):
        for filename in fnmatch.filter(filenames, match):
            matches.append(os.path.join(root, filename))
    return matches

def UpdateReleaseVersion():
    release_file = os.path.join(vimfiles_dir,'plugin/TagHighlight/data/release.txt')
    fh = open(release_file,'r')
    lines = [i for i in fh]
    fh.close()
    release = 'INVALID'
    fh = open(release_file, 'wb')
    for line in lines:
        if line.startswith('release:'):
            parts = line.strip().split(':')
            numbers = [int(i) for i in parts[1].split('.')]
            release = '{0}.{1}.{2}'.format(numbers[0],numbers[1],numbers[2]+1)
            fh.write('release:'+release+'\n')
        else:
            fh.write(line.strip() + '\n')
    fh.close()
    return release

version_info_initial = ['log','-1',"--format=format:release_revid:%H%nrelease_date:%ad","--date=iso"]
clean_info = ['status', '--porcelain']

def GenerateVersionInfo():
    version_file = os.path.join(vimfiles_dir,'plugin/TagHighlight/data/version_info.txt')

    args = GIT + clean_info
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout,stderr) = p.communicate()

    status_lines = stdout
    if len(status_lines) > 0:
        clean = False
        clean_line = "release_clean:0"
    else:
        clean = True
        clean_line = "release_clean:1"

    args = GIT + version_info_initial
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout,stderr) = p.communicate()

    # Write as binary for consistent line endings
    fh = open(version_file, 'wb')
    fh.write(clean_line + "\n")

    for line in stdout.split('\n'):
        if line.startswith('release_'):
            fh.write(line + '\n')
    fh.close()

    return version_file, clean

def MakeMainRelease(r):
    # List of paths to include (either explicit files or paths to search)
    paths = {
            '.py': ['plugin/TagHighlight',__file__],
            '.vim': ['plugin/TagHighlight.vim','autoload/TagHighlight'],
            '.txt': ['plugin/TagHighlight/data','plugin/TagHighlight/instructions.txt', 'doc/TagHighlight.txt'],
            '.spec': ['plugin/TagHighlight/TagHighlight.spec'],
            }
    filename = 'taghighlight_r{0}.zip'.format(r)
    MakeZipFile(filename, paths)

def MakeZipFile(filename, paths):
    # Create the zipfile
    zipf = zipfile.ZipFile(os.path.join(vimfiles_dir, 'dist', filename), 'w')

    # Collect the specified paths into a zip file
    for ext, pathlist in paths.items():
        for path in pathlist:
            # Get the full path (specified relative to vimfiles directory)
            full_path = os.path.join(vimfiles_dir, path)
            if os.path.exists(full_path):
                if os.path.isfile(full_path):
                    files = [full_path]
                elif os.path.isdir(full_path):
                    files = Rglob(full_path, '*' + ext)
                else:
                    print("Unrecognised path: " + full_path)

                if len(files) > 0:
                    for f in files:
                        dirname = os.path.dirname(os.path.relpath(f,vimfiles_dir))
                        zipf.write(f,os.path.join(dirname, os.path.basename(f)), zipfile.ZIP_DEFLATED)
                else:
                    print("No files found for path: " + full_path)
            else:
                print("Path does not exist: " + full_path)
    # Close the zipfile
    zipf.close()

def MakeLibraryPackage(r):
    paths = {
            '.txt': ['plugin/TagHighlight/standard_libraries'],
            '.taghl': ['plugin/TagHighlight/standard_libraries'],
            }
    filename = 'taghighlight_standard_libraries_r{0}.zip'.format(r)
    MakeZipFile(filename, paths)

def MakeCompiled(pyexe, pyinstaller_path, zipfilename, platform_dir):
    initial_dir = os.getcwd()
    os.chdir(os.path.join(vimfiles_dir, 'plugin/TagHighlight'))
    args = pyexe + [os.path.join(pyinstaller_path, 'Build.py'), '-y', 'TagHighlight.spec']
    p = subprocess.Popen(args)#, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout,stderr) = p.communicate()
    zipf = zipfile.ZipFile(os.path.join(vimfiles_dir,'dist',zipfilename), 'w')
    for f in Rglob(os.path.join(vimfiles_dir,'plugin/TagHighlight/Compiled/'+platform_dir),'*'):
        dirname = os.path.dirname(os.path.relpath(f,vimfiles_dir))
        zipf.write(f,os.path.join(dirname, os.path.basename(f)), zipfile.ZIP_DEFLATED)
    zipf.close()
    os.chdir(initial_dir)

def MakeWin32Compiled(r):
    if 'WINPYTHON' in os.environ:
        # Doesn't work with spaces in the path
        # (doing the split to allow for running python
        # with wine).
        pyexe = os.environ['WINPYTHON'].split(' ')
    else:
        pyexe = ['python.exe']
    pyinstaller_path = os.environ['WINPYINSTALLERDIR']
    MakeCompiled(pyexe, pyinstaller_path, 'taghighlight_r{0}_win32.zip'.format(r), 'Win32')

def MakeLinuxCompiled(r):
    if 'PYTHON' in os.environ:
        # Doesn't work with spaces in the path
        # (doing the split to allow for running python
        # with wine).
        pyexe = os.environ['PYTHON']
    else:
        pyexe = ['python']
    pyinstaller_path = os.environ['PYINSTALLERDIR']
    MakeCompiled(pyexe, pyinstaller_path, 'taghighlight_r{0}_linux.zip'.format(r), 'Linux')

def CheckInChanges(r):
    args = GIT+['add','plugin/TagHighlight/data/release.txt']
    p = subprocess.Popen(args)
    (stdout,stderr) = p.communicate()
    args = GIT+['commit','-m','Release build {0}'.format(r)]
    p = subprocess.Popen(args)
    (stdout,stderr) = p.communicate()
    args = GIT+['tag','taghighlight-release-{0}'.format(r)]
    p = subprocess.Popen(args)
    (stdout,stderr) = p.communicate()
    args = GIT+['push','origin','master','--tags']
    p = subprocess.Popen(args)
    (stdout,stderr) = p.communicate()

def PublishReleaseVersion():
    # TODO
    # This function will be used to push generated files to a remote location
    # to make them available on the web
    pass

def main():
    version_file, clean = GenerateVersionInfo()

    if clean:
        new_release = UpdateReleaseVersion()
        MakeMainRelease(new_release)
        os.remove(version_file)
        MakeWin32Compiled(new_release)
        MakeLinuxCompiled(new_release)
        MakeLibraryPackage(new_release)
        CheckInChanges(new_release)
        PublishReleaseVersion()
    else:
        print("Distribution not clean: check into Git before making release.")
        os.remove(version_file)


if __name__ == "__main__":
    main()
