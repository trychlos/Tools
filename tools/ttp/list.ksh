# @(#) list various informations about The Tools Project
#
# @(@) Apart from listing available commands, and an example of TTP used variables,
# @(@) this verb is also able to list:
# @(@) - the services available on a node, maybe with their label:
# @(@)     --services [--node=<name>] [--label]
# @(@) - the services defined in an environment:
# @(@)     --services -environment=<identifier> [--label]
# @(@) - the registered execution nodes, may be with their respective environment
# @(@)     --nodes [--environment]
# @(@) - the nodes which host a service:
# @(@)     --nodes -service=<identifier> [--environment]
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
help							display this online help and gracefully exit
verbose							verbose execution
commands						display list of commands
variables						display TTP variables
services						display services available on the node
label							display the service label
node=<name>						the execution node to display the services from
service=<identifier>			display the nodes which host this service
nodes							display the registered nodes
environment[=<identifier>]		display the environment associated to a node/service
format={CSV|RAW|TABULAR}		output format (case insensitive)
headers							whether to display headers (in CSV and TABULAR formats)
counter							whether to display rows counter (in CSV and TABULAR formats)
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
	opt_format_def="RAW"
	opt_headers_def="yes"
	opt_counter_def="yes"
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
		msgerr "at least one of '--commands', '--nodes', '--services' or '--vars' option must be specified"
		let _ret+=1
	fi

	# a node is only relevant when asking for services
	if [ ! -z "${opt_node}" -a "${opt_services}" = "no" ]; then
		msgwarn "'--node=<name>' option is only relevant when asking for list of services, ignored"
		unset opt_node
		opt_node_set="no"
	fi

	# a service is only relevant when asking for nodes
	if [ ! -z "${opt_service}" -a "${opt_nodes}" = "no" ]; then
		msgwarn "'--service=<identifier>' option is only relevant when asking for list of nodes, ignored"
		unset opt_service
		opt_service_set="no"
	fi

	# label is only relevant when asking for services
	if [ "${opt_label_set}" = "yes" -a "${opt_services}" = "no" ]; then
		msgwarn "'--[no]label' option is only relevant when asking for list of services, ignored"
		unset opt_label
		opt_label_set="no"
	fi

	# no both -environment and -service
	if [ ! -z "${opt_environment}" -a ! -z "${opt_service}" ]; then
		msgerr "'--environment=<identifier>' and '--service=<identifier>' options are mutually exclusives"
		let _ret+=1
	fi

	# environment is only relevant when asking for nodes or services
	if [ ! -z "${opt_environment}" \
			-a "${opt_services}" = "no" \
			-a "${opt_nodes}" = "no" ]; then
		msgerr "specifying an environment is only allowed when listing nodes or services"
		let _ret+=1
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
# list the available unique commands, in alpha order

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
		scriptDetail "${_cmdpath}" 1
	done

	return 0
}

# ---------------------------------------------------------------------

function f_commands_list {
	typeset -i _count=0
	typeset _line

	msgout "displaying available commands..."
	f_commands_all | while read _line; do
		echo " ${_line}"
		let _count+=1
	done
	msgout "${_count} displayed command(s)"

	return 0
}

# ---------------------------------------------------------------------
# raw output is:
#   [ttp.sh list] displaying available commands...
#    cft.sh: Cross File Transfer (CFT) management
#    mysql.sh: MySQL management
#   [ttp.sh list] 2 displayed command(s)

function f_commands_csv {
	#set -x
	typeset _headers="${1}"
	typeset _counter="${2}"
	typeset -i _count=0
	typeset _cmd
	typeset _comment

	cat - | while read _cmd _comment; do
		if [ "${_cmd:0:1}" = "[" ]; then
			[ "$(echo "${_comment}" | grep ' displayed command')" = "" -o "${_counter}" = "yes" ] \
				&& echo "${_cmd} ${_comment}"
		else
			[ ${_count} -eq 0 -a "${_headers}" = "yes" ] && echo "Command;Label"
			echo "${_cmd:0:${#_cmd}-1};${_comment}"
			let _count+=1
		fi
	done

	return 0
}

