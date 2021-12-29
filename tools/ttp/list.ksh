# @(#) list various informations about The Tools Project
#
# Please note that the '# @(#)' prefix display the help before the options
# while the '# @(@)' prefix display the help after the options. This later
# is 'post-help' message and is displayed by scriptDetailEnd() function. 
#
# @(#) This verb lists:
# @(#) - the available commands,
# @(#) - the registered execution nodes, maybe for a specified environment
# @(#)     --nodes [--environment=<identifier>]
# @(#) - the services available on a node, maybe with their label:
# @(#)     --services [--node=<name>] [--label]
# @(#) - the services defined in an environment:
# @(#)     --services -environment=<identifier> [--label]
# @(#) - the TTP defined variables,
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
# pwi 2013- 2-19 creation
# pwi 2017- 6-21 publish the release at last
# pwi 2021-12-28 only output CSV format, leaving json and tabular to ttp.sh filter

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help							display this online help and gracefully exit
verbose							verbose execution
commands						display the list of available commands
nodes							display the registered nodes
environment=<identifier>		display nodes for this specific environment
services						display defined services
variables						display TTP defined variables
counter							whether to display a data rows counter
csv								display output in CSV format
separator						(CSV output) separator
headers							(CSV output) whether to display headers
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
	typeset -i _ret=0

	# at least one option must be specified
	#  several are accepted as they are independant each other
	typeset -i _action=0
	[ "${opt_commands}" = "yes" ] && let _action+=1
	[ "${opt_variables}" = "yes" ] && let _action+=1
	[ "${opt_services}" = "yes" ] && let _action+=1
	[ "${opt_nodes}" = "yes" ] && let _action+=1
	if [ ${_action} -eq 0 ]; then
		msgErr "at least one of '--commands', '--nodes', '--services' or '--variables' option must be specified"
		let _ret+=1
	fi

	# a node is only relevant when asking for services
	if [ ! -z "${opt_node}" -a "${opt_services}" = "no" ]; then
		msgWarn "'--node=<name>' option is only relevant when asking for list of services, ignored"
		unset opt_node
		opt_node_set="no"
	fi

	# a service is only relevant when asking for nodes
	if [ ! -z "${opt_service}" -a "${opt_nodes}" = "no" ]; then
		msgWarn "'--service=<identifier>' option is only relevant when asking for list of nodes, ignored"
		unset opt_service
		opt_service_set="no"
	fi

	# label is only relevant when asking for services
	if [ "${opt_label_set}" = "yes" -a "${opt_services}" = "no" ]; then
		msgWarn "'--[no]label' option is only relevant when asking for list of services, ignored"
		unset opt_label
		opt_label_set="no"
	fi

	# no both -environment and -service
	if [ ! -z "${opt_environment}" -a ! -z "${opt_service}" ]; then
		msgErr "'--environment=<identifier>' and '--service=<identifier>' options are mutually exclusives"
		let _ret+=1
	fi

	# environment is only relevant when asking for nodes or services
	if [ ! -z "${opt_environment}" \
			-a "${opt_services}" = "no" \
			-a "${opt_nodes}" = "no" ]; then
		msgErr "specifying an environment is only allowed when listing nodes or services"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# list the available unique commands, in alpha order
# this function might also be a scriptListCommands() external one

function f_commands_all {
	#set -x
	typeset _dir
	typeset _file
	typeset _cmdpath

	bspRootEnum | while read _dir; do
		LANG=C \ls -1 "${_dir}/${ttp_binsubdir}" 2>/dev/null | while read _file; do
			_cmdpath="${_dir}/${ttp_binsubdir}/${_file}"
			[ -x "${_cmdpath}" ] && echo "${_file}" "${_cmdpath}"
		done
	done | sort -u -k1,1 | while read _file _cmdpath; do
		scriptDetail "${_cmdpath}"
	done

	return 0
}

# ---------------------------------------------------------------------
# standard output:
#   [ttp.sh list] displaying available commands...
#    cft.sh: Cross File Transfer (CFT) management
#    mysql.sh: MySQL management
#   [ttp.sh list] 2 displayed command(s)
# csv:
#   [ttp.sh list] displaying available commands...
#   command;label
#   cft.sh;Cross File Transfer (CFT) management
#   mysql.sh;MySQL management
#   [ttp.sh list] 2 displayed command(s)

