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
counter						whether to display a data rows counter
csv							display output in CSV format
separator					(CSV output) separator
headers						(CSV output) whether to display headers
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

	return ${_ret}
}

# ---------------------------------------------------------------------
# output the list of repositories for a redhat-like system
# return the count of found repositories

function f_debian_repolist {
	typeset -i _count=0

	return ${_count}
}

# ---------------------------------------------------------------------
# output the list of repositories for a redhat-like system
# return the count of found repositories
# From CentOS 6 to Fedora 34, we have
#	repo id		repo name		status

function f_redhat_repolist {
	typeset -i _count=0
	typeset _line

	[ "${opt_csv}" == "yes" -a "${opt_headers}" == "yes" ] && {
		echo "repository id${opt_separator}repository name${opt_separator}status";
	}

	typeset -i _title_found=0
	yum repolist all 2>/dev/null | while read _line; do
		# do not output anything until title line which starts with 'repo id'
		# then first word is repo id
		# last word is status
		# between we have a truncated label :(
		if [ ${_title_found} ]; then
			typeset _repoid="$(echo "${_line}" | awk '{ print $1 }')"
			typeset _label="$(echo "${_line}" | awk '{ for( i=2; i<NF; ++i ){ if( i>2 ) printf( " " ); printf( "%s", $i )}}')"
			typeset _status="$(echo "${_line}" | awk '{ print $NF }')"
			if [ "${opt_csv}" == "yes" ]; then
				echo "${_repoid}${opt_separator}${_label}${opt_separator}${_status}"
			else
				printf " ${_repoid}:\t${_label} (${_status})\n"
			fi
			let _count+=1
		elif [ ! -z "$(echo "${_line}" | grep -e '^repo id')" ]; then
			let _title_found=1
		fi
	done

	return ${_count}
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
			execRemote "${_node}" "${ttp_command} ${ttp_verb} -node ${_node} ${_parms}"
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
		osIsDebian 1>/dev/null 2>&1 && { f_debian_repolist; let _count+=$?; }
		osIsRedhat 1>/dev/null 2>&1 && { f_redhat_repolist; let _count+=$?; }
		[ "${opt_counter}" == "yes" ] && { msgOut "${_count} displayed repository/ies"; }
	fi

	return ${_ret}
}