# ---------------------------------------------------------------------
# stdout: all nodes with their environment, in node alpha order
# return: count of all unique registered nodes

function f_nodes_all {
	typeset -i _count=0
	typeset _dir
	typeset _ini
	typeset _node
	typeset _env
	
	bspRootEnum | while read _dir; do
		find ${_dir}/${ttp_nodesubdir} -type f -name '*.ini' | while read _ini; do
			echo ${_ini##*/} | sed -e 's|\.ini$||'
		done
	done | sort -u -k1,1 | while read _node; do
		_env="$(nodeGetEnvironment "${_node}")"
		echo "${_node}" "${_env}"
		let _count+=1;
	done

	return ${_count}
}

# ---------------------------------------------------------------------
# --nodes [--environment [=<identifier] ]

function f_nodes_byenv_list {
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _env

	if [ -z "${opt_environment}" ]; then
		msgout "displaying registered execution nodes..."
	else
		msgout "displaying nodes which participate to '${opt_environment}' environment..."
	fi

	f_nodes_all | while read _node _env; do
		if [ -z "${opt_environment}" -o "${_env}" = "${opt_environment}" ]; then
			echo -n " ${_node}"
			[ "${opt_environment_set}" = "yes" ] && echo ": ${_env}" || echo
			let _count+=1;
		fi
	done

	msgout "${_count} displayed node(s)"

	return ${_ret}
}

# ---------------------------------------------------------------------
# raw output is:
#   [ttp.sh list] displaying registered execution nodes...
#    svn
#    xps13
#   [ttp.sh list] 2 displayed node(s)
# or:
#   [ttp.sh list] displaying registered execution nodes...
#    svn: X@trychlos.pwi
#    xps13: X@trychlos.pwi
#   [ttp.sh list] 2 displayed node(s)

function f_nodes_byenv_csv {
	typeset _headers="${1}"
	typeset _counter="${2}"
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _env

	typeset _headline="Node"
	[ "${opt_environment_set}" = "yes" ] && _headline="${_headline};Environment"

	cat - | while read _node _env; do
		if [ "${_node:0:1}" = "[" ]; then
			[ "$(echo "${_env}" | grep ' displayed node')" = "" -o "${_counter}" = "yes" ] \
				&& echo "${_node} ${_env}"
		else
			[ ${_count} -eq 0 -a "${_headers}" = "yes" ] && echo "${_headline}"
			[ "${_node:${#_node}-1:1}" = ":" ] && echo -n "${_node:0:${#_node}-1}" || echo -n "${_node}"
			[ -z "${_env}" ] && echo || echo ";${_env}"
			let _count+=1
		fi
	done

	return ${_ret}
}

# ---------------------------------------------------------------------
# --nodes --service=<identifier [--environment]

function f_nodes_byserv_list {
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _service

	msgout "displaying nodes which host '${opt_service}' service..."
	f_services_all | while read _node _service; do
		if [ "${_service}" = "${opt_service}" ]; then
			echo -n " ${_node}: ${_service}"
			[ "${opt_environment_set}" = "yes" ] && echo " $(nodeGetEnvironment "${_node}")" || echo
			let _count+=1
		fi
	done

	msgout "${_count} displayed node(s)"

	return ${_ret}
}

# ---------------------------------------------------------------------
# raw output is:
#   [ttp.sh list] displaying nodes which host 'CFTT' service...
#    xps13: CFTT
#   [ttp.sh list] 1 displayed node(s)
# or:
#   [ttp.sh list] displaying nodes which host 'CFTT' service...
#    xps13: CFTT X@trychlos.pwi
#   [ttp.sh list] 1 displayed node(s)

function f_nodes_byserv_csv {
	typeset _headers="${1}"
	typeset _counter="${2}"
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _serv
	typeset _env

	typeset _headline="Node;Service"
	[ "${opt_environment_set}" = "yes" ] && _headline="${_headline};Environment"

	cat - | while read _node _serv _env; do
		if [ "${_node:0:1}" = "[" ]; then
			[ "$(echo "${_env}" | grep ' displayed node')" = "" -o "${_counter}" = "yes" ] \
				&& echo "${_node} ${_serv} ${_env}"
		else
			[ ${_count} -eq 0 -a "${_headers}" = "yes" ] && echo "${_headline}"
			echo -n "${_node:0:${#_node}-1}"
			echo -n ";${_serv}"
			[ -z "${_env}" ] && echo || echo ";${_env}"
			let _count+=1
		fi
	done

	return ${_ret}
}

# ---------------------------------------------------------------------
# --nodes [--environment [=<identifier] ]
# --nodes --service=<identifier [--environment]

function f_nodes_list {
	typeset -i _ret=0

	if [ -z "${opt_service}" ]; then
		# list all nodes, maybe with their environment, maybe for an
		#  environment
		f_nodes_byenv_list | f_output "f_nodes_byenv_csv"
	else
		# list nodes for a service
		f_nodes_byserv_list | f_output "f_nodes_byserv_csv"
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# stdout: all services with their node, in "node service" alpha order
# return: count of all unique defined services

function f_services_all {
	typeset -i _count=0
	typeset _dir
	typeset _ini
	typeset _service

	bspRootEnum | while read _dir; do
		find ${_dir}/${ttp_nodesubdir} -type f -name '*.ini' | while read _ini; do
			ttp_node="$(echo ${_ini##*/} | sed -e 's|\.ini$||')"
			cat "${_ini}" \
				| bspTabStripComments "${ttp_sep}" \
				| tabSubstitute "${ttp_sep}" \
				| awk -F "${ttp_sep}" '{ print $1 }' \
				| sort -u \
				| grep -v "${ttp_node}" \
				| while read _service; do	
					echo "${ttp_node} ${_service}"
					let _count+=1
				done
			unset ttp_node
		done
	done | sort

	return ${_count}
}

# ---------------------------------------------------------------------
#  --services [--node=<name>] [--label]

function f_services_bynode_list {
	typeset -i _ret=0
	typeset -i _count=0

	if [ -z "${opt_node}" ]; then
		msgout "displaying available services for current node..."
		typeset -n _vname="ttp_node_keys"
		typeset _value
		for _value in "${_vname[@]}"; do
			if [ "${_value}" != "${TTP_NODE}" ]; then
				echo -n " ${TTP_NODE}: ${_value}"
				[ "${opt_label}" = "yes" ] && echo " $(confGetKey "ttp_node_keys" "${_value}" "0=service" "2")" || echo
				let _count+=1
			fi
		done

	else
		msgout "displaying available services for '${opt_node}' node..."
		typeset _node
		typeset _service
		f_services_all | while read _node _service; do
			if [ "${_node}" = "${opt_node}" ]; then
				echo -n " ${_node}: ${_service}"
				[ "${opt_label}" = "yes" ] && echo " $(serviceGetLabel "${_node}" "${_service}")" || echo
				let _count+=1
			fi
		done
	fi

	msgout "${_count} displayed service(s)"

	return ${_ret}
}

# ---------------------------------------------------------------------
# raw output is:
#   [ttp.sh list] displaying available services for current node...
#    xps13: MYS
#    xps13: CFTT
#   [ttp.sh list] 2 displayed service(s)

function f_services_bynode_csv {
	typeset _headers="${1}"
	typeset _counter="${2}"
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _serv
	typeset _label

	typeset _headline="Node;Service"
	[ "${opt_label}" = "yes" ] && _headline="${_headline};Label"

	cat - | while read _node _serv _label; do
		if [ "${_node:0:1}" = "[" ]; then
			[ "$(echo "${_label}" | grep ' displayed service')" = "" -o "${_counter}" = "yes" ] \
				&& echo "${_node} ${_serv} ${_label}"
		else
			[ ${_count} -eq 0 -a "${_headers}" = "yes" ] && echo "${_headline}"
			echo -n "${_node:0:${#_node}-1}"
			echo -n ";${_serv}"
			[ "${opt_label}" = "yes" ] && echo ";${_label}" || echo
			let _count+=1
		fi
	done

	return ${_ret}
}

# ---------------------------------------------------------------------
#  --services --environment=<identifier> [--label]

function f_services_byenv_list {
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _service
	typeset _env
	typeset _label

	msgout "displaying available services in '${opt_environment}' environment..."
	f_services_all | while read _node _service; do
		_env="$(nodeGetEnvironment "${_node}")"
		if [ "${_env}" = "${opt_environment}" ]; then
			echo -n " ${_node}: ${_service}"
			[ "${opt_label}" = "yes" ] && echo " $(serviceGetLabel "${_node}" "${_service}")" || echo
			let _count+=1
		fi
	done
	msgout "${_count} displayed service(s)"

	return ${_ret}
}

# ---------------------------------------------------------------------
# raw output is:
#   [ttp.sh list] displaying available services in 'X@trychlos.pwi' environment...
#    svn: SVN
#    xps13: CFTT
#    xps13: MYS
#   [ttp.sh list] 3 displayed service(s)

function f_services_byenv_csv {
	typeset _headers="${1}"
	typeset _counter="${2}"
	typeset -i _ret=0
	typeset -i _count=0
	typeset _node
	typeset _serv
	typeset _label

	typeset _headline="Node;Service"
	[ "${opt_label}" = "yes" ] && _headline="${_headline};Label"

	cat - | while read _node _serv _label; do
		if [ "${_node:0:1}" = "[" ]; then
			[ "$(echo "${_label}" | grep ' displayed service')" = "" -o "${_counter}" = "yes" ] \
				&& echo "${_node} ${_serv} ${_label}"
		else
			[ ${_count} -eq 0 -a "${_headers}" = "yes" ] && echo "${_headline}"
			echo -n "${_node:0:${#_node}-1}"
			echo -n ";${_serv}"
			[ "${opt_label}" = "yes" ] && echo ";${_label}" || echo
			let _count+=1
		fi
	done

	return ${_ret}
}

# ---------------------------------------------------------------------
#  --services [--label]
#  --services --node=<name> [--label]
#  --services --environment=<identifier> [--label]

function f_services_list {
	typeset -i _ret=0
	typeset -i _count=0

	if [ -z "${opt_environment}" ]; then
		f_services_bynode_list | f_output "f_services_bynode_csv"
	else
		f_services_byenv_list | f_output "f_services_byenv_csv"
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function f_variables_list {
	typeset -i _ret=0

	typeset -i _count=0
	msgout "displaying global TTP variables..."
	set | grep -e '^TTP_' | while read l; do echo " $l"; let _count+=1; done
	msgout "displaying internal TTP variables..."
	set | grep -e '^ttp_' | while read l; do echo " $l"; let _count+=1; done
	msgout "${_count} displayed variable(s)"

	return ${_ret}
}

# ---------------------------------------------------------------------

function f_output {
	typeset _csvfn="${1}"
	typeset -i _ret=0

	if [ "${disp_format}" = "CSV" ]; then
		${_csvfn} "${opt_headers}" "${opt_counter}"

	elif [ "${disp_format}" = "RAW" ]; then
		cat -

	elif [ "${disp_format}" = "TABULAR" ]; then
		${_csvfn} "yes" "no" \
			| csvToTabular "${opt_headers}" "${opt_counter}"

	else
		msgerr "${disp_format}: unknown output format"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# listing available commands
	if [ "${opt_commands}" = "yes" ]; then
		f_commands_list | f_output "f_commands_csv"
		let _ret+=$?
	fi

	# listing registered nodes
	#  maybe with their associated environment
	if [ "${opt_nodes}" = "yes" ]; then
		f_nodes_list
		let _ret+=$?
	fi

	# listing available services
	# may be listed for the current node, for a specific node, or for
	#  an environment
	if [ "${opt_services}" = "yes" ]; then
		f_services_list
		let _ret+=$?
	fi

	# listing internal TTP variables
	if [ "${opt_variables}" = "yes" ]; then
		f_variables_list
		let _ret+=$?
	fi

	return ${_ret}
}
