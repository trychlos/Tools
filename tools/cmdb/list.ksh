# @(#) list components from the CMDB
#
# @(@) This verb lists the components of the CMDB, and is able to produce
# @(@) eiher a raw or a JSON output.
# @(@) The CMDB itself is hosted at ldap://ldap.
# @(@) One and only one action must be specified, among --host
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
# pwi 2021- 5-21 creation
# pwi 2021- 9- 4 make sure the group is able to access the output file

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
host={ALL|<hostname>}			list all known hosts, or only the one specified
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
	opt_verbose_def="no"
	opt_host_def="ALL"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# an action is mandatory
	if [ -z "${opt_host}" ]; then
		msgErr "an action is mandatory, has not been found"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# filter databases name

function f_all_filter {
	typeset _service
	typeset _dbname
	grep -E "^${opt_service}" | sed -e 's/;/ /g' | while read _service _dbname; do
		[ "${_dbname:0:1}" = "#" ] || echo "${_dbname}"
	done
}

# ---------------------------------------------------------------------
# dump the specified database + the specified tables (if any)
# note that all the output of this function will go the output file
# so only print your messages to stderr

function f_db_dump {
	typeset _dbname="${1}"
	typeset _tables="${2}"
	typeset -i _ret=0
	
	execDummy mysqldump \
					-u${opt_user} \
					-p$(dbmsGetPassword "${opt_service}" "${ttp_node_environment}" "${opt_user}") \
					"${_dbname}" \
					"${_tables}"
	let _ret=$?
	return ${_ret}
}

# ---------------------------------------------------------------------
# compress the stream depending of the choosed option

function f_compress {
	typeset _bname="${1}"
	typeset _foutput="${opt_dumpto}/${_bname}-$(date '+%Y%m%d%H%M%S').dump"
	typeset -i _ret=0

	execDummy "mkdir -p -m 0775 '${opt_dumpto}'"
	let _ret=$?

	if [ ${_ret} -eq 0 ]; then
		if [ "${opt_gz}" = "yes" ]; then
			msgOut "dumping ${_bname} to ${_foutput}.gz"
			execDummy gzip > "${_foutput}.gz"
			let _ret=$?
		
		else
			msgOut "dumping ${_bname} to ${_foutput}"
			cat - > "${_foutput}"
			let _ret=$?
		fi
	fi
	
	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# check which node hosts our required service
	typeset _node="$(tabGetNode CMDBLDAP)"
	if [ -z "${_node}" ]; then
		msgErr "'CMDBLDAP': no hosting node found (environment='${ttp_node_environment}')"
		let _ret+=1

	# as we connect remotely to the CMDB LDAP, no remote execution is needed
	else
		# check the service type
		typeset _conf="$(bspFind "${ttp_nodesubdir}/${_node}.ini")"
		if [ -z "${_conf}" ]; then
			msgErr "${_node}: unable to find the node configuration file"
			let _ret+=1

		else
			typeset _type="$(cat "${_conf}" | tabExtract "" "1=${_service},2=service" 3)"
			if [ "${_type}" != "ldap" ]; then
				msgErr "CMDBLDAP: service is of '${_type}' type, while 'ldap' was expected"
				let _ret+=1

			else
			fi
		fi
	fi

	return ${_ret}
}
