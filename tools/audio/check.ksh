# @(#) check tags validity
#
# @(@) This verb checks the validity of the tags in a tree of audio files.
# @(@) It is able to display all checked filenames, or only those which
# @(@) exhibit at least one error, or all found errors.
# @(@) In all cases, a dedicated log file summarizes all of theses.
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
# pwi 2021-11-26 creation

# ---------------------------------------------------------------------
# echoes the list of optional arguments
#  first word is the name of the option
#   an option is either boolean, or has an optional or mandatory argument
#  rest of line is the help message
#  'help', 'dummy', 'stamp', 'version' and 'verbose' options are standard
#   and - if used - their meaning should not be modified

function verb_arg_define_opt {
	echo "
help										display this online help and gracefully exit
verbose										verbose execution
path=<path>									the path to be (recursively) checked
debug										whether to display the internal variables
display=[none|checked|erroneous|allerrs]	display mode for checked filenames
maxcount=<n>								stop the execution after having checked <n> files
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
	opt_debug_def="no"
	opt_display_def="checked"
	opt_maxcount_def=-1
}

# ---------------------------------------------------------------------
# check arguments
#  all optional and positional arguments and their values have been set
#  default values have been applied if any

function verb_arg_check {
	#set -x
	typeset -i _ret=0

	# path is mandatory
	if [ -z "${opt_path}" ]; then
		msgerr "path is mandatory, has not been specified"
		let _ret+=1
	fi

	# display argument accepts only a set of values
	if [ "${opt_display}" != "none" \
		 -a "${opt_display}" != "checked"\
		 -a "${opt_display}" != "erroneous"\
		 -a "${opt_display}" != "allerrs" ]; then
		msgerr "'display' argument must be specified as none|checked|erroneous|all, '${opt_display}' found"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# check a file

function f_check {
	typeset _fname="${1}"
	typeset _data="$(f_ffmpeg "${_fname}")"
	varInc count
	#echo "${_data}"
	#set -x

	# extract relevant informations from the output of ffmpeg
	typeset _title="$(echo "${_data}" | grep -w TITLE | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset _artist="$(echo "${_data}" | grep -w ARTIST | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset _album_artist="$(echo "${_data}" | grep -w album_artist | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset _album="$(echo "${_data}" | grep -w ALBUM | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset _year="$(echo "${_data}" | grep -w DATE | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset -i _trackno="$(echo "${_data}" | grep -w track | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset -i _trackcount="$(echo "${_data}" | grep -w TRACKTOTAL | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset _encoder="$(echo "${_data}" | grep -w ENCODED-BY | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset -i _discno="$(echo "${_data}" | grep -w disc | awk '{ for( i=3; i<=NF; ++i ) printf( "%s%s", i>3?" ":"", $i )}')"
	typeset -i _has_image=$(f_has_image "${_data}")

	# extract relevant informations from the filename
	typeset _bname="${_fname##*/}"
	typeset _dir0="${_fname%/*}"
	typeset _bdir0="${_dir0##*/}"	# may be CD x or Disc x or the album
	typeset _dir1="${_dir0%/*}"
	typeset _bdir1="${_dir1##*/}"	# may be the album or the artist
	typeset _dir2="${_dir1%/*}"
	typeset _bdir2="${_dir2##*/}"	# may be the artist or the root
		
	# display internal variables if asked for
	if [ "${opt_debug}" == "yes" ]; then
		msgout "[debug] title='${_title}'"
		msgout "[debug] artist='${_artist}'"
		msgout "[debug] album_artist='${_album_artist}'"
		msgout "[debug] album='${_album}'"
		msgout "[debug] year='${_year}'"
		msgout "[debug] trackno=${_trackno}"
		msgout "[debug] trackcount=${_trackcount}"
		msgout "[debug] encoder='${_encoder}'"
		msgout "[debug] discno=${_discno}"
		msgout "[debug] has_image=${_has_image}"
	fi
	
	# check informations
	typeset _i _errors=0

	# title should be set
	if [ -z "${_title}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Title' is not set"
	fi

	# artist should be set
	if [ -z "${_artist}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Artist' is not set"
	fi

	# album artist should be set
	if [ -z "${_album_artist}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Album Artist' is not set"
	fi

	# album should be set
	if [ -z "${_album}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Album' is not set"
	fi

	# year should be set and be 4 digits
	if [ -z "${_year}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Year' is not set"
	else
		typeset _result="$(echo "${_year}" | awk '/^[0-9]{4,4}$/')"
		if [ "${_result}" != "${_year}" ]; then
			let _errors+=1
			f_error "${_fname}: Year=${_year} is not a four-digits value"
		fi
	fi

	# track number should be set
	if [ -z "${_trackno}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Track number' is not set"
	fi

	# track count should be set
	if [ -z "${_trackcount}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Track count' is not set"
	fi

	# encoder should be set
	if [ -z "${_encoder}" ]; then
		let _errors+=1
		f_error "${_fname}: 'Encoder' is not set"
	fi

	# disc number should only be set when there are several discs in the album

	# the filename should be built as
	#	<trackno> - <title>.<extension>
	if [ ! -z "${_title}" -a ! -z "${_trackno}" ]; then
		typeset _expected="${_trackno} - ${_title}"
		typeset _found="${_bname%.*}"
		typeset _ext="${_bname##*.}"
		if [ "${_expected}" != "${_found}" ]; then
			let _errors+=1
			f_error "${_fname}: '${_expected}.${_ext}' expected"
		fi
	fi

	if [ ${_errors} -eq 0 ]; then
		varInc ok
	else
		varInc notok
		varAdd total ${_errors}
	fi

	msgLog "${_fname}: errors count = ${_errors}"
	msgLog "count=$(varGet count) ok=$(varGet ok) notok=$(varGet notok)"
	
	if [ "${opt_display}" == "checked" ]; then
		msgout "${_fname}: errors count = ${_errors}"
	fi
	if [ "${opt_display}" == "erroneous" -a ${_errors} -gt 0 ]; then
		msgout "${_fname}: errors count = ${_errors}"
	fi
}

# ---------------------------------------------------------------------
# display an error message, and write it in a temp file

function f_error {
	typeset _msg="${1}"
	
	echo "${_msg}" >> $(pathGetTempFile errors)
	
	if [ "${opt_display}" == "allerrs" ]; then
		msgerr "${_fname}: ${_msg}"
	else
		msgLog "${_fname}: ${_msg}"
	fi
}

# ---------------------------------------------------------------------
# ffmpeg informations
#
# ffmpeg displays its output on stderr
# relevant data starts at the line 'input #0', and may contain
# - metadata for the file (first and second indentation levels)
# - duration
# - list of streams (audio / video)
# - metadata for each stream
#
# (O): this function echoes the relevant data on stdout as a string's list

function f_ffmpeg {
	typeset _fname="${1}"
	typeset _line
	typeset -i _relevant=0
	typeset _output=""
	typeset _ifs="${IFS}"
	IFS=''

	ffmpeg -i "${_fname}" 2>&1 | while read _line; do
		#echo "${_line}"
		if [ "${_line:0:8}" == "Input #0" ]; then
			let _relevant=1
		fi
		if [ ${_relevant} -eq 1 ]; then
			# last informational message outputed by ffmpeg, removed from there
			if [ "${_line}" != "At least one output file must be specified" ]; then
				if [ ! -z "${_output}" ]; then
					_output="${_output}
"
				fi
				_output="${_output}${_line}"
			fi
		fi
	done

	IFS="${_ifs}"
	echo "${_output}"
}

# ---------------------------------------------------------------------
# check if ffmpeg has detected an image
# we read the Video informations if any
# (O): outputs 1 (true) or 0

function f_has_image {
	typeset _data="${1}"
	typeset _line
	typeset -i _has_image=0
	
	echo "${_data}" | while read _line; do
		#echo "${_line}"
		if [ "$(echo "${_line}" | grep "Stream #0:")" != "" ]; then
			#echo "has stream" 1>&2
			if [ "$(echo "${_line}" | grep "Video:")" != "" ]; then
				#echo "has video" 1>&2
				if [ "$(echo "${_line}" | grep "attached pic")" != "" ]; then
					#echo "has attached pic" 1>&2
					let _has_image=1
					break
				fi
			fi
		fi
	done
	
	echo ${_has_image}
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0
	typeset _fname

	msgout "a summary of found errors will be available in '$(pathGetTempFile errors)' file"
	touch $(pathGetTempFile errors)
	
	varSet count 0
	varSet ok 0
	varSet notok 0
	varSet total 0

	find "${opt_path}" -type f | grep -vE 'jpeg|jpg|png' 2>/dev/null | while read _fname; do
		f_check "${_fname}"
		if [ ${opt_maxcount} -gt 0 -a $(varGet count) -ge ${opt_maxcount} ]; then
			msgout "stopping the check after ${opt_maxcount} files"
			break
		fi
	done

	msgout "$(varGet count) files checked"
	msgout "  $(varGet ok) are fully ok"
	msgout "  $(varGet notok) exhibit at least one error"
	msgout "    $(varGet total) total error(s)"

	msgout "a summary of found errors is available in '$(pathGetTempFile errors)' file" 
	
	return ${_ret}
}
