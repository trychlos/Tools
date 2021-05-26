# @(#) use SQL*Loader to load data into a schema
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
#   See http://docs.oracle.com/cd/B28359_01/server.111/b28319/ldr_concepts.htm
#   As SQL*Loader is able to load data through a network, we should have
#   no imperious need to execRemote to the database server. Actually, we
#   will work fully locally as soon as we have the binary in our path.
#   We fallback else to execRemote to the server.
#
#   Note: SQL*Loader silently requires its input/output files be sufixed
#         with ad-hoc extensions (.dat, .ctl, .bad, .dsc and .log) - We
#         take care of that if the user let the verb automatically choose
#         its output files; but we cannot do anything about input files. 
#
# jcl 2000-10-10 creation
# fv  2003- 2-21 port to Citi Exploitation Aix
# pwi 2003- 3- 5 get password via getPassword
# pwi 2003- 3-10 when only one line is loaded
# pwi 2003- 6-11 exit gracefully if maximum errors if not reached
# gma 2003- 8- 7 loading several tables in one session
# xle 2003- 9- 8 consider the SQL*Loader return code
# xle 2005- 1-24 add verbose mode
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
user=<user>				connecting user
data={<file>|-|*}		input data filename
control=<file>			format control filename
bad=<file>				output bad records filename
discard=<file>			output discarded records filename
logs=<file>				output logs filename
maxerrors=<count>		maximum count of errors
show					display output and logs
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
	opt_data_def="-"
	opt_bad_def="auto"
	opt_discard_def="auto"
	opt_logs_def="auto"
	opt_maxerrors_def="10"
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
		msgerr "service mnemonic is mandatory, was not found"
		let _ret+=1
	fi

	# if data file is specified, then must exists
	#  else will be read from stdin
	if [ "${opt_data}" != "-" -a "${opt_data}" != "\*" ]; then
		if [ ! -r "${opt_data}" ]; then
			msgerr "${opt_data}: data file not found or not available"
			let _ret+=1
		else
			typeset _sufix="${opt_data##*.}"
			if [ "${_sufix}" != "dat" ]; then
				msgerr "${opt_data}: data file must have a '.dat'-suffix"
				let _ret+=1
			fi
		fi
	fi

	# control data file is mandatory
	#  and must be exists
	if [ -z "${opt_control}"  ]; then
		msgerr "'--control' control format file is mandatory"
		let _ret+=1
	elif [ ! -r "${opt_control}" ]; then
		msgerr "${opt_control}: control file not found or not available"
		let _ret+=1
	else
		typeset _sufix="${opt_control##*.}"
		if [ "${_sufix}" != "ctl" ]; then
			msgerr "${opt_control}: data file must have a '.ctl'-suffix"
			let _ret+=1
		fi
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# get a local copy of input files if needed
#  the local copy is stored in /tmp, so that it will be candidate to
#  automatic cleanup at the end of the command
#
# (I): 1. option mnemonic
# (O): stdout: filename of the local copy

function f_input {
	typeset _opt="${1}"

	typeset _value="$(echo $(eval echo '${opt_'${_opt}'}'))"

	# TODO: get a local copy of input files

	echo "${_value}"
}

# ---------------------------------------------------------------------
# compute the path of output files
#
# (I): 1. option mnemonic
#      2. default value

function f_output {
	typeset _opt="${1}"
	typeset _def="${2}"

	typeset _value="$(echo $(eval echo '${opt_'${_opt}'}'))"
	if [ -z "${_value}" -o "${_value}" = "auto" ]; then
		eval $(echo 'opt_'${_opt}="$(pathGetTempFile "${_def}")")
		msgout "output '${_opt}' file goes to $(echo $(eval echo '${opt_'${_opt}'}'))"
	fi
}

# ---------------------------------------------------------------------

