# creates a building environment for openssl
# - working directory
# - on windows: uses msys' bash for command execution (openssl's scripts need an UNIX-like environment with perl)

from subprocess import PIPE, Popen
from sys import argv, exit
import os, re

env = os.environ
l = []

os_s = argv[1]                                      # operating system
offset = 2          # 0: this script's path, 1: operating system

if os_s == "WIN32":
    offset = 4  # 2: MSYS_BASH_PATH, 3: CMAKE_MAKE_PROGRAM

    #
    bash = argv[2]
    msys_path = os.path.dirname(bash)
    mingw_path = os.path.dirname(argv[3])

    # append ; to PATH if needed
    if not env['PATH'].endswith(";"):
        env['PATH'] += ";"

    # include path of msys binaries (perl, cd etc.) and building tools (gcc, ld etc.)
    env['PATH'] = ";".join([msys_path, mingw_path])+";"+env['PATH']
    env['MAKEFLAGS'] = ''            # otherwise: internal error: invalid --jobserver-fds string `gmake_semaphore_1824'


binary_openssl_dir_source = argv[offset]+"/"             # downloaded openssl source dir
l.extend(argv[offset+1:])                             # routed commands

l[0] = '"'+l[0]+'"'

# read environment from file if cross-compiling
if os_s == "LINUX_CROSS_ANDROID":
    expr = re.compile('^(.*?)="(.*?)"', re.MULTILINE | re.DOTALL)
    f = open(binary_openssl_dir_source+"/../../../buildenv.txt", "r")
    content = f.read()
    f.close()

    for k, v in expr.findall(content):
        if k != "PATH":
            env[k] = v.replace('"', '')
        else:
            env[k] = v.replace('"', '')+":"+env[k]

proc = None
if os_s == "WIN32":
    # we must emulate a UNIX environment to build openssl using mingw
    proc = Popen(bash, env=env, cwd=binary_openssl_dir_source, stdin=PIPE, universal_newlines=True)
    proc.communicate(input=" ".join(l)+" || exit $?")
else:
    proc = Popen(" ".join(l)+" || exit $?", shell=True, env=env, cwd=binary_openssl_dir_source)
    proc.communicate()

exit(proc.returncode)
