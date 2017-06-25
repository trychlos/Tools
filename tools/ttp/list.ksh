# @(#) list available commands and verbs
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
# pwi 2013- 2-19 creation
# pwi 2013- 7-10 add --verbs option
# pwi 2013- 7-18 review options dynamic computing
# pwi 2013- 7-30 fix #40: ttp.sh list -verbs also displays count of verbs
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
verbose		execute verbosely
commands	display list of commands
vars		display internal TTP variables
"
#verbs       display list of verbs (requires --commands)
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
#  first word is the name of the argument
#  rest of line is the help message
#
#function verb_arg_define_pos {
#	echo "
#"
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

	#set | grep -e '^opt_'
	# at least one option must be specified
	if [ "${opt_commands_set}" = "no" -a \
			"${opt_vars_set}" = "no" ]; then
				msgerr "no valid option found, but at least one is mandatory"
				let _ret+=1
	fi

	# --verbs requires --commands
	#if [ "${opt_verbs}" = "yes" -a "${opt_commands}" = "no" ]; then
	#	msgerr "'--verbs' option requires '--commands'"
	#	let _ret+=1
	#fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# listing commands and verbs
	#if [ "${opt_verbs}" = "yes" ]; then
	#	msgout "displaying available verbs..."
	#	typeset _dir
	#	typeset -i _commands=0
	#	typeset -i _cverbs=0
	#	for _dir in $(bspRootEnum); do
	#		LANG=C \ls -1 "${_dir}/${ttp_binsubdir}" 2>/dev/null | while read _file; do
	#			typeset _cmdpath="${_dir}/${ttp_binsubdir}/${_file}"
	#			if [ -x "${_cmdpath}" ]; then
	#				let _commands+=1
	#				varReset cverbs
	#				scriptDetail "${_cmdpath}" 1
	#				scriptListVerbs "${_cmdpath}" 1 cverbs "no"
	#				let _cverbs+=$(varGet cverbs)
	#			fi
	#		done
	#	done
	#	msgout "${_cverbs} verbs found"
	#	msgout "${_commands} commands found"

	# listing commands only
	if [ "${opt_commands}" = "yes" ]; then
		msgout "displaying available commands..."
		typeset _dir
		typeset -i _commands=0
		for _dir in $(bspRootEnum); do
			LANG=C \ls -1 "${_dir}/${ttp_binsubdir}" 2>/dev/null | while read _file; do
				typeset _cmdpath="${_dir}/${ttp_binsubdir}/${_file}"
				if [ -x "${_cmdpath}" ]; then
					let _commands+=1
					scriptDetail "${_cmdpath}" 1
				fi
			done
		done
		msgVerbose "${_commands} commands found"
	fi


	# listing internal TTP variables
	if [ "${opt_vars}" = "yes" ]; then
		msgout "displaying global TTP variables..."
		set | grep -e '^TTP_' | while read l; do echo " $l"; done
		msgout "displaying internal TTP variables..."
		set | grep -e '^ttp_' | while read l; do echo " $l"; done
	fi

	return ${_ret}
}