function verb_main {
	#set | grep -e '^opt_'
	#set -x

	typeset -i _ret=0

	# if SQL*Loader is in our path, then no need to execRemote to the
	#  server; just adjust required ORACLE_HOME if needed
	typeset _local="no"
	typeset _ftmpldr="$(pathGetTempFile ldr)"
	sqlldr 1>"${_ftmpldr}" 2>&1

	# we do have a local SQL*Loader in our PATH, and it is correctly set
	#  just use it
	if [ $? -ne 0 ]; then

		# we do have a local SQL*Loader in our PATH, just missing its
		#  ORACLE_HOME path; set it and run
		if [ $(grep -c "Message 2100 not found" "${_ftmpldr}") -gt 0 ]; then
			typeset _path="$(which sqlldr)"
			_path="${_path%/*}"
			export ORACLE_HOME="${_path%/*}"

		# no chance, have to execRemote to the server
		else
			typeset _host="$(tabGetMachine "${opt_service}")"
			if [ -z "${_host}" ]; then
				msgerr "'${opt_service}': unknown service mnemonic"
				return 1
			fi

			if [ "${_host}" != "${ttp_logical}" ]; then
				# TODO: if input data file is to be read from stdin
				#        then read it before execRemote and store into a temp file
				#        and adjust the arguments accordingly
				typeset _parms="$@"
				execRemote "${_host}" "${ttp_command} ${ttp_verb} ${_parms}" "${opt_user}"
				return $?
			fi

			# setup the environment
			oraSetEnv "${opt_service}"
			[ $? -eq 0 ] || return 1
		fi
	fi

	# at this time, we do have an operational SQL*Loader
	#  but the service mnemonic may not have been validated

	# get the user's password
	typeset _passwd="$(getPassword "${ttp_environment}" "${opt_service}" "${opt_user}")"
	[ -z "${_passwd}" ] && { let _ret+=1; return ${_ret}; }

	# compute the path of output files
	f_output "bad" "sqlldr.bad"
	f_output "discard" "sqlldr.dsc"
	f_output "logs" "sqlldr.log"

	# if needed, get a local copy of input files
	opt_data="$(f_input "data")"
	[ -z "${opt_data}" ] && { let _ret+=1; return ${_ret}; }
	opt_control="$(f_input "control")"
	[ -z "${opt_control}" ] && { let _ret+=1; return ${_ret}; }

	# import data
	typeset _options="${opt_user}/${_passwd}"
	_options="${_options} bad=${opt_bad}"
	_options="${_options} discard=${opt_discard}"
	_options="${_options} log=${opt_logs}"
	if [ "${opt_data}" = "-" ]; then
		_options="${_options} data=\'-\'"
	elif [ "${opt_data}" != "\*" ]; then
		_options="${_options} data=${opt_data}"
	fi
	_options="${_options} control=${opt_control}"
	_options="${_options} errors=${opt_maxerrors}"

	#set -x
	if [ "${opt_show}" = "yes" ]; then
		_ftmpldr=""
		sqlldr ${_options} | \
			perl -ne '{
				chomp;
				next if !length;
				next if /^SQL\*Loader/;
				next if /^Copyright /;
				print "log> $_\n";
			}'
	else
		_ftmpldr="$(pathGetTempFile sqlldr.stdout)"
		sqlldr ${_options} 1>"${_ftmpldr}" 2>&1
	fi
	typeset -i _retldr=$?
	[ ${_retldr} -gt 0 ] && let _ret=1
	msgout "sqlldr returns with code ${_retldr}"

	typeset -i _nberrs=0
	[ -s ${opt_bad} ] && _nberrs+=$(wc -l ${opt_bad} | awk '{ print $1 }')
	[ -s ${opt_discard} ] && _nberrs+=$(wc -l ${opt_discard} | awk '{ print $1 }')
	typeset -i _nbrows=$(awk '/successfully loaded\./ { count+=$1 } END { print count }' "${opt_logs}")
	if [ "${opt_show}" = "yes" ]; then
		perl -ne '{
			chomp;
			next if !length;
			next if /^SQL\*Loader/;
			next if /^Copyright /;
			print "log> $_\n";
		}' "${opt_logs}"
	fi
	msgout "${_nbrows} rows successfully loaded"
	msgout "${_nberrs} bad or discarded input records"
	[ ${_nberrs} -gt ${opt_maxerrors} ] && let _ret+=1

	return ${_ret}
}
