# @(#) test the service
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
# gmi 2005- 6-13 creation
# pwi 2006-10-27 tools become The Tools Project, released under GPL
# pwi 2013- 6-28 port to Tools v2
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
help					display this online help and gracefully exit
verbose					verbose execution
service=<identifier>	service identifier
status					also check the intern DBMS status
showtest				show the output of 'test' service lines
showstatus				show the output of the intern DBMS status check
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

function verb_arg_set_defaults {
	opt_status_def="yes"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# the service identifier is mandatory
	if [ -s "${opt_service}" ]; then
		msgerr "service identifier is mandatory, has not been found"
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
		msgerr "'${opt_service}': no hosting node found (environment='${ttp_node_environment}')"
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
			msgerr "${opt_service}: service is of '${_type}' type, while 'mysql' was expected"
			let _ret+=1

		else
			# does this command requires a specific account ?
			typeset _user="$(confGetKey ttp_node_keys ${opt_service} 0=test 1)"
			if [ ! -z "${_user}" -a "${_user}" != "${ttp_user}" ]; then
				typeset _parms="$@"
				execRemote "${TTP_NODE}" "${ttp_command} ${ttp_verb} ${_parms}" "${_user}"
				let _ret+=$?

			else
				# we are on the right node with the right account
				# setup the environment
				mySetenv "${opt_service}"
	
				# execute the test commands list
				typeset _cmd
				typeset _line
				typeset _ftmptest="$(pathGetTempFile test)"
				confGetKey ttp_node_keys ${opt_service} 0=test 2 | while read _cmd; do
					eval "${_cmd}" 1>>"${_ftmptest}"
					let _ret+=$?
				done
				if [ "${opt_showtest}" = "yes" ]; then
					cat "${_ftmptest}" | while read _line; do echo " test: "${_line}""; done
				fi

				# if all is ok, also tries to connect to the dbms itself
				if [ ${_ret} -eq 0 -a "${opt_status}" = "yes" ]; then
					typeset _ftmpstatus="$(pathGetTempFile status)"
					mysql.sh sql -service ${opt_service} -interactive 1>>"${_ftmpstatus}" <<!
use mysql;
show status;
!
					let _ret+=$?
				fi
				if [ "${opt_showstatus}" = "yes" ]; then
					cat "${_ftmpstatus}" | while read _line; do echo " status: "${_line}""; done
				fi
				if [ ${_ret} -eq 0 ]; then
					msgout "${opt_service}: service is up and running"
				fi
			fi
		fi
	fi

	return ${_ret}
}
