# @(#) list elements
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
help						display this online help and gracefully exit
verbose						verbose execution
service=<identifier>		service identifier
database[=<name>]			list databases or tables
system						also show system databases
format={CSV|RAW|TABULAR}	output format (case insensitive)
headers						whether to display headers
counter						whether to display rows counter
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
	opt_system_def="yes"
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

	# the service identifier is mandatory
	if [ -z "${opt_service}" ]; then
		msgerr "service identifier is mandatory, has not been found"
		let _ret+=1
	fi

	# the '--database' option should be specified, either an argument or not
	if [ "${opt_database_set}" = "no" ]; then
		msgerr "'--database[=<name>]' option is expected, has not been found"
		let _ret+=1
	fi

	# the '--system' is only relevant when listing the databases
	if [ "${opt_database_set}" = "yes" -a ! -z "${opt_database}" -a "${opt_system_set}" = "yes" ]; then
		msgerr "'--[no]system' is only relevant when listing databases, ignored"
	fi

	# check output format
	disp_format="$(formatCheck "${opt_format}")"
	let _ret+=$?

	return ${_ret}
}

# ---------------------------------------------------------------------
# filter system databases if asked for

function f_filter_systemdb {
	if [ "${opt_system}" = "yes" ]; then
		cat -
	else
		#grep -vwE 'information_schema|[^\[]mysql|performance_schema|test[^]]'
		# shouldn't filter "[mysql.sh test] " prefix,
		#  nor "mysql.sh test " command
		awk -v headers=${opt_headers} -v prefix="$(msgoutPrefix)" '
			BEGIN { count=0 }
			/[[:digit:]] displayed row/ { next }
			/^\[|^+/ { print; next }
			!/information_schema|mysql|performance_schema|test/ { print; count+=1; next }
			END { printf( "%s%d displayed row(s)\n", prefix, match( headers, "yes" ) ? count-1 : count ) }'
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
			typeset _headers="--headers"
			[ "${opt_headers}" = "no" ] && _headers="--noheaders"
			typeset _counter="--counter"
			[ "${opt_counter}" = "no" ] && _counter="--nocounter"

			# if no value is provided to the --database option,
			#  then list databases
			if [ -z "${opt_database}" ]; then
				mysql.sh sql \
					-service ${opt_service} \
					-command "show databases" \
					-format ${opt_format} \
					${_headers} ${_counter} | f_filter_systemdb
	
			# if a database is specified, then list tables
			else
				mysql.sh sql \
					-service ${opt_service} \
					-command "use ${opt_database}; show tables" \
					-notest \
					-format ${opt_format} \
					${_headers} ${_counter}
			fi
		fi
	fi

	return ${_ret}
}
