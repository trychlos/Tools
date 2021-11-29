# @(#) stop running services
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
# vdo 1999- 1-11 creation
# raj 2002-12- 6 port to Gec environment
# pwi 2002-12-27 logs are kept
# pwi 2003- 3-17 fix stop instance
# pwi 2003- 3-24 trap interrupts and delete temp files
# gma 2003-10- 1 automatic fallback between base status
# pwi 2006-10-27 the tools become The Tools Project, released under GPL
# pwi 2013- 6-10 migrate to command-line dynamic interpretation scheme
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
listener						stop the listener
instance						stop the instance
timeout=<value>					shutdown timeout
mode={normal|immediate|transactional|abort} \
								shutdown mode 
show							display the output of the shutdown command
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
	#opt_mode_def="normal"
	opt_mode_def="immediate"
	#opt_show_def="yes"
}

# ---------------------------------------------------------------------

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
			"${opt_instance}" = "no" ]; then
				msgErr "no valid option found, at least one is mandatory"
				let _ret+=1
	fi

	# check for shutdown mode of the instance
	if [ "${opt_instance}" = "yes" ]; then
		opt_mode_upper="$(echo "${opt_mode}" | strUpper)"
		if [ "${opt_mode_upper}" != "NORMAL" -a \
				"${opt_mode_upper}" != "IMMEDIATE" -a \
				"${opt_mode_upper}" != "TRANSACTIONAL" -a \
				"${opt_mode_upper}" != "ABORT" ]; then
					msgErr "${opt_mode}: invalid shutdown mode"
					let _ret+=1
		fi
	fi

	# shutdown mode only applies when stopping a database instance
	if [ "${opt_mode_set}" = "yes" -a \
			"${opt_instance}" = "no" ]; then
				msgErr "shutdown mode only applies when stopping the instance"
				let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0

	# check which machine hosts the required service
	typeset _host="$(tabGetMachine "${opt_service}")"
	typeset _user="$(oraGetOwner "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgErr "'${opt_service}': unknown service mnemonic"
		let _ret+=1

	elif [ -z "${_user}" ]; then
		msgErr "'${opt_service}': unable to find owner account"
		let _ret+=1

	elif [ "${_host}" != "${ttp_logical}" -o "${_user}" != "${USER}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}" "${_user}"
		let _ret+=$?

	else
		# we are on the right host with the right account

		#set | grep -e '^opt_'

		# stopping the listener
		if [ "${opt_listener}" = "yes" ]; then

			typeset _name="$(oraGetListener "${opt_service}")"
			typeset -i _count=$(ps -e -o cmd | grep tnslsnr | grep "${_name}" | wc -l)
			if [ ${_count} -eq 0 ]; then
				msgOut "listener for ${opt_service} is not running"
			else
				oraStopListener "${opt_service}" "${_name}"
				let _ret+=$?
			fi
		fi

		# stopping the database
		if [ "${opt_instance}" = "yes" ]; then

			# check that the instance is running (database is not relevant here)
			#  if not running, this is fine for this verb
			typeset -i _count=$(ps -e -o cmd | grep -e "^ora_.\+_${ORACLE_SID}" | wc -l)
			if [ ${_count} -eq 0 ]; then
				msgOut "${opt_service} database is not running"

			# only then, try to stop the instance
			else
				oraStopDBInstance \
					"${opt_service}" \
					"${opt_mode_upper}" \
					"${opt_timeout}" \
					"${opt_show}"
				let _ret=$?
			fi
		fi
	fi

	return ${_ret}
}
