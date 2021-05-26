# @(#) list the configured repositories
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
# pwi 2018-12-31 creation

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
node=<name>					display repositories configured for this specific node
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
	opt_node_def="ALL"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	return ${_ret}
}

# ---------------------------------------------------------------------
# output the list of repositories for yum
# return the count of found repos

function f_yum_repolist {
	#set -x
	typeset _count=0
	
	which yum 1>/dev/null 2>&1
	if [ $? -eq 0 ]; then
		typeset _line
		typeset _found="no"
		yum repolist enabled | while read _line; do
			if [ "${_found}" = "yes" ]; then
				if [ "${_line:10}" = "repolist: " ]; then
					break
				else
					typeset _name="$(echo "${_line}" | awk '{ print $1 }')"
					let _count+=1
					echo "${_name}"
				fi
			elif [ "${_line}" = "repo id" ]; then
				_found="yes"
			fi
		done
	fi

	return ${_count}
}

# ---------------------------------------------------------------------
# modify the display format

function f_listcat_output {
	#set -x

	if [ "${disp_format}" = "CSV" ]; then
		cftCatalogFullToCsv "${opt_service}" "${opt_headers}" "${opt_counter}"

	elif [ "${disp_format}" = "RAW" ]; then
		cat -

	elif [ "${disp_format}" = "TABULAR" ]; then
		cftCatalogFullToCsv "${opt_service}" "yes" "no" \
			| csvToTabular "${opt_headers}" "${opt_counter}"
	fi
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# if all nodes are requested, then loop inside them
	if [ "${opt_node}" = "ALL" ]; then
		typeset _node
		typeset _parms="$@"
		nodeEnum | while read _node; do
			execRemote "${_node}" "${ttp_command} ${ttp_verb} ${_parms}"
			let _ret+=$?
		done

	# if only one node is requested, then ask it
	elif [ "${opt_node}" != "${TTP_NODE}" ]; then
		typeset _parms="$@"
		execRemote "${opt_node}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	# we are on the right node
	# then ask it for the repositories it is configured for 
	else
		typeset -i _count=0
		let _count=f_yum_repolist
		if [ ${_count} -eq 0 ]; then
			let _count=f_dnf_repolist
		fi
		if [ ${_count} -eq 0 ]; then
			let _count=f_debian_repolist
		fi
	fi

	return ${_ret}
}
