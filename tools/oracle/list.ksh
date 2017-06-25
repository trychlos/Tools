# @(#) list the objects in a database
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
# pwi 2003- 4-29 creation
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6-17 migrate to command-line dynamic interpretation scheme
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
schema[=<schema>]		schema to be listed
table[=<table>]			table to be listed
"
#packages			list packages
#body				also display packages body
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
	opt_schema_def="ALL"
	opt_table_def="ALL"
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# the service mnemonic is mandatory
	if [ -z "${opt_service}" ]; then
		msgerr "service mnemonic is mandatory, was not found"
		let _ret+=1
	fi

	# at least a schema value must be specified
	if [ "${opt_schema_set}" = "no" ]; then
		msgerr "'--schema' option must be specified"
		let _ret+=1
	else
		if [ "${opt_schema}" != "ALL" -a \
				"${opt_table_set}" = "no" ]; then
					msgerr "don't know what to do which just a shema; did you mean '--table' ?"
					let _ret+=1
		fi
	fi

	# listing tables only applies to one schema
	if [ "${opt_table_set}" = "yes" -a \
			"${opt_table}" = "ALL" -a \
			"${opt_schema}" = "ALL" ]; then
				msgerr "listing tables only applies to one specified schema"
				let _ret+=1
	fi

	# '--body' option is only relevant when displaying list of packages
	#if [ "${opt_body}" = "yes" -a \
	#		"${opt_packages}" = "no" ]; then
	#			msgerr "'--body' option is only relevant when listing packages"
	#			let _ret+=1
	#fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	#set | grep -e '^opt_'
	typeset -i _ret=0

	typeset _host="$(tabGetMachine "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgerr "'${opt_service}': unknown service mnemonic"
		let _ret+=1

	# TODO: it should not be required to get informations to be on the
	#  server while Oracle provides a listener for managing the
	#  connection - but this also means that we have to have a server
	#  environment and a client environment
	elif [ "${_host}" != "${ttp_logical}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	else
		# setup the environment
		oraSetEnv "${opt_service}"
		[ $? -eq 0 ] || { let _ret+=1; return ${_ret}; }

		# list all the schemas
		if [ "${opt_schema_set}" = "yes" -a "${opt_schema}" = "ALL" ]; then
			oraListSchemas "${opt_service}"
		fi

		# list all the tables in a schema
		if [ "${opt_table_set}" = "yes" -a \
				"${opt_table}" = "ALL" -a \
				"${opt_schema}" != "ALL" ]; then
					oraListTables "${opt_service}" "${opt_schema}"
		fi
	fi

	return ${_ret}
}
