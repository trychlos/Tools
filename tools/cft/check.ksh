# @(#) check the output of CFTUTIL LISTCAT CONTENT=FULL command
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
#   Get the output of the command on stdin
#   Does its check
#   Output the result
#
#   In order to verify that we are able to deal with all displayed
#   data, we are checking here the following points:
#
#    1. last line of each individual output is
#       'Network message size           RUSIZE   = 4056                '
#
#    2. as we are considering that each individual data is introduced
#       by an equal '=' sign, splitting per equal sign and counting;
#       we expect 101
#
#    3. date and time on the output are always displayed as individual
#       data, though we are going to concatenate them as a datetime
#       data so, must have as many date as time
#
#    4. when we eventually have consolidated datetime datas, we
#       should obtain 94 parameters
#
#    5. uppercase keywords will be the title of output columns; we
#       want them to be unique (or to be known to be not unique)
#       e.g. Type TYPE is FILE
#            Protocol Type TYPE is PESIT -> is subtituted with PTYPE
#
#    6. last control can also be visual and human-driven:
#       when a line has two individual data in it
#       (so two equal '=' signs), then ensure that the data value is
#       only one word - else we have no way of parsing the line...
#
#    As of CFT 2.7:
#    - last line per transfer is 'Network message size RUSIZE   = 4056'
#    - total 101 individual data
#    - finally 94 parameters post datetime concatenation
#    - 1 duplicate keyword TYPE
#    - all double-equals only take a single word value
#
# pwi 2013- 6-20 creation
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
fullcat					check LISTCAT CONTENT=FULL command output from stdin
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
#
#function verb_arg_set_defaults {
#}


# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	typeset -i _ret=0

	# at least one option must be specified
	if [ "${opt_fullcat}" = "no" ]; then
		msgerr "no option found, at least one is mandatory"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------

function f_check_full_listcat {
	typeset -i _ret=0

	# the output of CFTUTIL LISTCAT CONTENT=FULL for *one* transfer
	#  is isolated in its own temp file
	msgout "extracting *one* transfer from input stream..." "" " \b"
	typeset _ftmpunit="$(pathGetTempFile unit)"
	perl -ne '{
		chomp;
		s/^\s+//;
		s/\s+$//;
		next if !length;
		next if /^CFTU/;
		next if $last_seen;
		printf( "%s\n", $_ );
		$last_seen = 1 if m/Network message size\s+RUSIZE\s+=\s+\d+/;
	}' > "${_ftmpunit}"
	msgout "OK, $(wc -l "${_ftmpunit}" | awk '{ print $1 }') lines" " "

	# count individual data as marked by equal '=' sign
	typeset -i _expect=101
	msgout "checking for count of individual data [${_expect}]..." "" " \b"
	typeset _ftmpequal="$(pathGetTempFile equal)"
	sed -e 's?\(= \S*\)?\1\
?' "${_ftmpunit}" | grep '=' > "${_ftmpequal}"
	typeset -i _cdata=$(wc -l "${_ftmpequal}" | awk '{ print $1 }')

	if [ ${_cdata} -eq ${_expect} ]; then
		msgout "OK" " "
	else
		msgout "NOT OK" " "
		msgerr "${_cdata} individual data found instead of ${_expect}"
		let _ret+=1
	fi

	# as long as we are able to identify dates and times, count
	#  count them as we are going to concatenate them later
	msgout "checking for as many dates and times..." "" " \b"
	typeset _DATE="DATE|NEXTDAT"
	typeset _ftmpdate="$(pathGetTempFile date)"
	grep -E "${_DATE}" "${_ftmpequal}" > "${_ftmpdate}"
	typeset -i _cdate=$(wc -l "${_ftmpdate}" | awk '{ print $1 }')

	typeset _TIME="TIME|NEXTTIM"
	typeset _ftmptime="$(pathGetTempFile time)"
	typeset -i _ctime
	grep -E "${_TIME}" < "${_ftmpequal}" > "${_ftmptime}"
	typeset -i _ctime=$(wc -l "${_ftmptime}" | awk '{ print $1 }')

	if [ ${_cdate} -eq ${_ctime} ]; then
		msgout "OK, ${_cdate} found" " "
	else
		msgout "NOT OK" " "
		msgerr "${_cdate} dates vs. ${_ctime} times"
		cat "${_ftmpdate}" "${_ftmptime}"
		let _ret+=1
	fi

	# eventually count final parameters
	_expect=94
	msgout "checking for final count of parameters [${_expect}]..." "" " \b"
	typeset _ftmpparms="$(pathGetTempFile parms)"
	grep -vE "${_DATE}|${_TIME}" < "${_ftmpequal}" > "${_ftmpparms}"
	typeset -i _cparms=$(wc -l "${_ftmpparms}" | awk '{ print $1 }')
	typeset -i _call=${_cparms}+${_cdate}

	if [ ${_call} -eq ${_expect} ]; then
		msgout "OK" " "
	else
		msgout "NOT OK" " "
		msgerr "${_call} parameters found instead of ${_expect}"
		let _ret+=1
	fi

	# check for uppercase keywords : how many duplicates
	_expect=1
	msgout "checking for duplicate keywords [${_expect}]..." "" " \b"
	typeset _ftmpkey="$(pathGetTempFile key)"
	cat "${_ftmpequal}" | perl -ne '{
		chomp;
		s#^.*?([A-Z]+)\s+=.*#\1#;
		printf( "%s\n", $_ );
	}' > "${_ftmpkey}"
	typeset -i _ckey=$(wc -l "${_ftmpkey}" | awk '{ print $1 }')
	typeset _ftmpsorted="$(pathGetTempFile sorted)"
	sort -u < "${_ftmpkey}" > "${_ftmpsorted}"
	typeset -i _csorted=$(wc -l "${_ftmpsorted}" | awk '{ print $1 }')
	typeset -i _diff=${_ckey}-${_csorted}

	if [ ${_diff} -eq ${_expect} ]; then
		msgout "OK" " "
	else
		msgout "NOT OK" " "
		msgerr "${_diff} duplicates found instead of ${_expect}"
		let _ret+=1
	fi

	# visually inspect the double-equal lines
	msgout "visually check yourself for double-equal signs: must have a single-word data value..."
	grep -e '=.\+=' "${_ftmpunit}"

	return ${_ret}
}

# ---------------------------------------------------------------------

function verb_main {
	typeset -i _ret=0

	if [ "${opt_fullcat}" = "yes" ]; then

		f_check_full_listcat
		let _ret+=$?
	fi

	return ${_ret}
}
