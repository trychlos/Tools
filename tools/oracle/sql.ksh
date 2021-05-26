# @(#) execute a SQL connection to an Oracle instance
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
# vdo 1999- 1-12 creation
# jcl 1999- 6-14 script normalisation
# jcl 1999- 7-15 use svrmgrl connection
# raj 2002- 7-21 port to Citi Exploitation Aix
# pwi 2002- 8-18 homogenize command-line arguments
# pwi 2002-10- 8 fix temporary files removal
# gma 2003- 6-16 add whenever *error exit failure rollback
# gma 2003- 6-30 replace svrmgrl with SYSDBA calls
# gma 2003- 7- 4 add --quiet option
# gma 2003- 9- 8 fix return code when it is impossible to connect
# gma 2003-12- 3 execRemote for fexploit user
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
help					display this online help and gracefully exit
service=<identifier>	service identifier
user=<user>				username to use for the connection
script=<file>			sql script to be executed
command=<command>		sql command to be executed
interactive				open an interactive session
quiet					be quiet
sysdba					opens the connection as SYSDBA
show					display executed code
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
	opt_user_def="system"
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

	# we want execute a script, or a command, or open a session
	if [ "${opt_script_set}" = "no" -a \
			"${opt_command_set}" = "no" -a \
			"${opt_interactive}" = "no" ]; then
				msgerr "one of '--script', '--command' or '--interactive' option must be chosen"
				let _ret+=1
	else
		typeset -i _count=0
		# check for sql script option
		if [ "${opt_script_set}" = "yes" ]; then
			let _count+=1
			if [ -z "${opt_script}" -o ! -r "${opt_script}" ]; then
				msgerr "'${opt_script}': sql script not found or not available"
				let _ret+=1
			fi
		fi
		# check for sql command option
		if [ "${opt_command_set}" = "yes" ]; then
			let _count+=1
			if [ -z "${opt_command}" ]; then
				msgerr "'${opt_command}': sql command not found"
				let _ret+=1
			fi
		fi
		# or wants an interactive session ?
		if [ "${opt_interactive}" = "yes" ]; then
			let _count+=1
		fi
		# at last, we must choose one in these three options
		if [ ${_count} -ne 1 ]; then
			msgerr "only one of '--script', '--command' or '--interactive' option must be chosen"
			let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	#set | grep -e '^opt_'
	#echo "0=$0 #=$# *=$*"
	#set -x

	typeset -i _ret=0

	typeset _host="$(tabGetMachine "${opt_service}")"

	if [ -z "${_host}" ]; then
		msgerr "'${opt_service}': unknown service mnemonic"
		let _ret+=1

	elif [ "${_host}" != "${ttp_logical}" ]; then
		typeset _parms="$@"
		execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}"
		let _ret+=$?

	else
		# setup the environment
		oraSetEnv "${opt_service}"
		[ $? -eq 0 ] || { let _ret+=1; return ${_ret}; }

		# get the user's password
		typeset _passwd="$(getPassword "${ttp_environment}" "${opt_service}" "${opt_user}")"
		[ -z "${_passwd}" ] && { let _ret+=1; return ${_ret}; }

		[ "${opt_sysdba}" = "yes" ] && _passwd="${_passwd} as sysdba"

		typeset _options
		[ "${opt_quiet}" = "yes" ] && _options="-S"

		# interactive session
		# usage (11gr2): sqlplus [ [<option>] [{logon | /nolog}] [<start>] ]
		# <logon> is: {<username>[/<password>][@<connect_identifier>] | / }
		#   [AS {SYSDBA | SYSOPER | SYSASM}] [EDITION=value]
		if [ "${opt_interactive}" = "yes" ]; then
			sqlplus "${_options}" "${opt_user}"/"${_passwd}"
			[ $? -eq 0 ] || let _ret+=1

		# execute a command or a script
		# script file must have the '.sql' extension
		else
			typeset _command
			if [ "${opt_script_set}" = "yes" ]; then
				_ftmpscript="$(pathGetTempFile "script.sql")"
				(umask 0026; cp "${opt_script}" "${_ftmpscript}")
				_command="@${_ftmpscript}"
			else
				_command="$(echo "${opt_command}" | sed -e 's#\\\*#*#' -e 's#\\\$#$#')"
			fi

			typeset _ftmpsql="$(pathGetTempFile "tmp.sql")"
			( umask 0026; cat <<! >>"${_ftmpsql}"
whenever oserror  exit failure rollback
whenever sqlerror exit failure rollback
connect ${opt_user}/${_passwd}
${_command}
exit;
!
)
			if [ "${opt_show}" = "yes" ]; then
				cat "${_ftmpsql}"
			fi

        	_options="${_options} /NOLOG"
			sqlplus ${_options} "@${_ftmpsql}"
			[ $? -eq 0 ] || let _ret+=1
		fi
	fi

	return ${_ret}
}