function f_commands_list {
	typeset -i _count=0
	typeset _line

	typeset _prefix=" "
	typeset _separator=": "
	[ "${opt_csv}" == "yes" ] && { _prefix=""; _separator="${opt_separator}"; }
	[ "${opt_csv}" == "yes" -a "${opt_headers}" == "yes" ] && { echo "command${_separator}label"; }

	msgOut "displaying available commands..."

	f_commands_all | while read _line; do
		printf '%b' "${_prefix}"
		printf '%s' "$(echo "${_line}" | cut -d: -f1)"
		printf '%b' "${_separator}"
		printf '%s' "$(echo "${_line}" | cut -d: -f2 | sed -e 's|^\s*||' -e 's|\s*$||')"
		printf '\n'
		let _count+=1
	done

	[ "${opt_counter}" == "yes" ] && { msgOut "${_count} displayed command(s)"; }

	return 0
}

# ---------------------------------------------------------------------
# list on stdout all nodes with their environment, in node alpha order,
# as a 'ttp_sep'-separated list node:environment:ini_path
# returns the count of nodes

function f_nodes_all {
	typeset -i _count=0
	typeset _dir
	typeset _ini
	typeset _line

	bspRootEnum | while read _dir; do
		find ${_dir}/${ttp_nodesubdir} -type f -name '*.ini' | while read _ini; do
			typeset _node="$(echo ${_ini##*/} | sed -e 's|\.ini$||')"
			typeset _env="$(nodeGetEnvironment "${_node}")"
			echo "${_node}${ttp_sep}${_env}${ttp_sep}${_ini}"
		done
	done | sort -t ${ttp_sep} -k 1,1 -u | while read _line; do
		let _count+=1
		echo "${_line}"
	done

	return ${_count}
}

# ---------------------------------------------------------------------

function f_nodes_display {
	typeset _line="${1}"
	typeset _prefix="${2}"
	typeset _separator="${3}"

	typeset _node="$(echo "${_line}" | cut -d${ttp_sep} -f1)"
	typeset _env="$(echo "${_line}" | cut -d${ttp_sep} -f2)"
	typeset _ini="$(echo "${_line}" | cut -d${ttp_sep} -f3)"

	printf '%b' "${_prefix}"
	printf '%s' "${_node}"
	printf '%b' "${_separator}"
	printf '%s' "${_env}"
	printf '%b' "${_separator}"
	printf '%s' "${_ini}"
	printf '\n'

	return 0
}

# ---------------------------------------------------------------------
# list nodes
#	default output is node environment inipath
#	population may be restricted for a particular environment
# Please note that a node may be defined without any service; so trying to
#	list services per node is a bit more complex

function f_nodes_list {
	typeset -i _ret=0
	typeset -i _count=0
	typeset -i _total=0
	typeset _line

	if [ -z "${opt_environment}" ]; then
		msgOut "displaying registered execution nodes..."
	else
		msgOut "displaying nodes which participate to '${opt_environment}' environment..."
	fi

	typeset _prefix=" "
	typeset _separator=":\t"
	[ "${opt_csv}" == "yes" ] && { _prefix=""; _separator="${opt_separator}"; }
	[ "${opt_csv}" == "yes" -a "${opt_headers}" == "yes" ] && { echo "node${_separator}environment${_separator}pathname"; }

	f_nodes_all | while read _line; do
		if [ -z "${opt_environment}" ]; then
			f_nodes_display "${_line}" "${_prefix}" "${_separator}"
			let _count+=1
		else
			typeset _env="$(echo "${_line}" | cut -d${ttp_sep} -f2)"
			if [ "${_env}" == "${opt_environment}" ]; then
				f_nodes_display "${_line}" "${_prefix}" "${_separator}"
				let _count+=1
			fi
		fi
		let _total+=1
	done

	[ "${opt_counter}" == "yes" -a -z "${opt_environment}" ] && { msgOut "${_count} displayed node(s)"; }
	[ "${opt_counter}" == "yes" -a ! -z "${opt_environment}" ] && { msgOut "${_count} displayed node(s) on ${_total} total registered"; }

	return ${_ret}
}

# ---------------------------------------------------------------------
# display a 'ttp_sep'-separated list:
#	<service_id> : <service_type> : <node> : <node_environment> : <service_label>
# sorted by service/node

