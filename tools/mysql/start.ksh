# @(#) start the service
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
# gmi 2005- 6-13 creation
# pwi 2006-10-27 tools become The Tools Project, released under GPL
# pwi 2013- 6-28 port to Tools v2
# pwi 2013- 7-18 review options dynamic computing
# pwi 2017- 6-21 publish the release at last
# pwi 2021-12-28 improve verbose execution

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help						display this online help and gracefully exit
dummy						dummy execution
verbose						verbose execution
service=<identifier>		service identifier
"
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
	#set -x
	typeset -i _ret=0

	# the service identifier is mandatory
	if [ -z "${opt_service}" ]; then
		msgErr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# check which node hosts the required service
	typeset _node="$(tabGetNode "${opt_service}")"
	if [ -z "${_node}" ]; then
		msgErr "'${opt_service}': no hosting node found (environment='${ttp_node_environment}')"
		let _ret+=1

	elif [ "${_node}" != "${TTP_NODE}" ]; then
		typeset _parms="$@"
		execRemote "${_node}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	# we are on the right node
	else
		# check the service type
		typeset _type="$(confGetKey ttp_node_keys ${opt_service} 0=service 1)"
		if [ "${_type}" != "mysql" ]; then
			msgErr "${opt_service}: service is of '${_type}' type, while 'mysql' was expected"
			let _ret+=1

		else
			# does this command requires a specific account ?
			typeset _user="$(confGetKey ttp_node_keys ${opt_service} 0=start 1)"
			if [ ! -z "${_user}" -a "${_user}" != "${ttp_user}" ]; then
				typeset _parms="$@"
				execRemote "${TTP_NODE}" "${ttp_command} ${ttp_verb} ${_parms}" "${_user}"
				let _ret+=$?

			else
				# we are on the right node with the right account
				# setup the environment
				serviceSetenv "${opt_service}"
	
				# check that the instance is not running
				mysql.sh test -service "${opt_service}" -nostatus 1>/dev/null 2>&1
				if [ $? -eq 0 ]; then
					msgOut "${opt_service}: service is already up and running"
	
				# start the instance, and re-check
				else
					typeset _cmd
					confGetKey ttp_node_keys ${opt_service} 0=start 2 | while read _cmd; do
						[ "${opt_verbose}" == "yes" ] && msgVerbose "command: ${_cmd}"
						execDummy "eval "${_cmd}" 1>/dev/null"
						let _ret+=$?
					done
					mysql.sh test -service "${opt_service}" -nostatus 1>/dev/null 2>&1
					if [ $? -eq 0 ]; then
						msgOut "${opt_service}: service is successfully started"
					else
						msgErr "${opt_service}: unable to start the service"
						let _ret+=1
					fi
				fi
			fi
		fi
	fi

	return ${_ret}
}
