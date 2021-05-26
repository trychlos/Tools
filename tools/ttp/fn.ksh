# @(#) call a function with arguments
#
# The Tools Project: a Tools System and Paradigm for IT Production
# Copyright (©) 2003-2021 Pierre Wieser (see AUTHORS)
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
# pwi 2013- 2-26 creation
# pwi 2013- 7-18 review options dynamic computing
# pwi 2013- 7-30 fix #41: fix positional arguments list
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
help		display this online help and gracefully exit
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
#  first word is the name of the argument
#  rest of line is the help message

function verb_arg_define_pos {
	echo "
fn			name of the function to be called
[args]		arguments of the function
"
}

# ---------------------------------------------------------------------
# define a no-op verb_arg_read_pos function in order for our arguments
#  to not be checked by the Tools

#function verb_arg_read_pos {
#	echo "" > /dev/null
#}

# ---------------------------------------------------------------------
# initialize specific default values
#
#function verb_arg_set_defaults {
#}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# check that a function name is provided
	if [ -z "${pos_fn}" ]; then
		msgerr "a function name must be provided"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# function name is the first argument
	#  other arguments are to be passed to the function
	shift
	"${pos_fn}" "$@"
	_ret=$?

	return ${_ret}
}
