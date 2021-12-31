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
# pwi 2021-12-30 only add CSV format, leaving json to ttp.sh filter

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
verbose						verbose execution
service=<identifier>		service identifier
command=<command>			command to be executed
script=</path>				script SQL to be executed
interactive					open an interactive connection
user=<user>					connection account
timeout=<sec>				timeout
test						test that the service is up and running before executing
counter						whether to display a data rows counter
headers						whether to display headers
csv							display output in CSV format
separator					(CSV output) separator
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
	opt_counter_def="yes"
	opt_csv_def="no"
	opt_separator_def="${ttp_csvsep}"
	opt_headers_def="yes"
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
		msgErr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	typeset -i _action=0
	[ "${opt_command_set}" = "yes" ] && let _action+=1
	[ "${opt_script_set}" = "yes" ] && let _action+=1
	[ "${opt_interactive_set}" = "yes" ] && let _action+=1

	# command, script or interactive
	if [ ${_action} -eq 0 ]; then
		msgErr "one of '--command', '--script' or '--interactive' options must be specified"
		let _ret+=1
	elif [ ${_action} -gt 1 ]; then
		msgErr "only one of '--command', '--script' or '--interactive' options must be specified"
		let _ret+=1
	fi

	# if a script is specified, check that it exists
	if [ "${opt_script_set}" = "yes" ]; then
		if [ ! -r "${opt_script}" ]; then
			msgErr "${opt_script}: script not found or not readable"
			let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# sql client defauts to not output any data rows counter
# add it here

function f_add_counter {
	typeset _ftemp="${1}"
	typeset -i _count=$(wc -l ${_ftemp} | awk '{ print $1 }')
	let _count-=4
	msgOut "${_count} displayed data row(s)" >> "${_ftemp}"
}

# ---------------------------------------------------------------------
# sql client defauts to a tabular output with headers
# remove then here

function f_remove_headers {
	typeset _ftemp="${1}"
	typeset _ftail="$(pathGetTempFile tail)"
	cat "${_ftemp}" | tail -n +3 > "${_ftail}"
	mv "${_ftail}" "${_ftemp}"
}

# ---------------------------------------------------------------------
# format the output
#	sql client defaults to display its output in tabular form

function f_output {
	#set -x

	if [ "${opt_csv}" == "yes" ]; then

		typeset _inheaders="${opt_headers}"
		typeset _insep="\|"
		typeset _outcols="ALL"
		typeset _outfmt="CSV"
		typeset _outheaders="${opt_headers}"
		typeset _outnames=""
		typeset _outsep="${opt_separator}"
		typeset _screenwidth="yes"
		typeset _prefixed="no"
		typeset _counter="${opt_counter}"
		typeset -i _maxcount=-1

		filterFromTabular \
			"${opt_verbose}" \
			"${_inheaders}" "${_insep}" \
			"${_outcols}" "${_outfmt}" "${_outheaders}" "${_outnames}" "${_outsep}" \
			"${_screenwidth}" "${_prefixed}" "${_counter}" "${_maxcount}"

	else
		cat -
	fi
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
			msgErr "${opt_service}: service is of '${_type}' type, while 'mysql' was expected"
			let _ret+=1

		else
			# check that the instance is running
			if [ "${opt_test}" = "yes" ]; then
				mysql.sh test -service "${opt_service}" -nostatus
				if [ $? -ne 0 ]; then
					msgErr "${opt_service}: DBMS instance is not running"
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
					if [ ${_ret} -eq 0 ]; then
						[ "${opt_counter}" == "yes" ] && f_add_counter "${_ftemp}"
						[ "${opt_headers}" == "no" ] && f_remove_headers "${_ftemp}"
						cat "${_ftemp}" | f_output
						let _ret+=$?
					fi

				# execute a SQL script
				elif [ "${opt_script_set}" = "yes" ]; then
					_ftemp="$(pathGetTempFile command)"
					cat "${opt_script}" | mysql -n \
						-u${opt_user} \
						-p$(dbmsGetPassword "${opt_service}" "${ttp_node_environment}" "${opt_user}") \
						--table >"${_ftemp}"
					let _ret+=$?
					if [ ${_ret} -eq 0 ]; then
						[ "${opt_counter}" == "yes" ] && f_add_counter "${_ftemp}"
						[ "${opt_headers}" == "no" ] && f_remove_headers "${_ftemp}"
						cat "${_ftemp}" | f_output
						let _ret+=$?
					fi

				else
					msgErr "no managed action"
					let _ret+=1
				fi
			fi
		fi
	fi

	return ${_ret}
}
