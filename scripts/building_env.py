# MIT License
#
# Copyright (c) 2015-2023 The ViaDuck Project
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# creates a building environment for openssl
# - working directory
# - on windows: uses msys' bash for command execution (openssl's scripts need an UNIX-like environment with perl)

import argparse
import os, re
from subprocess import PIPE, Popen
from sys import exit

parser = argparse.ArgumentParser()
parser.add_argument('-v', '--verbose', action='store_true')
parser.add_argument('--bash', nargs='?')
parser.add_argument('--make', nargs='?')
parser.add_argument('--envfile')
parser.add_argument('os')
parser.add_argument('cwd')
parser.add_argument('args', nargs='+')
args = parser.parse_args()

if args.verbose:
    print(args)

env = os.environ
env_sep = ';' if args.os == 'WIN32' else ':'

def add_env(k, v):
    global env

    if k == 'PATH':
        env[k] = v + ('' if v.endswith(env_sep) else env_sep) + env[k]
    else:
        env[k] = v

    if args.verbose:
        print(f'Updated env[{k}] to "{v}"')

# add bash and make directories to path if specified
if args.bash is not None and len(args.bash) > 0:
    add_env('PATH', os.path.dirname(args.bash))
if args.make is not None and len(args.make) > 0:
    add_env('PATH', os.path.dirname(args.make))

# os-specifics
if args.os == 'WIN32':
    # otherwise: internal error: invalid --jobserver-fds string `gmake_semaphore_1824'
    add_env('MAKEFLAGS', '')
elif args.os == 'LINUX_CROSS_ANDROID':
    # parse A="B" where B has all quotes escaped
    pattern = re.compile(r'^(.*?)="((?:\\.|[^"\\])*)"', re.MULTILINE | re.DOTALL)

    # parse env vars from file
    with open(args.envfile, 'r') as f:
        content = f.read()

    # unescape and save all env vars
    for k, v in pattern.findall(content):
        add_env(k, v.replace("\\\"", "\""))

# build command-line
cmd_exec, cmd_args = args.args[0], ' '.join(args.args[1:])
cmd_line = f'"{cmd_exec}" {cmd_args} || exit $?'

if args.verbose:
    print(f'Built cmd_line = "{cmd_line}"')

proc = None
if args.os == 'WIN32':
    # we must emulate a UNIX environment to build openssl using mingw
    proc = Popen(bash, env=env, cwd=args.cwd, stdin=PIPE, universal_newlines=True)
    proc.communicate(input=cmd_line)
else:
    proc = Popen(cmd_line, env=env, cwd=args.cwd, shell=True)
    proc.communicate()

exit(proc.returncode)
