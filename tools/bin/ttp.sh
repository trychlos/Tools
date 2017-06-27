#!/bin/ksh
# @(#) The Tools Project (TTP) management
#
# The Tools Project: a Tools System and Paradigm for IT Production
# Copyright (©) 2003-2017 Pierre Wieser (see AUTHORS)
#
# The Tools Project is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# The Tools Project is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with The Tools Project; see the file COPYING. If not,
# see <http://www.gnu.org/licenses/>.
#
# pwi 2012- 7-12 creation
# pwi 2017- 6-21 publish the release at last 

# In order to be able to honor the 'logical machine' paradigm, we have
#  to manage the in-process command ". ttp.sh switch --node <name>".
#  The run of this command depends of the TTP_SHDIR variable.
#
# When run in-process, the '$0' first argument is not the 'ttp.sh'
# command, but the running shell which is something like: '[-]<shell>'.
# Whether there is a leading dash ('-') or not indicates the presence
# of a login shell.
#
# If first character is '-',
#   - then we are in a login shell, which makes sure the command is
#     actually ". ttp.sh ..."
# else
#   - we are in a non-login shell, which does not say anything about
#     whether we have run ". ttp.sh .." or "ttp.sh ..."
#
# If running shell is Korn,
#   - this does not say anything about whether we have run
#     ". ttp.sh .." or "ttp.sh ..."
#   - FPATH will be honored, we so can call ttpf_main() as usual
# else
#   - we are in the user shell, which makes sure the command is actually
#     ". ttp.sh ..."
#   - we have to pre-load the function in a sub-environment.

#set -x
#echo "ttp.sh: 0=$0 #=$# *=$*" >&2

# the only allowed in-process invocation is the ". ttp.sh switch" command
# other in-process invocations may fall in error if FPATH is not honored
#  (in bash for example)
if [ "${0:0:1}" = "-" -o "${0}" = "${SHELL##*/}" ]; then
	[ "${1}" = "switch" ] && { . ${TTP_SHDIR%/*}/bootstrap/sh_switch "$(which ttp.sh 2>/dev/null)" "${@}"; return; }
fi

ttpf_main "${0}" "${@}"
