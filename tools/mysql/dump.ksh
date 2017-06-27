# @(#) dump elements to an output file
#
# @(@) This verb creates one output file per dumped database, with
# @(@) a '<dbname>-yyyymmddhhmiss.dump' basename.
# @(@) Depending of the chosen compression option, a '.gz', '.xz', etc.,
# @(@) suffix may be appended.
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
# ema 2006-10- 4 creation
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
help							display this online help and gracefully exit
dummy							dummy execution
verbose							verbose execution
service=<identifier>			service identifier
database[=<name>]				dump this database
system							also dump system databases
table=<name>[,<name>[,...]]		dump this table (resp. these tables)
gz								use gzip to compress the dump
user=<user>						connection account
dumpto=/path/to/dir				output dump directory
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
	opt_dummy_def="yes"
	opt_database_def="ALL"
	opt_table_def="ALL"
	opt_gz_def="yes"
	opt_user_def="root"
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

	# at least an empty --database option must be specified
	if [ "${opt_database_set}" != "yes" ]; then
		msgerr "at least an empty '--database' option must be specified"
		let _ret+=1
	fi

	# if a table is named, then a database must be chosen
	if [ "${opt_table}" != "ALL" -a "${opt_database}" = "ALL" ]; then
		msgerr "'--table=<name>' option can only be specified if a '--database=<name>' has been selected"
		let _ret+=1
	fi

	# '--system' is only relevant when dumping all databases
	if [ "${opt_system_set}" = "yes" -a "${opt_database}" != "ALL" ]; then
		msgwarn "'--[no]system' option is not relevant when dumping a specified database, ignored"
	fi

	# the output file is mandatory
	if [ -z "${opt_dumpto}" ]; then
		msgerr "output dump file is mandatory, has not been found"
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

	execDummy mkdir -p "${opt_dumpto}"
	let _ret=$?

	if [ ${_ret} -eq 0 ]; then
		if [ "${opt_gz}" = "yes" ]; then
			msgout "dumping ${_bname} to ${_foutput}.gz"
			execDummy gzip > "${_foutput}.gz"
			let _ret=$?
		
		else
			msgout "dumping ${_bname} to ${_foutput}"
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
			# check that we have access the mysqldump binary
			which mysqldump 1>/dev/null 2>&1
			let _ret=$?
			if [ ${_ret} -ne 0 ]; then
				msgerr "${opt_service}: 'mysqldump' required, not found or not available"
				let _ret+=1
	
			# save all databases (
			elif [ "${opt_database}" = "ALL" ]; then
				typeset _system="--system"
				[ "${opt_system}" = "no" ] && _system="--nosystem"
				typeset _flist="$(pathGetTempFile dball)"
				typeset _ftemp="$(pathGetTempFile dump)"
				typeset _dbname
				mysql.sh list \
					-service ${opt_service} \
					-database \
					-noheaders \
					-nocount \
					${_system} \
					-format csv > "${_flist}"
				let _ret=$?
				if [ ${_ret} -eq 0 ]; then
					cat "${_flist}" | f_all_filter | while read _dbname; do
						msgVerbose "about to dump '${_dbname}' database"
						f_db_dump "${_dbname}" > "${_ftemp}" 
						let _ret=$?
						[ ${_ret} -eq 0 ] && cat "${_ftemp}" | f_compress "${_dbname}"
						let _ret=$?
					done
				fi

			# save one database, all tables
			elif [ "${opt_table}" = "ALL" ]; then
				typeset _ftemp="$(pathGetTempFile dbone)"
				msgVerbose "about to dump '${opt_database}' database"
				f_db_dump "${opt_database}" > "${_ftemp}"
				let _ret=$?
				[ ${_ret} -eq 0 ] && cat "${_ftemp}" | f_compress "${opt_database}"
				let _ret=$?

			# only dump some tables specified as a comma-separated list
			else
				typeset _ftemp="$(pathGetTempFile tab)"
				typeset _tables="$(echo "${opt_table}" | sed -e 's/,/ /g')"
				msgVerbose "about to dump '${opt_database}' database, '${_tables}' table(s)"
				f_db_dump "${opt_database}" "${_tables}" > "${_ftemp}"
				let _ret=$?
				[ ${_ret} -eq 0 ] && cat "${_ftemp}" | f_compress "${opt_database}"
				let _ret=$?
			fi
		fi
	fi

	return ${_ret}
}
