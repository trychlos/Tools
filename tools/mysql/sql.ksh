#!/bin/ksh
# @(#) execute a SQL command
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
# pwi 2017- 6-21 publish the release at last 

disp_format=""

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
command=<command>			command to be executed
script=</path>				script SQL to be executed
interactive					open an interactive connection
user=<user>					connection account
timeout=<sec>				timeout
test						test that the service is up and running before executing
format={CSV|RAW|TABULAR}	output format (case insensitive)
headers						whether to display headers (in CSV and TABULAR formats)
counter						whether to display rows counter (in CSV and TABULAR formats)
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
	opt_timeout_def=0
	opt_user_def="root"
	opt_test_def="yes"
	opt_format_def="RAW"
	opt_headers_def="yes"
	opt_counter_def="yes"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# the service mnemonic is mandatory
	if [ -z "${opt_service}" ]; then
		msgerr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	typeset -i _action=0
	[ "${opt_command_set}" = "yes" ] && let _action+=1
	[ "${opt_script_set}" = "yes" ] && let _action+=1
	[ "${opt_interactive_set}" = "yes" ] && let _action+=1

	# command, script or interactive
	if [ ${_action} -eq 0 ]; then
		msgerr "one of '--command', '--script' or '--interactive' options must be specified"
		let _ret+=1
	elif [ ${_action} -gt 1 ]; then
		msgerr "only one of '--command', '--script' or '--interactive' options must be specified"
		let _ret+=1
	fi

	# if a script is specified, check that it exists
	if [ "${opt_script_set}" = "yes" ]; then
		if [ ! -r "${opt_script}" ]; then
			msgerr "${opt_script}: script not found or not readable"
			let _ret+=1
		fi
	fi

	# '--[no]headers' and '--[no]counter' are only relevant when the
	#  format is not 'RAW'
	if [ "${opt_headers_set}" = "yes" -a "${opt_format}" = "RAW" ]; then
		msgwarn "'--[no]headers' option is only relevant with 'CSV' or 'TABULAR' format, ignored"
		unset opt_headers
		opt_headers_set="no"
	fi
	if [ "${opt_counter_set}" = "yes" -a "${opt_format}" = "RAW" ]; then
		msgwarn "'--[no]counter' option is only relevant with 'CSV' or 'TABULAR' format, ignored"
		unset opt_counter
		opt_counter_set="no"
	fi

	# check output format
	disp_format="$(formatCheck "${opt_format}")"
	let _ret+=$?

	return ${_ret}
}

# ---------------------------------------------------------------------
# format the output

function f_output {
	#set -x

	if [ "${disp_format}" = "CSV" ]; then
		dbmsToCsv "${opt_service}" "${opt_headers}" "${opt_counter}"

	elif [ "${disp_format}" = "RAW" ]; then
		cat -

	elif [ "${disp_format}" = "TABULAR" ]; then
		dbmsToCsv "${opt_service}" "yes" "no" \
			| csvToTabular "${opt_headers}" "${opt_counter}"
	fi
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
		typeset _parms=""
		if [ "${opt_script_set}" = "yes" ]; then
			typeset _destfic="$(ficCopyToTemp "${TTP_NODE}" "${opt_script}" "${_node}")"
			_parms="--service "${opt_service}" --script "${_destfic}""
			[ "${opt_user_set}" = "yes" ] && _parms="${_parms} --user="${opt_user}""
			[ "${opt_timeout_set}" = "yes" ] && _parms="${_parms} --timeout="${opt_timeout}""
		else
			_parms="$@"
		fi
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
			# check that the instance is running
			if [ "${opt_test}" = "yes" ]; then
				mysql.sh test -service "${opt_service}" -nostatus
				if [ $? -ne 0 ]; then
					msgerr "${opt_service}: DBMS instance is not running"
					let _ret+=1
				fi
			fi
			if [ ${_ret} -eq 0 ]; then
				serviceSetenv "${opt_service}"
				typeset _ftemp

				# interactive connection to mysql client
				# -n, --unbuffered: Flush the buffer after each query.
				if [ "${opt_interactive}" = "yes" ]; then
					mysql -n \
						-u${opt_user} \
						-p$(dbmsGetPassword "${opt_service}" "${ttp_node_environment}" "${opt_user}")
					let _ret+=$?

				# execute a command passed as an argument
				elif [ "${opt_command_set}" = "yes" ]; then
					_ftemp="$(pathGetTempFile command)"
					mysql \
						-u${opt_user} \
						-p$(dbmsGetPassword "${opt_service}" "${ttp_node_environment}" "${opt_user}") \
						-e "${opt_command}" \
						--table >"${_ftemp}"
					let _ret+=$?
					[ ${_ret} -eq 0 ] && cat "${_ftemp}" | f_output
					let _ret+=$?

				# execute a SQL script
				elif [ "${opt_script_set}" = "yes" ]; then
					cat "${opt_script}" | mysql -n \
						-u${opt_user} \
						-p$(dbmsGetPassword "${opt_service}" "${ttp_node_environment}" "${opt_user}") \
						--table >"${_ftemp}"
					let _ret+=$?
					[ ${_ret} -eq 0 ] && cat "${_ftemp}" | f_output
					let _ret+=$?

				else
					msgerr "no managed action"
					let _ret+=1
				fi
			fi
		fi
	fi

	return ${_ret}
}
