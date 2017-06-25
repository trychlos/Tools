# @(#) provides various informations about an Oracle instance
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
# pwi 2002- 9-29 creation
# pwi 2002-10-24 add current processes informations
# pwi 2003- 3-17 remove asterisk when displaying version number
# cm  2004- 7-30 add tablespace use
# cm  2006  2-21 generate metrics
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6-10 migrate to command-line dynamic interpretation scheme
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
service=<identifier>	service identifier
events					display 'SY'-prefixed system events
iostats					display 'FS'-prefixed I/O file statistics
parameters				display 'PA'-prefixed current instance parameters
processes				display 'PR'-prefixed currently running processes
segments[=user|sys]		display 'US'/'SS'-prefixed user/system segments size
sga						display 'SG'-prefixed SGA usage
tablescan				display 'TC'-prefixed table scans
tablespaces				display 'TS'-prefixed tablespaces usage
version					display 'VR'-prefixed server components version levels
metrics[=<file>]		output as semi-colon separated data
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments
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
	opt_segments_def="user"
	opt_metrics_def="-"
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
		msgerr "service mnemonic is mandatory, was not found"
		let _ret+=1
	fi

	# at least one option must be specified
	if [ "${opt_events}" = "no" -a \
			"${opt_iostats}" = "no" -a \
			"${opt_parameters}" = "no" -a \
			"${opt_processes}" = "no" -a \
			"${opt_segments_set}" = "no" -a \
			"${opt_sga}" = "no" -a \
			"${opt_tablescan}" = "no" -a \
			"${opt_tablespaces}" = "no" -a \
			"${opt_version}" = "no" ]; then
				msgerr "no option found, at least one is mandatory"
				let _ret+=1
	fi

	# check the value specified with '--opt_segments' option (if any)
	if [ "${opt_segments_set}" = "yes" ]; then
		typeset _value="$(echo "${opt_segments}" | strUpper)"
		case "${_value}" in
			USER|SYS)
				opt_segments="${_value}"
				;;
			*)
				msgerr "'${opt_segments}': invalid value for '--segments' option"
				let _ret+=1
				;;
		esac
	fi

	# '--metrics' is only allowed with some options that we known how
	#  to parse, other options are just displayed as is without being
	#  piped through optMetrics
	if [ "${opt_metrics_set}" = "yes" ]; then
		if [ "${opt_events}" != "yes" -a \
				"${opt_iostats}" != "yes" -a \
				"${opt_parameters}" != "yes" -a \
				"${opt_processes}" != "yes" -a \
				"${opt_segments_set}" != "yes" -a \
				"${opt_sga}" != "yes" -a \
				"${opt_tablescan}" != "yes" -a \
				"${opt_tablespaces}" != "yes" -a \
				"${opt_version}" != "yes" ]; then
					msgerr "'--metrics' option not supported for required information"
					let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	typeset -i _ret=0

	# check which machine hosts the required service
	typeset _host="$(tabGetMachine "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgerr "'${opt_service}': unknown service mnemonic"
		let _ret+=1

	# TODO: it should not be required to get informations to be on the
	#  server while Oracle provides a listener for managing the
	#  connection - but this also means that we have a server
	#  environment and a client environment
	elif [ "${_host}" != "${ttp_logical}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	else
		#set | grep -e '^opt_'

		# this machine host the required service

		if [ "${opt_events}" = "yes" ]; then
			oraSystemEvents "${opt_service}"
		fi

		if [ "${opt_iostats}" = "yes" ]; then
			oraIOFileStats "${opt_service}"
		fi

		if [ "${opt_parameters}" = "yes" ]; then
			oraShowParameters "${opt_service}"
		fi

		if [ "${opt_processes}" = "yes" ]; then
			oraProcesses "${opt_service}"
		fi

		if [ "${opt_segments_set}" = "yes" ]; then
			oraSegments "${opt_service}" "${opt_segments}"
		fi

		if [ "${opt_sga}" = "yes" ]; then
			oraSgaStats "${opt_service}"
		fi

		if [ "${opt_tablescan}" = "yes" ]; then
			oraTableScan "${opt_service}"
		fi

		if [ "${opt_tablespaces}" = "yes" ]; then
			oraTablespaces "${opt_service}"
		fi

		if [ "${opt_version}" = "yes" ]; then
			oraComponentsVersion "${opt_service}"
		fi
	fi

	return ${_ret}
}
