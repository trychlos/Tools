# @(#) start services
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
# Synopsis:
#
# Notes:
#
#  - timeout=0 means unlimited
#
# sc  2001- 4-23 creation
# jcl 2001- 5-18 add options -M -a
# pwi 2002- 4-16 port to Citi Exploitation Aix
# raj 2002-12- 6 adapt to Gec architecture
# pwi 2002-12-27 archive logs in their own directory
# pwi 2003- 3-20 trap interrupts and delete temp files
# xle 2004- 6-18 use sqlplus /nolog instead of svrml
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6-10 migrate to command-line dynamic interpretation scheme
# pwi 2013- 6-17 add --mode option
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
service=<identifier>			service identifier
listener						start the listener
instance						start the instance
manager							start the manager
pfile=<pfile>					use this text parameter file
spfile=<spfile>					use this server parameter file
timeout=<timeout>				start timeout
mode={nomount|mount|open|restrict|force|recover} \
								database startup mode
show							display the output of the startup command
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
	opt_timeout_def="10"
	opt_mode_def="open"
	#opt_show_def="yes"
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
		msgErr "service mnemonic is mandatory, was not found"
		let _ret+=1
	fi

	# at least one option must be specified
	if [ "${opt_listener}" = "no" -a \
			"${opt_instance}" = "no" -a \
			"${opt_manager}" = "no" ]; then
				msgErr "no valid option found, at least one is mandatory"
				let _ret+=1
	fi

	# --pfile and --spfile options can only be used when starting the
	#  database instance
	if [ "${opt_pfile_set}" = "yes" -o "${opt_spfile_set}" = "yes" ]; then
		if [ "${opt_instance}" = "no" ]; then
			msgErr "'--pfile' or '--spfile' can only be used when starting the instance"
			let _ret+=1
		elif [ "${opt_pfile_set}" = "yes" -a "${opt_spfile_set}" = "yes" ]; then
			msgErr "'--pfile' and '--spfile' options are mutually exclusive"
			let _ret+=1
		fi
	fi

	# pfile/spfile files must exist
	if [ "${opt_pfile_set}" = "yes" ]; then
		if [ ! -s "${opt_pfile}" ]; then
			msgErr "'${opt_pfile}': parameter file not found or not available"
			let _ret+=1
		fi
	fi
	if [ "${opt_spfile_set}" = "yes" ]; then
		if [ ! -s "${opt_spfile}" ]; then
			msgErr "'${opt_spfile}': server parameter file not found or not available"
			let _ret+=1
		fi
	fi

	# mount mode is only allowed when starting a database instance
	if [ "${opt_mode_set}" = "yes" -a "${opt_instance}" = "no" ]; then
		msgErr "'--mode' option is only allowed when starting a database instance"
		let _ret+=1
	fi

	# if starting up the instance, the startup mode must be valid
	if [ "${opt_instance}" = "yes" ]; then
		opt_mode_upper="$(echo "${opt_mode}" | strUpper)"
		if [ "${opt_mode_upper}" != "NOMOUNT" -a \
				"${opt_mode_upper}" != "MOUNT" -a \
				"${opt_mode_upper}" != "OPEN" -a \
				"${opt_mode_upper}" != "RESTRICT" -a \
				"${opt_mode_upper}" != "FORCE" -a \
				"${opt_mode_upper}" != "RECOVER" ]; then
					msgErr "${_opt_mode}: invalid startup mode"
					let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	set -x
	typeset -i _ret=0

	# check which machine hosts the required service
	# whether we are starting a database instance, a listener or an
	# enterprise manager console, then we must start the service locally
	# on the target server, and with the right 'oracle' account

	typeset _host="$(tabGetMachine "${opt_service}")"
	typeset _user="$(oraGetOwner "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgErr "'${opt_service}': unknown service mnemonic"
		let _ret+=1
	fi
	if [ -z "${_user}" ]; then
		msgErr "'${opt_service}': unable to find owner account"
		let _ret+=1
	fi
	verbExitOnErr ${_ret}

	if [ "${_host}" != "${ttp_logical}" -o "${_user}" != "${USER}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}" "${_user}"
		verbExitOnErr $?
	fi

	# we are on the right host with the right account

	#set | grep -e '^opt_'

	# starting the listener
	if [ "${opt_listener}" = "yes" ]; then

		# check that the listener is not already running
		oracle.sh test -service "${opt_service}" -listener 1>/dev/null 2>&1
		if [ $? -eq 0 ]; then
			msgOut "listener for ${opt_service} is already running"
		else
			oraStartListener "${opt_service}"
			let _ret+=$?

				# check that the listener is running
			if [ ${_ret} -eq 0 ]; then
				oracle.sh test -service "${opt_service}" -listener 1>/dev/null 2>&1
				let _ret=$?
				if [ ${_ret} -ne 0 ]; then
					msgErr "${opt_service} listener has not been started"
					fi
				fi
			fi
		fi

		# starting the database
	if [ "${opt_instance}" = "yes" ]; then

			# check that the instance is not running
		oracle.sh test -service "${opt_service}" -instance 1>/dev/null 2>&1
		if [ $? -eq 0 ]; then
			msgOut "${opt_service} database instance is already running"

			# starting the instance with the required mode
		else
			if [ "${opt_mode_upper}" = "RECOVER" ]; then
				opt_mode_upper="OPEN RECOVER"
			fi
			oraStartDBInstance \
				"${opt_service}" \
				"${opt_pfile}" \
				"${opt_spfile}" \
				"${opt_timeout}" \
				"${opt_mode_upper}" \
				"${opt_show}"
				let _ret+=$?

				if [ ${_ret} -eq 0 ]; then
				# what is to be checked depending of the startup mode ?
				typeset -A _tests
				_tests=(
					["NOMOUNT"]="-processes -noconnect -noarchiver"
					["MOUNT"]="-processes -noconnect -noarchiver"
					["OPEN"]="-processes -connect"
					["RESTRICT"]="-processes -connect"
					["FORCE"]="-processes -connect"
					["OPEN RECOVER"]="-processes -connect"
				)
				oracle.sh test -service "${opt_service}" -instance ${_tests[${opt_mode_upper}]} 1>/dev/null 2>&1
				_ret=$?
				if [ ${_ret} -ne 0 ]; then
					msgErr "${opt_service} database instance has not been started"
					
			fi
		fi
	fi

	return ${_ret}
}
