# @(#) test different sort of optional and positional arguments
#
# @(@) last, display a post-help block message
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
# pwi 2013- 6- 7 creation
# pwi 2013- 7-18 review options dynamic computing
# pwi 2017- 6-21 publish the release at last 

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help				display this online help and gracefully exit
verbose				verbose execution
command=<name>		execute the named command
status[=<status>]	check for the given status
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
#  first word is the name of the argument
#  rest of line is the help message

function verb_arg_define_pos {
	echo "
file		input from a file
[dir]		output to a directory
"
}

# ---------------------------------------------------------------------
# initialize specific default values

function verb_arg_set_defaults {
	pos_dir_def="/tmp"
	opt_status_def="ALL"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0
	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	typeset -i _ret=0

	set | grep -E '^opt_|^pos_'

	return ${_ret}
}
