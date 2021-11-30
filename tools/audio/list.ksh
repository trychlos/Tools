# @(#) list artists, albums, tracks from our audio library
#
# @(#) Scans the specified path as an on-file audio library, and
# @(#) tries to list tracks, albums and/or artists.
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
album							whether to display the list of found albums
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
	opt_album_def="no"
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

	return ${_ret}
}

# ---------------------------------------------------------------------
# get the album out of the file
# writes it out to the allocated temp file

function f_getAlbum {
	typeset _fname="${1}"
	typeset _data="$(audioFileInfo "${_fname}")"
	varInc count

	# extract relevant informations
	typeset _album="$(audioInfo2Album "${_data}")"
	typeset _album_artist="$(audioInfo2AlbumArtist "${_data}")"
	
	if [ -z "${_album}" ]; then
		msgErr "${_fname}: 'Album' information is not set"
		varInc errors_album
	elif [ -z "${_album_artist}" ]; then
		msgErr "${_fname}: 'AlbumArtist' information is not set"
		varInc errors_albumartist
	else
		echo "${_album}${_sep}${_album_artist}" >> "$(pathGetTempFile albums)"
	fi
}

# ---------------------------------------------------------------------
# display an error message, and write it in a temp file

function f_error {
	typeset _msg="${1}"
	
	echo "${_msg}" >> $(pathGetTempFile errors)
	
	if [ "${opt_display}" == "allerrs" ]; then
		msgErr "${_fname}: ${_msg}"
	else
		msgLog "${_fname}: ${_msg}"
	fi
}

# ---------------------------------------------------------------------

function verb_main {
	#set -x
	typeset -i _ret=0
	typeset _fname
	typeset _sep="|"

	varSet count 0
	varSet errors_album 0
	varSet errors_albumartist 0

	typeset _falbums="$(pathGetTempFile albums)"
	typeset _sorted="$(pathGetTempFile albums-sorted)"

	audioPathScan "${opt_path}" | while read _fname; do
		f_getAlbum "${_fname}"
	done

	msgOut "$(varGet count) files checked"
	msgOut "  $(varGet errors_album) files have been found without any 'Album' field set"
	msgOut "  $(varGet errors_albumartist) files have been found without any 'AlbumArtist' field set"

	if [ "${opt_album}" == "yes" ]; then
		sort --ignore-case --ignore-leading-blanks --field-separator=${_sep} --keydef 1,1 --unique "${_falbums}" > "${_sorted}"
		typeset -i count_albums=$(wc -l "${_sorted}" | awk '{ print $1 }')

		typeset _line
		typeset _album
		typeset _artist
		cat "${_sorted}" | while read _line; do
			_album="$(echo "${_line}" | awk -F${_sep} '{ print $1 }')"
			_artist="$(echo "${_line}" | awk -F${_sep} '{ print $2 }')"
			msgOut "found: ${_album}\t${_artist}"
		done
		msgOut "  ${count_albums} found distinct albums"
	fi 
		
	return ${_ret}
}
