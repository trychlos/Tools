# @(#) list artists, albums, tracks from our audio library
#
# @(#) Scans the specified path as an on-file audio library, and tries to list albums.
# @(#) The output may be as raw strings or in tabular form (à la SQL), and can be accompanied
# @(#) by a CSV file.
# @(#) Please note that albums are identified based on the meta-informations found in the
# @(#) scanned files.
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
# pwi 2021-11-29 creation

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
path=<path>						the path to be (recursively) scanned
maxcount=<n>					stop the execution after having checked <n> files
albums							whether to display the list of found albums
display=standard|tabular|none	selection of the output format
csv=<path> 						whether to output the list into a CSV file
wdate							warn if 'Date' information is not set
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
	opt_help_def="no"
	opt_verbose_def="no"
	opt_maxcount_def=-1
	opt_albums_def="no"
	opt_display_def="standard"
	opt_csv_def=""
	opt_wdate_def="yes"
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
		msgErr "path is mandatory, has not been specified"
		let _ret+=1
	fi

	# display must be standard|tabular|none
	if [ "${opt_display}" != "standard" -a "${opt_display}" != "tabular" -a "${opt_display}" != "none" ]; then
		msgErr "invalid 'display' option, '${opt_display}' found, 'standard', 'tabular' or 'none' expected"
		let _ret+=1
	fi

	return ${_ret}
}

# ---------------------------------------------------------------------
# display the list of found albums

function f_displayAlbums {
	typeset _flist="${1}"
	typeset _sep="${2}"

	typeset _sorted="$(pathGetTempFile albums-sorted)"
	typeset _title="$(pathGetTempFile albums-title)"

	# sort the list by album name
	# note that 'LC_ALL=C' doesn't fix the issue where 'État d'urgence' is sorted at the very last
	LC_ALL=C sort --ignore-case --ignore-leading-blanks --field-separator=${_sep} --key 1,1 --key 3,3 --unique "${_flist}" > "${_sorted}"
	typeset -i _count_albums=$(wc -l "${_sorted}" | awk '{ print $1 }')

	if [ "${opt_display}" == "standard" ]; then
		typeset _line
		cat "${_sorted}" | while read _line; do
			typeset _album="$(echo "${_line}" | cut -d${_sep} -f1)"
			typeset _date="$(echo "${_line}" | cut -d${_sep} -f2)"
			typeset _artist="$(echo "${_line}" | cut -d${_sep} -f3)"
			typeset _tracks="$(echo "${_line}" | cut -d${_sep} -f4)"
			msgOut "found album '${_album}' [${_date}] by '${_artist}' (tracks=${_tracks})"
		done
		msgOut "found ${_count_albums} distinct albums"
	
	elif [ "${opt_display}" == "tabular" ]; then
		echo "Album${_sep}Date${_sep}Artist${_sep}Tracks" > "${_title}"
		cat "${_title}" "${_sorted}" | csvToTabular yes yes "" "" yes
	fi

	if [ ! -z "${opt_csv}" ]; then
		echo "Album${_sep}Date${_sep}Artist${_sep}Tracks" > "${_title}"
		cat "${_title}" "${_sorted}" > "${opt_csv}"
		msgOut "${_count_albums} lines written in ${opt_csv}"
	fi
}

# ---------------------------------------------------------------------
# read meta informations from each scanned file
# because this operation is costly, it is mutualized between all command
# options

function f_readMetaInformations {
	typeset _fname="${1}"
	typeset _sep="${2}"

	typeset _data="$(audioFileInfo "${_fname}")"
	varInc count

	# extract relevant informations
	typeset _album="$(audioInfo2Album "${_data}")"
	typeset _date="$(audioInfo2Date "${_data}")"
	typeset _album_artist="$(audioInfo2AlbumArtist "${_data}")"
	typeset _tracks="$(audioInfo2TrackCount "${_data}")"

	# only album is really needed when displaying the list of albums
	# other informations may be unavailable 
	if [ -z "${_album}" ]; then
		msgErr "${_fname}: 'Album' information is not set"
		varInc errors_album
	fi
	if [ -z "${_album_artist}" ]; then
		msgErr "${_fname}: 'AlbumArtist' information is not set"
		varInc errors_albumartist
	fi
	if [ -z "${_date}" ]; then
		if [ "${opt_wdate}" == "yes" ]; then
			msgErr "${_fname}: 'Date' information is not set"
		fi
		varInc errors_date
	fi
	if [ -z "${_tracks}" ]; then
		msgErr "${_fname}: 'TrackCount' information is not set"
		varInc errors_tracks
	fi
	if [ "${opt_albums}" == "yes" -a ! -z "${_album}" ]; then
		echo "${_album}${_sep}${_date}${_sep}${_album_artist}${_sep}${_tracks}" >> "$(pathGetTempFile albums)"
	fi
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0
	typeset _sep=";"

	varSet count 0
	varSet errors_album 0			# album not set
	varSet errors_albumartist 0		# album artist not set
	varSet errors_date 0			# date not set
	varSet errors_tracks 0			# tracks not set

	typeset _fname
	audioPathScan "${opt_path}" | while read _fname; do
		f_readMetaInformations "${_fname}" "${_sep}"
		if [ ${opt_maxcount} -gt 0 -a $(varGet count) -ge ${opt_maxcount} ]; then
			msgOut "stopping the scan after ${opt_maxcount} files"
			break
		fi
	done

	msgOut "$(varGet count) files checked"
	msgOut "  $(varGet errors_album) files have been found without 'Album' field set"
	msgOut "  $(varGet errors_albumartist) files have been found without 'AlbumArtist' field set"
	msgOut "  $(varGet errors_date) files have been found without 'Date' field set"
	msgOut "  $(varGet errors_tracks) files have been found without 'TrackCount' field set"

	if [ "${opt_albums}" == "yes" ]; then
		f_displayAlbums "$(pathGetTempFile albums)" "${_sep}"
	fi 
		
	return ${_ret}
}
