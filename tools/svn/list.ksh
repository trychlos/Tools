# @(#) list known SVN repositories
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
# pwi 2013- 6- 8 creation
# pwi 2013- 6-25 update to new automatic command-line interpretation
# pwi 2013- 7-18 review options dynamic computing
# pwi 2013- 7-25 review option arguments list
# pwi 2017- 6-21 publish the release at last 

# ---------------------------------------------------------------------
# global variables
#  will be set in verb_arg_check, used in verb_main

disp_columns=""
disp_format=""

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
columns={SERVICE,NAME,PATH,URL}		comma-separated list of to be displayed columns (case insensitive)
headers								display headers
format={CSV|RAW|TABULAR}			output format (case insensitive)
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
	opt_columns_def="ALL"
	opt_headers_def="yes"
	opt_format_def="TABULAR"
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
		msgerr "service identifier is mandatory, was not found"
		let _ret+=1
	fi

	# columns, headers or format have only sense when listing repositories
	#if [ "${opt_columns_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgerr "--columns option has only sense when listing repositories"
	#	let _ret+=1
	#fi
	#if [ "${opt_headers_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgerr "--headers option has only sense when listing repositories"
	#	let _ret+=1
	#fi
	#if [ "${opt_format_set}" = "yes" -a "${opt_repository}" = "no" ]; then
	#	msgerr "--format option has only sense when listing repositories"
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
				msgerr "'--columns' option value must be 'ALL', 'NAME', 'PATH', 'SERVICE' or 'URL', '${opt_columns}' found"
				let _ret+=1
		esac
	done

	# set output format
	disp_format="$(formatCheck "${opt_format}")"
	let _ret+=$?

	return ${_ret}
}

# ---------------------------------------------------------------------
# Display output header if asked for
# Default format here is 'csv'

function f_display_header {
	typeset -i _count=0
	typeset _col

	if [ "${opt_headers}" = "yes" ]; then
		for _col in $(echo ${disp_columns}); do
			if [ "${_col}" = "NAME" ]; then
				[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
				printf "Name"
				let _count+=1
			fi
			if [ "${_col}" = "PATH" ]; then
				[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
				printf "Path"
				let _count+=1
			fi
			if [ "${_col}" = "SERVICE" ]; then
				[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
				printf "Service"
				let _count+=1
			fi
			if [ "${_col}" = "URL" ]; then
				[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
				printf "Url"
				let _count+=1
			fi
		done
		printf "\n"
	fi
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
			[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
			printf "${_name}"
			let _count+=1
		fi
		if [ "${_col}" = "PATH" ]; then
			[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
			printf "${_path}"
			let _count+=1
		fi
		if [ "${_col}" = "SERVICE" ]; then
			[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
			printf "${opt_service}"
			let _count+=1
		fi
		if [ "${_col}" = "URL" ]; then
			[ ${_count} -gt 0 ] && printf "${ttp_csvsep:-;}"
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
		msgerr "'${opt_service}': no hosting node found (environment='${ttp_node_environment}')"
		let _ret+=1
	
	elif [ "${_node}" != "${TTP_NODE}" ]; then
		typeset _parms="$@"
		execRemote "${_node}" "${ttp_command} ${ttp_verb} ${_parms}" 
		return $?

	# we are on the right node
	else
		# check the service type
		typeset _type="$(confGetKey ttp_node_keys ${opt_service} 0=service 1)"
		if [ "${_type}" != "svn" ]; then
			msgerr "${opt_service}: service is of '${_type}' type, while 'svn' was expected"
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
						f_display_header;
						svnHttpGetLocations "${_conf}" | while read _name _path; do
							f_display_line "${_mode}" "${_conf}" "${_name}" "${_path}"
							varInc count
						done;
					} | formatOutput "${disp_format}" "${opt_headers}"
					typeset -i _count=$(varGet count)
					msgout "${_count} displayed row(s)"
					;;

				*)
					msgerr "'${_mode}': unknown running mode"
					let _ret+=1
			esac
		fi
	fi

	return ${_ret}
}