function f_services_all {
	typeset -i _ret=0
	typeset _line
	typeset _sub

	f_nodes_all | while read _line; do
		typeset _node="$(echo "${_line}" | cut -d${ttp_sep} -f1)"
		typeset _env="$(echo "${_line}" | cut -d${ttp_sep} -f2)"
		typeset _ini="$(echo "${_line}" | cut -d${ttp_sep} -f3)"
		cat "${_ini}" \
			| tabStripComments "${ttp_sep}" \
			| tabSubstitute "${ttp_sep}" "${_node}" \
			| sed -e "s|\s*${ttp_sep}\s*|${ttp_sep}|g" \
			| grep -e "${ttp_sep}service${ttp_sep}" \
			| while read _sub; do
				typeset _service="$(echo "${_sub}" | cut -d${ttp_sep} -f1)"
				typeset _type="$(echo "${_sub}" | cut -d${ttp_sep} -f3)"
				typeset _label="$(echo "${_sub}" | cut -d${ttp_sep} -f4)"
				echo "${_service}${ttp_sep}${_type}${ttp_sep}${_node}${ttp_sep}${_env}${ttp_sep}${_label}"
			done
	done | sort -t${ttp_sep} -k1,1 -k3,3

	return ${_ret}
}

# ---------------------------------------------------------------------
# list services, with their nodes and their environment

function f_services_list {
	typeset -i _ret=0
	typeset -i _count=0
	typeset _line

	typeset _prefix=" "
	typeset _separator=":\t"
	[ "${opt_csv}" == "yes" ] && { _prefix=""; _separator="${opt_separator}"; }
	[ "${opt_csv}" == "yes" -a "${opt_headers}" == "yes" ] && { echo "service${_separator}type${_separator}node${_separator}environment${_separator}label"; }

	msgOut "displaying defined services and their node..."

	f_services_all | while read _line; do
		typeset _service="$(echo "${_line}" | cut -d${ttp_sep} -f1)"
		typeset _type="$(echo "${_line}" | cut -d${ttp_sep} -f2)"
		typeset _node="$(echo "${_line}" | cut -d${ttp_sep} -f3)"
		typeset _env="$(echo "${_line}" | cut -d${ttp_sep} -f4)"
		typeset _label="$(echo "${_line}" | cut -d${ttp_sep} -f5)"
		printf '%b' "${_prefix}"
		printf '%s' "${_service}"
		printf '%b' "${_separator}"
		printf '%s' "${_type}"
		printf '%b' "${_separator}"
		printf '%s' "${_node}"
		printf '%b' "${_separator}"
		printf '%s' "${_env}"
		printf '%b' "${_separator}"
		printf '%s' "${_label}"
		printf '\n'
		let _count+=1
	done


	[ "${opt_counter}" == "yes" ] && { msgOut "${_count} defined service(s)"; }

	return ${_ret}
}

# ---------------------------------------------------------------------

function f_variables_list {
	typeset -i _ret=0

	typeset _prefix=" "
	typeset _separator="="
	[ "${opt_csv}" == "yes" ] && { _prefix=""; _separator="${opt_separator}"; }
	[ "${opt_csv}" == "yes" -a "${opt_headers}" == "yes" ] && { echo "variable${_separator}content"; }

	typeset -i _count=0
	f_variables_regexp 'TTP_' "global TTP variables" "${_prefix}" "${_separator}"
	let _count+=$?
	f_variables_regexp 'ttp_' "internal TTP variables" "${_prefix}" "${_separator}"
	let _count+=$?
	f_variables_regexp 'opt_' "myn own internal opt_ variables" "${_prefix}" "${_separator}"
	let _count+=$?

	[ "${opt_counter}" == "yes" ] && { msgOut "${_count} displayed variable(s)"; }

	return ${_ret}
}

# ---------------------------------------------------------------------
# return the count of displayed variables

function f_variables_regexp {
	typeset _regexp="${1}"
	typeset _label="${2}"
	typeset _prefix="${3}"
	typeset _separator="${4}"

	typeset _line
	typeset -i _count=0
	msgOut "displaying ${_label}..."

	set | grep -e "^${_regexp}" | while read _line; do
		printf '%b' "${_prefix}"
		printf '%s' "$( echo "${_line}" | cut -d= -f1)"
		printf '%b' "${_separator}"
		printf '%s' "$( echo "${_line}" | cut -d= -f2-)"
		printf '\n'
		let _count+=1
	done

	return ${_count}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# list available commands
	if [ "${opt_commands}" = "yes" ]; then
		f_commands_list
		let _ret+=$?
	fi

	# list registered nodes
	#  maybe for a specified environment
	if [ "${opt_nodes}" = "yes" ]; then
		f_nodes_list
		let _ret+=$?
	fi

	# list defined services
	if [ "${opt_services}" = "yes" ]; then
		f_services_list
		let _ret+=$?
	fi

	# list TTP variables
	if [ "${opt_variables}" = "yes" ]; then
		f_variables_list
		let _ret+=$?
	fi

	return ${_ret}
}
