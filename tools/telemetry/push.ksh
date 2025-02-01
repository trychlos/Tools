# @(#) push a metric to the push gateway
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
# pwi 2025- 2- 1 creation

# ---------------------------------------------------------------------
# global variables
#  will be set in verb_arg_check, used in verb_main

disp_columns=""

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory value
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help								display this online help and gracefully exit
verbose								verbose execution
service=<identifier>				service identifier
name=<name>							the metric name
value=<value						the metric (numeric) value
label='<name>=<value>'				a label to qualify the metric
"
}

# ---------------------------------------------------------------------
# echoes the list of positional arguments if any
#  first word is the name of the argument
#  rest of line is the help message
#
#function verb_arg_define_pos {
#	echo "
#repo		svn repository name
#"
#}

# ---------------------------------------------------------------------
# initialize specific default values

function verb_arg_set_defaults {
	opt_service_def=""
	opt_name_def=""
	opt_value_def="0"
	opt_label_def=""
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
		msgErr "service identifier is mandatory, was not found"
		let _ret+=1
	fi

	# columns, headers or format have only sense when listing repositories
	#if [ "${opt_columns_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgErr "--columns option has only sense when listing repositories"
	#	let _ret+=1
	#fi
	#if [ "${opt_headers_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgErr "--headers option has only sense when listing repositories"
	#	let _ret+=1
	#fi
	#if [ "${opt_format_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgErr "--format option has only sense when listing repositories"
	#	let _ret+=1
	#fi

	# set displayed columns along with display order
	typeset _col
	for _col in $(echo "${opt_columns}" | strUpper | sed -e 's/,/ /g'); do
		case "${_col}" in
			A|AL|ALL)
				disp_columns="SERVICE NAME PATH URL"
				;;
			N|NA|NAM|NAME)
				disp_columns="${disp_columns} NAME"
				;;
			P|PA|PAT|PATH)
				disp_columns="${disp_columns} PATH"
				;;
			S|SE|SER|SERV|SERVI|SERVIC|SERVICE)
				disp_columns="${disp_columns} SERVICE"
				;;
			U|UR|URL)
				disp_columns="${disp_columns} URL"
				;;
			*)
				msgErr "'--columns' option value must be 'ALL', 'NAME', 'PATH', 'SERVICE' or 'URL', '${opt_columns}' found"
				let _ret+=1
		esac
	done

	return ${_ret}
}

# ---------------------------------------------------------------------
# Always display output header
# Default format here is 'csv'

function f_display_header {
	typeset -i _count=0
	typeset _col

	for _col in $(echo ${disp_columns}); do
		if [ "${_col}" = "NAME" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "Name"
			let _count+=1
		fi
		if [ "${_col}" = "PATH" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "Path"
			let _count+=1
		fi
		if [ "${_col}" = "SERVICE" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "Service"
			let _count+=1
		fi
		if [ "${_col}" = "URL" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "Url"
			let _count+=1
		fi
	done
	printf "\n"
}

# ---------------------------------------------------------------------
# Display one output line
# Default format here is 'csv'
#
# (I): 1. subversion server running mode
#      2. server mode configuration
#      3. repository name
#      4. repository path

function f_display_line {
	typeset _mode="${1}"
	typeset _conf="${2}"
	typeset _name="${3}"
	typeset _path="${4}"

	typeset -i _count=0
	typeset _col

	for _col in $(echo ${disp_columns}); do
		if [ "${_col}" = "NAME" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "${_name}"
			let _count+=1
		fi
		if [ "${_col}" = "PATH" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "${_path}"
			let _count+=1
		fi
		if [ "${_col}" = "SERVICE" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "${opt_service}"
			let _count+=1
		fi
		if [ "${_col}" = "URL" ]; then
			[ ${_count} -gt 0 ] && printf "${opt_separator}"
			printf "$(svnGetURL "${_mode}" "${_conf}")/${_name}"
			let _count+=1
		fi
	done

	printf "\n"
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

	# we do not need to execRemote as the push gateway is already a remote execution way
	# so once we have got the hosting node, we are ok if we find the pushgateway properties
	else
		# check the service type
		typeset _type="$(confGetKey ttp_node_keys ${opt_service} 0=service 1)"
		if [ "${_type}" != "svn" ]; then
			msgErr "${opt_service}: service is of '${_type}' type, while 'svn' was expected"
			let _ret+=1

		# List the available repositories
		else
			typeset _mode="$(svnGetMode "${opt_service}")"
			typeset _conf="$(svnGetConf "${opt_service}" "${_mode}")"

			case "${_mode}" in

				httpd)
					typeset _name
					typeset _path
					varReset count
					{
						[ "${opt_headers}" == "yes" ] && f_display_header;
						svnHttpGetLocations "${_conf}" | while read _name _path; do
							f_display_line "${_mode}" "${_conf}" "${_name}" "${_path}"
							varInc count
						done;
					}
					typeset -i _count=$(varGet count)
					[ "${opt_counter}" == "yes" ] && msgOut "${_count} displayed data row(s)"
					;;

				*)
					msgErr "'${_mode}': unknown running mode"
					let _ret+=1
			esac
		fi
	fi

	return ${_ret}
}
