#!/usr/bin/bash
# somikroarc.sh - a script for generating integrity verifyable archives of entire filesystem trees
# providing different generation and auditing modes
# Published under GNU GPL 3.0 License
#
version="1.15"
author="somikro"
reldate="V1.15 2025-11-25 20:38"

# Based on this code in compliance with GNU GPL 3.0: 
# 
# ======================================================================
# READ INI FILE with Bash
# https://axel-hahn.de/blog/2018/06/08/bash-ini-dateien-parsen-lesen/
#
#  Author:  Axel hahn
#  License: GNU GPL 3.0
#  Source:  https://github.com/axelhahn/bash_iniparser
#  Docs:    https://www.axel-hahn.de/docs/bash_iniparser/
# ----------------------------------------------------------------------
# Many thanks to Axel Hahn
#
# yad is used in version 14.1+ from https://github.com/v1cont/yad
# Many thanks to Victor Ananjevsky 
#
# Furthermore this software is based on the following programs from debian repositories
# zip, unzip, hashdeep, bzip2
# 

{
	stcmd="$0 $*"
	script_name=$( basename "$0" )
	script_loc="$(realpath "$(dirname "$0")")"
	startTS=$(date +%s%N)
	today="$(date +%Y-%m-%d)"
	sysnam=$(hostname)
}
{
	declare -A settings
	settings["confloc"]="$HOME/.config/somikro"
	settings["conf_bn"]="somikro.conf"
	settings["logloc"]="$HOME/.logs/somikro"
	settings["tmpdir"]="/tmp"
	settings["ramdir"]="/tmp/ramdir"
	settings["ramdirSize"]="1000M"
	settings["ramonly"]=1
	settings["exdir"]="somikroarc"
	settings["vm"]=1
	settings["hm"]=2
	settings["am"]=3
	settings["cm"]=3
	settings["fulllog"]=1
	settings["hashalgs"]="sha256 sha1 md5"
	settings["halg"]="sha1"
	settings["hashopt"]=" -r -o fe -l "
	settings["auditopt"]=" -a -vv -r -o fe -l "
	settings["tasklist_width"]=800
	settings["tasklist_height"]=300
	settings["gui_delay"]='500'
	settings["cssfile"]="$HOME/.config/somikro/somikroarc.css"
	settings["tablog"]="$HOME/.logs/somikro/somikroarc.tab"
	settings["atype"]="zip"
	settings["zipopt"]=" -8 -Z bzip2 -nw -q -UN q -y -r "
	settings["unzipopt"]=" -0 "
}
{
	reqcmds=( "zip" "unzip" "hashdeep" "yad" "bzip2" )
	declare -i create=0
	declare -i audit=0
	declare -i tst=0
	declare -i errmark=0
	declare -i timeout=5
	declare -a arglist
	declare -a sizelist
	declare -i nvc=0
	hvf_bn=""
	hvf_fp=""
	hvf_rp=""
	hvf_MD=""
	af_bn=""
	itm_pn=""
	logfile_fp=""
	itmtype=""
	arcert_bn=""
	ramdir=""
	cwd=""
	itm_bn=""
	itm_fp=""
	itm_rp=""
	pdir_fp=""
	pdir_rp=""
	tmpdir=""
	declare -a files
	declare -a tmparr
	declare -a hashalgs
	declare -a unzipopt
	declare -a hashopt
	declare -a auditopt
	declare -a zipopt
	declare -i taskstart=0
	declare -i hashstart=0
	declare -i arcstart=0
	declare -i exstart=0
	declare -i audstart=0
	hashtime="0"
	arctime="0"
	extime="0"
	audtime="0"
	declare -a itemlist
	declare -a itmsizelist
	declare -a itmcntlist
	declare -a begtlist
	declare -a hashtlist
	declare -a arctlist
	declare -a extlist
	declare -a audtlist
	declare -a arcsizelist
	declare -a donelist
	declare -a deltlist
	declare -i curtask
	donestat=""
	declare -a yaddata
	declare -a dellist
	action=''
	declare -i gui_tl_updTS=''
	declare -i YAD_TASKLIST_PID
	declare -i	YAD_MAINWIN_PID
}
function get_runtime () {
	local curTS
	curTS=$(date +%s%N)
	local runtime
	runtime=$(( (curTS - startTS) / 1000000 ))
	somilog "$(printf "Elapsed Time: %'.fms" "$runtime")"
}
function calc_deltaT () {
	local -n tstr=$1
	local -n refts=$2
	local deltaT
	local deltaTs
	deltaT=$(( $(date +%s%N) - refts  ))
	deltaTs=$( echo "scale=3; $deltaT/1000000000" | bc)
	deltaTs="${deltaTs/./,}"
	somilog "calc_deltaT: deltaTs:$deltaTs" 3
	printf -v tstr "%'.2f" "$deltaTs"
	somilog "calc_deltaT: deltaT:$deltaT printstring:$tstr" 3
	somilog "$(printf "calc_deltaT: deltaT:%'.fns" "$deltaT")" -3
}
function term_script () {
	local reason=$1
	case "$reason" in
		"err")
				echo -e >&4 "
				echo -e >&4 "##################  Check Log #####################\n"
				gui_err "General Error - Check Log"
				;;
		"end")
				summarize
				echo -e >&4 "All Done \n"
				;;
		"reqcmds")
				echo -e >&4 "Required commands missing\n"
				echo -e >&4 "##################  Check Log #####################\n"
				somilog "term_script: ###  Required commands missing ### at check_reqcmds" -1
				;;
		"conf")
				echo -e >&4 "##############  Configuration Error #####################\n"
				echo -e >&4 "##################  Check Log #####################\n"
				somilog "term_script: ###  Configuration Error ### at read_conf or prep_log" -1
				;;
		"timeout")
				echo -e >&4 "Timeout missed to confirm start of archiving\n"
				somilog "term_script: ${timeout}s timout passed with no user confirmation to start archiving" -1
				;;
		"nosel")
				echo -e >&4 "No item selected for proccessing\n"
				somilog "Terminating because no item was selected for proccessing" -1
				;;
		"testing")
				echo -e >&4 "End of Test"
				somilog "term_script: End of Test" -1
				;;
		"breakpt")
				echo -e >&4 "Terminated from breakpoint"
				somilog "term_script: Terminated from breakpoint" -1
				;;
	esac
	get_runtime
	echo >&4 "Press enter to Exit"
	read -r
	kill -9 $YAD_MAINWIN_PID &>/dev/null
	exec 3>&-
	exec 5>&-
	[ "$reason" == "end" ] && exit 0 || exit 1
}
function time_from_ts () {
	local nsts="$1"
	local delt_ms
	local delt_s
	local ms
	delt_ms=${nsts:0:-6}
	delt_s=${delt_ms:0:-3}
	ms="${delt_ms: -3}"
	echo "$(date -d @"$delt_s" "+%Y-%m-%d_%H:%M:%S").$ms"
}
function nsts2msts () {
	local nsts="$1"
	echo "${nsts:0:-6}"
}
function summarize () {
	local taskcnt=${#itemlist[@]}
	declare -i i
	local printstr
	local tablogstr
	local dirdelt
	declare -i begts
	declare -i delts
	printstr=""
	tablogstr=""
	for (( i=0; i<taskcnt; i++ )); do
		if [ -n "${deltlist[$i]}" ] ; then
			dirdelt=$(time_from_ts "${deltlist[$i]}")
			somilog "summarize: DirDelTime:$dirdelt" -1
		else
			dirdelt=0
		fi
		printstr+="\t${itemlist[i]}\tsize:${sizelist[$i]}\tfcnt:${itmcntlist[$i]}\that:${hashtlist[$i]}\tart:${arctlist[$i]}\text:${extlist[$i]}\taut:${audtlist[$i]}\tasize:${arcsizelist[$i]}\tdirdelt:$dirdelt"
		(( i<taskcnt-1 )) && printstr+="\n"
		somilog "summarize: begt:${begtlist[i]} delt:${deltlist[i]}" -1
		begts=$(nsts2msts "${begtlist[i]}" )
		if [ -n "${deltlist[i]}" ] ; then
			delts=$(nsts2msts "${deltlist[i]}" )
		else
			delts=0
		fi
		tablogstr+="$begts\t$action\t${settings["cm"]}\t${settings["hm"]}\t${settings["am"]}\t$sysnam\t${itemlist[i]}\t${sizelist[i]}\t${itmcntlist[i]}\t${settings["halg"]}\t${hashtlist[i]}\t${settings["atype"]}\t${arctlist[i]}\t${arcsizelist[i]}\t${extlist[i]}\t${audtlist[i]}\t$delts"
		(( i<taskcnt-1 )) && tablogstr+="\n"
	done
	somilog "------------------------- Task Summary -------------------------------" -1
	somilog "$stcmd" -1
	somilog "${taskcnt} tasks successfully completed\n$printstr" -1
	somilog "summarize: Tablog entry\n$tablogstr" -1
	echo >&5 -e "$tablogstr"
}
function on_err () {
	get_runtime
	somilog "RUNTIME ERROR ----------------------------------- RUNTIME ERROR "
    somilog "Error: trapped at line $2
	Error: last cmd:$3
	Error: at line:$2
	Error: exited with:$1
	Error: in subshell level:$4"
    term_script "err"
}
function print_conf () {
	local key
	echo -e "\tThe current script settings are:"
	for key in "${!settings[@]}"; do
		echo -e  "\t$key:${settings[$key]}"
	done
}
function somilog () {
	local pcount=$
	local msg="$1"
	local vm=${settings["vm"]}
	local fulllog=${settings["fulllog"]}
	local sev=$2
	local logline
	if [[ $pcount -gt 1 ]] ; then
		if [[ $vm -ge ${sev#-} ]] ; then
			logline="$(date +%T.%3N)_$script_name:($sev)($((curtask+1))) $1::"
		fi
	else
		logline="$(date +%T.%3N)_$script_name:(-) $1::"
	fi
	if [[ $logline != "" ]] ; then
		if [[ $sev -lt 0 ]] ; then
			echo >&3 -e "$logline"
		else
			echo -e "$logline" | tee /proc/self/fd/4
		fi
	fi
	if [[ $fulllog -eq 1 ]] && [[ $vm -lt ${sev#-} ]]  ; then
		echo >&3 -e "$(date +%T.%3N)_$script_name:($sev) $1::"
	fi
}
function log_arr () {
	local pcount=$
	local msg="$1"
	local vm=${settings["vm"]}
	local fulllog=${settings["fulllog"]}
	declare -i sev=$2
	local logline
	local -n array=$3
	declare -i i
	declare -i arrcnt
	declare -i maxidx
	somilog "log_arr: started with message $1 and severity $2 and array name $3 and arraylength:$4" -2
	if [[ $pcount -ge 3 ]] ; then
		if [[ $pcount -eq 4 ]] ; then
			arrcnt=$4
		else
			arrcnt=${#array[@]}
		fi
		maxidx=$(( arrcnt - 1 ))
		if [[ $vm -ge ${sev#-} ]] ; then
			somilog "$msg" $sev
			if [[ $sev -lt 0 ]] ; then
				for ((i=0; i<arrcnt; i++)) ; do
					echo >&3 -e -n "\t$i: ${array[$i]}"
					(( i<maxidx )) && echo >&3
				done
				(( arrcnt>0 )) && echo >&3 "::"
			else
				for ((i=0; i<arrcnt; i++)) ; do
					echo -e -n "\t$i: ${array[$i]}" | tee /proc/self/fd/4
					(( i<maxidx )) && echo | tee /proc/self/fd/4
				done
				(( arrcnt>0 )) && echo "::" | tee /proc/self/fd/4
			fi
		fi
		if [[ $fulllog -eq 1 ]] && [[ $vm -lt ${sev#-} ]]  ; then
			somilog "$msg" $sev
			for ((i=0; i<arrcnt; i++)) ; do
				echo >&3 -e -n "\t$i: ${array[$i]}"
				(( i<maxidx )) && echo >&3
			done
			(( arrcnt>0 )) && echo >&3 "::"
		fi
	else
		somilog "log_arr: Parameters missing - Check function call" -2
	fi
}
function prep_log () {
	logfile="${today}_$script_name.log"
	local tablog_fp="${settings["tablog"]}"
	echo "prep_log: tablog:$tablog_fp"
	mkdir -p "${settings["logloc"]}" || return 1
	logfile_fp="${settings["logloc"]}/$logfile"
	if [[ ! -f "$logfile_fp" ]]; then
		touch "$logfile_fp" || return 1
	fi
	exec 3>>"$logfile_fp"
	exec 4>&1
	exec 1>&3 2>&3
	set -e
	trap 'on_err $? $LINENO $BASH_COMMAND $BASH_SUBSHELL' ERR
	[ "${settings["vm"]}" -eq 0 ] &&  settings["vm"]=1
	echo >&3 "-------------------------------------------------------------------------------------------"
	somilog "$stcmd" -1
	somilog "Program Version: $reldate running on $sysnam" -1
	somilog "prep_log: Current logfile is:$logfile_fp" 3
	if [[ ! -f "$tablog_fp" ]]; then
		touch "$tablog_fp" || {
		somilog "prep_log: Creation of tabular logfile $tablog_fp failed" -1
		return 1
		}
		exec 5>>"$tablog_fp"
		echo >&5 -e "begints[ms]\taction\tcm\thm\tam\tsysnam\titem\tsize\tfcnt\thalg\that[s]\tatype\tart[s]\tasize\text[s]\taut[s]\tdelts[ms]"
	else
		exec 5>>"$tablog_fp"
	fi
	return 0
}
function arr_from_string () {
	local str="$1"
	local -n arr=$2
	local sep="$3"
	if IFS=$sep read -ra arr <<< "$str" ; then
		return 0
	else
		return 1
	fi
}
function read_conf () {
	local conffile="${settings["confloc"]}/${settings["conf_bn"]}"
	if [[ -f "$conffile" ]] ; then
		source "$script_loc/ini.class.sh" || {
					logger -s -t "$script_name" -p user.err "Error when sourcing ini.class.sh"
					exit 1;
		}
		ini.set "$conffile"
		ini.setsection somikroarc
		[ "$(ini.value "fulllog")" ] && settings["fulllog"]="$(ini.value "fulllog")"
		[ "$(ini.value "tmpdir")" ] && settings["tmpdir"]="$(ini.value "tmpdir")"
		[ "$(ini.value "ramdir")" ] && settings["ramdir"]="$(ini.value "ramdir")"
		[ "$(ini.value "ramdirSize")" ] && settings["ramdirSize"]="$(ini.value "ramdirSize")"
		[ "$(ini.value "ramonly")" ] && settings["ramonly"]="$(ini.value "ramonly")"
		[ "$(ini.value "exdir")" ] && settings["exdir"]="$(ini.value "exdir")"
		[ "$(ini.value "vm")" ] && settings["vm"]="$(ini.value "vm")"
		[ "$(ini.value "cm")" ] && settings["cm"]="$(ini.value "cm")"
		[ "$(ini.value "hm")" ] && settings["hm"]="$(ini.value "hm")"
		[ "$(ini.value "am")" ] && settings["am"]="$(ini.value "am")"
		[ "$(ini.value "tasklist_width")" ] && settings["tasklist_width"]="$(ini.value "tasklist_width")"
		[ "$(ini.value "tasklist_height")" ] && settings["tasklist_height"]="$(ini.value "tasklist_height")"
		[ "$(ini.value "gui_delay")" ] && settings["gui_delay"]="$(ini.value "gui_delay")"
		[ "$(ini.value "cssfile")" ] && settings["cssfile"]="$(ini.value "cssfile")"
		[ "$(ini.value "tablog")" ] && settings["tablog"]="$(ini.value "tablog")"
		[ "$(ini.value "atype")" ] && settings["atype"]="$(ini.value "atype")"
		settings["zipopt"]="$(ini.value "zipopt")"
		arr_from_string "${settings["zipopt"]}" zipopt ' ' || return 1
		settings["unzipopt"]="$(ini.value "unzipopt")"
		arr_from_string "${settings["unzipopt"]}" unzipopt ' ' || return 1
		settings["hashalgs"]="$(ini.value "hashalgs")"
		arr_from_string "${settings["hashalgs"]}" hashalgs ' ' || return 1
		settings["halg"]="$(ini.value "halg")"
		settings["hashopt"]="$(ini.value "hashopt")"
		arr_from_string "${settings["hashopt"]}" hashopt ' ' || return 1
		settings["auditopt"]="$(ini.value "auditopt")"
		arr_from_string "${settings["auditopt"]}" auditopt ' ' || return 1
	else
		echo "read_conf: no config file $conffile found - using defaults"
	fi
	return 0
}
function print_help () {
   echo >&4 "Usage: $0 [-c] [-a] [-h] [-V] [-L] [-C creationMode] [-A auditingMode] [-H hashfileMode] [-t testmode] [-v loglevel] directory|zip-archive"
   echo >&4 "   $script_name creates or audits an archive of a directory tree with integrity verification"
   echo >&4 "  -c: create a hash value file and/or zip-archive from given directory"
   echo >&4 "  -C: creationMode 1=archive only, 2=hashfile and archive, 3=hashfile and archive verified, 4 hashfile only"
   echo >&4 "  -a: audit the integrity of the given directory or zip-archive"
   echo >&4 "  -A: auditingMode 1=archive by crc, 2=archive by hashfile, 3=directory by hashfile"
   echo >&4 "  -v: loglevel of messages "
   echo >&4 "  -V: list version of the program"
   echo >&4 "  -L: full logging in logfile"
   echo >&4 "  -H: hashfileMode 1=out-of-dir , 2=in dir, negative nr produces a hidden hash values file"
   echo >&4 "  -s: hash algorithms out of ${settings["hashalgs"]}"
   echo >&4 "  -t: running in test mode - testmode is a number"
   echo >&4 "  -h: Display this help message"
   echo >&4 "	Example : $script_name -c -C 3 mydir_to_archive"
   echo >&4 "	Example : $script_name -a -A 2 mydir_to_archive.zip"
   echo >&4 "$script_name by $author, Version $version, $reldate"
}
function get_cliargs () {
	while getopts "t:v:H:A:C:s:achVL" option; do
		case "$option" in
			t) tst=$OPTARG ;;
			v) settings["vm"]=$OPTARG ;;
			H) settings["hm"]=$OPTARG ;;
			A) settings["am"]=$OPTARG ;;
			C) settings["cm"]=$OPTARG ;;
			s) settings["halg"]=$OPTARG ;;
			c) create=1
				action="Hash &| Archive";;
			a) audit=1
				action="Audit";;
			L) settings["fulllog"]=1 ;;
			h)
			print_help
				exit 0 ;;
			V) echo >&4 "$version" ;;
			\?)
				echo >&4"Error: Invalid option"
				somilog "get_cliargs: Invalid option with $stcmd :$OPTARG" 1
		esac
	done
	shift "$((OPTIND-1))"
	arglist=("$@")
	somilog "Number of remaining arguments:$#" 3
	somilog "Remaining arguments are: ${arglist[*]}" 3
}
function rm_ramfs () {
	if sudo umount "$ramfs_fp" ; then
		somilog "rm_ramfs: tmpfs at $ramfs_fp unmounted" -4
		return 0
	else
		somilog "rm_ramfs: unmount of tmpfs at $ramfs_fp failed" -4
		return 1
	fi
}
function set_itmrefs () {
	local itm="$1"
	cwd="$(pwd)"
	somilog "set_itmrefs: Current working dir cwd:$cwd" 4
	itm_fp="$(realpath "$itm")"
	somilog "set_itmrefs: Full path itm_fp:$itm_fp" 4
	if [[ "$itm" == "." ]]; then
		itm_bn="$(basename "$cwd")"
	else
		if [[ -L "$itm" ]]; then
			itm_bn="$(basename "$itm_fp")"
		fi
		itm_bn="$(basename "$itm")"
	fi
	somilog "set_itmrefs: Item name itm_bn:$itm_bn" 4
	itm_rp="$(realpath --relative-to="$cwd" "$itm_fp")"
	somilog "set_itmrefs: Item pathname relative to current dir itm_rp:$itm_rp" 4
	if [[ "$itm" == "." ]]; then
		pdir_fp="$(dirname "$cwd")"
	else
		pdir_fp="$(realpath "$(dirname "$itm")")"
	fi
	somilog "set_itmrefs: Items's parent directory full path pdir_fp:$pdir_fp" 4
	if [[ "$itm" == "." ]]; then
		pdir_rp=".."
	else
		pdir_rp="$(realpath --relative-to="$cwd" "$pdir_fp")"
	fi
	somilog "set_itmrefs: Item's parent directory pathname relative to current dir pdir_rp:$pdir_rp" 4
}
function docd () {
	local target="$1"
	target="${target%/}"
	somilog "docd: Current target dir is:$target" -5
	cd "$target"
	cwd="$(pwd)"
	somilog "docd: Current Working dir is now:$cwd" -5
	if [[ "$cwd" == "$target" ]] ; then
		return 0
	else
		return 1
	fi
}
function form_nums_in_string () {
	local input
	input=$(cat -)
    local output
    local word
    LC_NUMERIC=de_DE.UTF-8
    for word in $input; do
        if [[ $word =~ ^([0-9]+)([^0-9]*)$ ]]; then
            formatted="$(printf "%'d" "${BASH_REMATCH[1]}")${BASH_REMATCH[2]}"
		elif [[ $word =~ ^([^0-9]+)([0-9]+)(,*)$ ]]; then
            formatted="${BASH_REMATCH[1]}$(printf "%'d" "${BASH_REMATCH[2]}")${BASH_REMATCH[3]}"
        elif [[ $word =~ ^[0-9]+\,[0-9]+,*$ ]]; then
            formatted=$(printf "%'.2f" "$word")
        else
            formatted="$word"
        fi
        output+="$formatted "
    done
    echo -e "${output% }"
}
function check_arg () {
	local arg="$1"
	somilog "check_arg: File Info: $(file "$arg")" 5
	if [[ -d "$arg" ]] ; then
			itmtype="dir"
			return 0
		elif file "$arg" | grep -q "Zip archive data"  ; then
			itmtype="zip"
			return 0
		else
			somilog "check_arg: $arg is an invalid argument"
			itmtype="invalid"
			return 1
		fi
}
function check_args () {
	local -n args=$1
	local arrcnt=${#args[@]}
	local arg
	log_arr "check_args: Arguments list with $arrcnt args" "3" arglist
	if [[ $arrcnt -eq 0 ]]; then
		somilog "check_args: No arguments specified"
		return 1
	else
		for arg in "${args[@]}"; do
			check_arg "$arg"  || ((nvc+=1))
			somilog "check_args: Found argument $arg of type:$itmtype" 3
		done
		if [[ "$nvc" -ne 0 ]]; then
		  somilog "check_args: $nvc arguments are not valid - chek arguments list" 1
		  return 1
		fi
	fi
	local halgo="${settings["halg"]}"
	local halgos="${settings["hashalgs"]}"
	[[ "$halgos" == *"$halgo"* ]]  || {
		somilog "check_args: $halgo is not a valid hash algorithm, only $halgos allowed." 1
		return 1
	}
	return 0
}
function make_itm_pn () {
	local itm="$1"
	somilog "make_itm_pn: argument info:$itm" 4
	local pattern=".+(share=.+)"
	if [[ "$itm" =~ $pattern ]] ; then
		itm_pn="${BASH_REMATCH[1]}"
	else
		itm_pn="$itm"
	fi
	somilog "make_itm_pn: itm_pn is:$itm_pn" 4
}
function gui_term () {
	somilog "gui_term: $1" -1
	yad --title="Custom Styled Dialog" \
		--form \
		--field="Name" \
		--field="Age" \
		--button=gtk-ok \
		--button=gtk-cancel
}
function gui_err () {
	somilog "gui_err: $1" -1
	yad --title="ERROR" --center \
		--image="/usr/lib/somikroarc/icons/Error.png" \
		--text="$1" \
		--borders=50 \
		--button="Confirm:0" \
		--width=400
}
function breakpt () {
	somilog "breakpt: $1" -1
	yad --title="Breakpoint" --center \
		--text="$1" \
		--button="Continue:0" \
		--button="Terminate:1" \
		--width=400  || term_script "breakpt"
}
function upd_tasklist () {
		somilog "upd_tasklist: Updateing times for task Nr. $((curtask+1))" 4
		hashtlist[curtask]=$hashtime
		arctlist[curtask]=$arctime
		extlist[curtask]=$extime
		audtlist[curtask]=$audtime
		donelist[curtask]=$donestat
		begtlist[curtask]=$taskstart
}
function calc_itmidx () {
	local searchitm="$1"
	local -i foundidx=''
	local taskcnt=${#itemlist[@]}
	declare -i i
	somilog "calc_itmidx: Searching index of itm $searchitm in itemlist of length $taskcnt" -4
	for (( i=0; i<taskcnt; i++ )); do
		if [[ "${itemlist[i]}" == "$searchitm" ]] ;then
			foundidx=i
		fi
	done
	if [[ -z "${foundidx}" ]] ; then
		somilog "calc_itmidx: Significant internal error: deleted item $searchitm was not found in itemlist" -1
		return 1
	else
		echo $foundidx
		return 0
	fi
}
function prep4task () {
		hashtime=0
		arctime=0
		extime=0
		audtime=0
		donestat="false"
}
function deldirs () {
	local seldirs="$1"
	local delcnt
	local rdline
	declare -i delidx
	local yadstat
	declare -i index
	local -i foundidx
	somilog "deldirs: Processing $delcnt directory delete operations" -3
	index=0
	while IFS=$'\n' read -r rdline ; do
		arr_from_string "$rdline" tmparr '|'
		[[ "${tmparr[9]}" == "TRUE" ]] && dellist+=("${tmparr[0]}")
		((index+=1))
	done < <(echo "$seldirs")
	delcnt=${#dellist[@]}
	log_arr "deldirs: $delcnt Directories to delete:" -3 dellist
	for (( delidx=0; delidx<${#dellist[@]}; delidx++ )); do
		yad --title="somikroarc: Confirm directory deletion" --center \
			--text="Deleting directory ${dellist[delidx]}" \
			--image="/usr/lib/somikroarc/icons/Delete.png"  \
			--css="${settings["cssfile"]}" \
			--button="Delete:1" \
			--button="Cancel:0" \
			--width=400 && yadstat=$? || yadstat=$?
		if [ $yadstat -eq 1 ] ; then
			somilog "deldirs: Deleting dir ${dellist[delidx]} (still dummy) " -3
			if stat "${dellist[delidx]}" >& /dev/null ; then
				somilog "deldirs: Deletion of dir ${dellist[delidx]} was successfull" -1
				foundidx=$(calc_itmidx "${dellist[delidx]}") || {
					return 1
				}
				deltlist[foundidx]=$(date +%s%N)
			else
				somilog "deldirs: Error when deleting dir ${dellist[delidx]}" -1
				return 1
			fi
		fi
	done
	log_arr "deldirs: List of successful deletions deltlist[@]" -1 deltlist ${#itemlist[@]}
	return 0
}
function disp_tasklist () {
	local dmode="$1"
	local selstr
	declare -i i
	local yadstat
	local gaptime
	local gui_delay
	gui_delay=${settings["gui_delay"]}
	gaptime=$(( ( $(date +%s%N) - gui_tl_updTS ) / 1000000 ))
	if (( gaptime <= gui_delay )) &&  [[ $dmode != "b" ]]; then
		somilog "disp_tasklist: Called too quickly after ${gaptime}ms" -1
		return 0
	fi
	yaddata=()
	local taskcnt=${#itemlist[@]}
	somilog "disp_tasklist: Running after action $2 in dmode:$dmode" -3
	if [[ -n "${YAD_TASKLIST_PID+x}" ]]; then
		somilog "disp_tasklist: There is old dialog with PID $YAD_TASKLIST_PID" -1
		if (ps -p $YAD_TASKLIST_PID &>/dev/null); then
			somilog "disp_tasklist: Old tasklist dialog with PID $YAD_TASKLIST_PID is still active" -1
			kill $YAD_TASKLIST_PID &>/dev/null || {
				somilog "disp_tasklist: Failed to kill old tasklist dialog with PID $YAD_TASKLIST_PID" -1
				return 1
			}
			ps -p $YAD_TASKLIST_PID &>/dev/null && wait $YAD_TASKLIST_PID
			somilog "disp_tasklist: Continuing after process PID $YAD_TASKLIST_PID terminated" -1
		fi
	else
		somilog "disp_tasklist: No old tasklist dialog is active" -3
	fi
	somilog "disp_tasklist: Numer of tasks:$taskcnt" -3
	somilog "disp_tasklist: Creating new tasklist" -3
	for (( i=0; i<taskcnt; i++ )); do
		yaddata+=("${itemlist[i]}")
		yaddata+=("${itmsizelist[i]}")
		yaddata+=("${itmcntlist[i]}")
		yaddata+=("${hashtlist[$i]}")
		yaddata+=("${arctlist[$i]}")
		yaddata+=("${extlist[$i]}")
		yaddata+=("${audtlist[$i]}")
		yaddata+=("${donelist[$i]}")
		yaddata+=("${arcsizelist[$i]}")
		yaddata+=("false")
	done
	log_arr "disp_tasklist: data" -3 yaddata
	if [[ $dmode == "b" ]] ; then
		selstr=$(yad --list --print-all --title="somikroarc: Tasklist"\
			--button="OK:0" \
		    --width="${settings["tasklist_width"]}" \
		    --height="${settings["tasklist_height"]}" \
			--column=path:text  \
			--column=size:text \
			--column=fcnt:text \
			--column=hat:text \
			--column=art:text \
			--column=ext:text \
			--column=aut:text \
			--column=status:chk \
			--column=asize:text \
			--column=delete:chk \
			"${yaddata[@]}" ) 2> /dev/null  && yadstat=$? || yadstat=$?
		gui_tl_updTS=$(date +%s%N)
		if [[ $yadstat -eq 0 ]]; then
			somilog "disp_tasklist: Selection:\n$selstr" 1
			if [[ $selstr == '' ]] ; then
				somilog "disp_tasklist: No delete selection made in tasklist and terminated with OK" -1
				return 0
			else
				somilog "disp_tasklist: Delete selection made - calling delete function" -1
				deldirs "$selstr" "$(wc -l <<< "$selstr")" || return 1
			fi
		else
			somilog "disp_tasklist: Btn Cancel pressed or dialog window closed" -1
			return 1
		fi
	else
		yad --list --no-buttons --no-selection --title="somikroarc: Tasklist" \
		  --width="${settings["tasklist_width"]}" \
		  --height="${settings["tasklist_height"]}" \
		  --column=path:text  \
		  --column=size:text \
		  --column=fcnt:text \
		  --column=hat:text \
		  --column=art:text \
		  --column=ext:text \
		  --column=aut:text \
		  --column=status:chk \
		  --column=asize:text \
		  --column=delete:chk \
		  "${yaddata[@]}" &>/dev/null &
		YAD_TASKLIST_PID=$!
		gui_tl_updTS=$(date +%s%N)
		somilog "disp_tasklist: New dynamic tasklist dialog created  with PID:$YAD_TASKLIST_PID" -1
	fi
}
function initgui () {
	local optStr
	local cm=${settings["cm"]}
	if [[ $cm -gt 2 ]]; then
		optStr+="Hashing"
	fi
	if [[ $cm -lt 4 ]]; then
		optStr+=" Archiving"
	fi
	if [[ $cm -eq 3 ]]; then
		optStr+=" Verifying"
	fi
	somilog "initgui: cm=$cm, optstr=$optStr" -1
	yad --title="somikroArc" --text="somikroArc V$version processing info" --no-buttons\
	  --image="/usr/lib/somikroarc/icons/somikroarc.png" \
	  --form --date-format="%-d %B %Y" --separator="," --item-separator="," \
	  --css="${settings["cssfile"]}" \
	  --width=550 --height=550 \
	  --field="RunMode":RO "$action" \
	  --field="Options":RO "$optStr" \
	  --field="Args Cnt":RO ${#arglist[@]} &
		YAD_MAINWIN_PID=$!
}
function calc_sizelist () {
	declare -i  index
	local dirsize
	local dir
	index=0
	somilog "calc_sizelist: Calculating the sizes of ${#arglist[@]} dirs in arglist" 4
	for dir in "${arglist[@]}"; do
		IFS=$'\t' read -r dirsize _ < <(du "$dir" -sh)
		somilog "calc_sizelist: dirsize:$dirsize" -5
		sizelist[index]="$dirsize"
		(( index+=1 ))
	done
	log_arr "calc_sizelist: sizelist of the item-arguments" -3 sizelist
}
function calc_cntlist () {
	declare -i  index
	local dir
	index=0
	somilog "calc_cntlist: Calculating the number of files in ${#arglist[@]} dirs in arglist" -3
	for dir in "${arglist[@]}"; do
		itmcntlist[index]=$(find "$dir" -type f | wc -l)
		somilog "calc_cntlist: Number of files in $dir: ${itmcntlist[index]}" -1
		(( index+=1 ))
	done
	log_arr "calc_cntlist: Filecounts for items in itmcntlist:" -3 itmcntlist
}
function args2tasks () {
	local selargs="$1"
	local rdline
	declare -i index
	index=0
	while IFS=$'\n' read -r rdline ; do
		somilog "args2tasks: processing user selection nr:$index" -5
		somilog "args2tasks: rdline:$rdline" -3
		arr_from_string "$rdline" tmparr '|'
		log_arr "arg2tasks: user selection line from tmparr" -1 tmparr
		itemlist[index]="${tmparr[3]}"
		itmsizelist[index]="${tmparr[1]}"
		itmcntlist[index]="${tmparr[2]}"
		hashtlist[index]=$hashtime
		arctlist[index]=$arctime
		extlist[index]=$extime
		audtlist[index]=$audtime
		donelist[index]="false"
		arcsizelist[index]=0
		((index+=1))
	done < <(echo "$selargs")
	disp_tasklist "d" "args2tasks" || return 1
	return 0
}
function disp_arglist () {
	somilog "disp_arglist: Starting YAD display of arglist" 1
	local yaddata=()
	local yadstat
	local selstr
	declare -i i
	for ((i=0; i<${#arglist[@]}; i++))
	do
		yaddata+=("false" "${sizelist[$i]}" "${itmcntlist[$i]}" "${arglist[$i]}")
	done
	log_arr "disp_arglist: Data for arglist display yaddata:" -1 yaddata
	selstr=$(yad --list --checklist  --title="somikroarc: Select directory to $action"\
	  --width=600 --height=401 \
	  --column=Do:Tick \
	  --column=size:text \
	  --column=fcnt:text \
	  --column=item:text \
	  --separator="|" \
	  --button="Cancel":1 \
	  --button="Select":0 \
	  "${yaddata[@]}") && yadstat=$? || yadstat=$?
	somilog "disp_arglist: Status code of yad:$yadstat" -1
	if [[ $yadstat -eq 0 ]]; then
		somilog "disp_arglist: Selection:\n$selstr" 1
		if [[ $selstr == '' ]] ; then
			somilog "disp_arglist: No selection made and terminated with OK" -1
			return 1
		else
			args2tasks "$selstr"
		fi
	else
		somilog "disp_arglist: Btn Cancel pressed or dialog window closed" -1
		return 1
	fi
	return 0
}
function ex_arc () {
	local exdir=${settings["exdir"]}
	if [ -n "$(ls -A "$tmpdir/$exdir")" ] ; then
		somilog "ex_arc: Extraction directory $tmpdir/$exdir is not empty. It has to be cleared." -1
		rm -rf "${tmpdir:?}/${exdir:?}"
		mkdir "${tmpdir:?}/${exdir:?}" || {
			somilog "ex_arc: Clearing extraction directory ${tmpdir:?}/${exdir:?}} failed " -1
			term_script "err"
		}
	fi
	somilog "ex_arc: ExCMD:unzip ${unzipopt[*]} $itm_bn -d $tmpdir/$exdir" -1
	exstart=$(date +%s%N)
	if 	[ ! -d "$tmpdir/$exdir" ] ; then
		mkdir "$tmpdir/$exdir" || {
			somilog "ex_arc: Creation of exdir $exdir at /dev/shm failed" -2
			return 1
			}
		chmod 777 "$tmpdir/$exdir" || {
			somilog "ex_arc: Failed to set permissions for exdir $tmpdir/$exdir" -2
			return 1
			}
	fi
	if unzip "${unzipopt[@]}" "$itm_bn" -d "$tmpdir/$exdir" ; then
		calc_deltaT extime exstart
		upd_tasklist
		disp_tasklist "d" "extraction"
		somilog "ex_arc: Archive $itm_bn extracted successfully to $tmpdir/$exdir" 1
	else
		somilog "ex_arc: Extraction of archive $itm_bn failed" 1
		return 1
	fi
	local arcert_tn="${itm_bn%.*}"
	arcert_bn="$(ls "$tmpdir/$exdir" )"
	somilog "ex_arc: Extraction expected root:$arcert_tn Extraced root:$arcert_bn" 2
	if [[ "$arcert_tn" != "$arcert_bn" ]] ; then
		somilog "ex_arc: Extracted archive root name mismatch"
		return 1
	fi
	return 0
}
function check_tmp () {
	declare -i reqblk=$1
	declare -i blockCnt=0
	somilog "check_tmp: Current tmpdir tested is:$tmpdir" 4
	blockCnt=$(df "$tmpdir" | awk 'NR==2 {print $4}')
	local freespace
	freespace=$(echo "scale=2; $blockCnt / 1024" | bc -l)
	freespace="${freespace//./,}"
	local fspmsg
	fspmsg=$(echo "$freespace" | form_nums_in_string)
	somilog "check_tmp: Temp dir $tmpdir, blockCnt:$blockCnt, reqblk:$reqblk, freespace:$freespace, fspmsg:$fspmsg  " 4
	if [ $blockCnt -ge $reqblk ] ; then
		somilog "check_tmp: Temp dir $tmpdir has $fspmsg [MiB] which is enough" 4
		return 0
	else
		somilog "check_tmp: Temp dir $tmpdir has $fspmsg [MiB] which is not enough" 4
		return 1
	fi
}
function mk_ramdir () {
	local ramfs_fp=${settings["ramdir"]}
	declare -i req_size=${settings["ramdirSize"]}
	if 	[ ! -d "ramfs_fp" ] ; then
		somilog "mk_ramdir: Creating mountpoint for ramdir $ramfs_fp" -2
		mkdir "$ramfs_fp" || {
			somilog "mk_ramdir: Creating mountpoint for ramdir $ramfs_fp failed" -2
			return 1
			}
	fi
	chmod 777 "$ramfs_fp" || {
		somilog "mk_ramdir: Failed to set permissions for mountpoint of ramdir $ramfs_fp " -2
		return 1
		}
	somilog "mk_ramdir: Creating a tmpfs of $req_size at $ramfs_fp" 3
	sudo mount -t tmpfs -o size=$req_size tmpfs "$ramfs_fp" && ramdir="$ramfs_fp" || return 1
	return 0
}
function get_tmpdir () {
	declare -i reqtmpblk=$1
	local exdir=${settings["exdir"]}
	local archMB
	archMB=$(echo "scale=2; $reqtmpblk / 1024" | bc -l)
	archMB="${archMB//./,}"
	declare -i ramonly=${settings["ramonly"]}
	local reqramdir=${settings["ramdir"]}
	somilog "get_tmpdir: Looking if /ev/shm has at least $archMB [MiB] freespace" 5
	if [ -d /dev/shm ] ; then
		tmpdir="/dev/shm"
		check_tmp $reqtmpblk
		return 0
	fi
	somilog "get_tmpdir: Next try is to use ramdir from configuration:$reqramdir" 5
	if [ -d "$reqramdir" ] ; then
		if df -T "$reqramdir" | grep -q tmpfs ; then
			somilog "get_tmpdir: A ramdir is already existing at $reqramdir" -2
			ramdir="$reqramdir"
		else
			[ "$(ls -A "$reqramdir")" ] && {
				somilog "get_tmpdir: $reqramdir is not empty - no ramdir created there" -2
				return 1
				}
			mk_ramdir || return 1
		fi
	else
		mk_ramdir || return 1
	fi
	tmpdir="$ramdir"
	check_tmp $reqtmpblk && return 0
	if [ ! $ramonly ] ; then
		somilog "get_tmpdir: No sufficient ramdir found. Searching a tmpdir on disk with > $archMB [MiB] freespace" 5
		tmpdir=${settings["tmpdir"]}
		check_tmp $reqtmpblk && return 0
		tmpdir="/tmp"
		check_tmp $reqtmpblk && return 0
	fi
	return 1
}
function find_hvf () {
	local itm_lbn="$1"
	local rel_sp="$2"
	local algo
	somilog "find_hvf: Finding hash value file for item:$itm_lbn" -1
	log_arr "find_hvf: Available hash algorithms are:" 4 hashalgs
	for algo in "${hashalgs[@]}" ; do
		somilog "find_hvf: Testing for hash value file of:$algo in $rel_sp" 4
		[[ -f "$rel_sp/.$itm_lbn.$algo" ]] && { hvf_rp="$rel_sp/.$itm_lbn.$algo"; break; }
		[[ -f "$rel_sp/$itm_lbn.$algo" ]] && { hvf_rp="$rel_sp/$itm_lbn.$algo"; break; }
	done
	[ "$hvf_rp" ] && {
		hvf_bn="$(basename "$hvf_rp")"
		hvf_MD=$(stat -c '%Y' "$hvf_rp")
		return 0 ; } || return 1
}
function run_hd_audit () {
	local hvf_rpl="$1"
	local dir_rpl="$2"
	local hvf_MDh
	local audres
	local status
	hvf_MDh="$(date -d "@$hvf_MD" "+%Y-%m-%d %H:%M:%S")"
	somilog "run_hd_audit: Using hash values from $hvf_rpl dated:$hvf_MDh" 1
	somilog "run_hd_audit: Running hashdeep ${auditopt[*]} $hvf_rpl $dir_rpl" -3
	audstart=$(date +%s%N)
	audres="$(hashdeep "${auditopt[@]}" -k "$hvf_rpl" "$dir_rpl")"
	status=$?
	calc_deltaT audtime audstart
	somilog "run_hd_audit: hasdeep output\n$audres" -2
	case $status in
		0)
			return 0
			;;
		2)
			somilog "run_hd_audit: hashdeep (stat 1) unused hashes - Files missing in archive $itm_bn " 1
			yad --title="Audit Result" --text="Found unused hashes - Files missing in archive $itm_bn" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
			;;
		1)
			somilog "run_hd_audit: hashdeep (stat 2) new files in archive $itm_bn without hash in hvf" 1
			yad --title="Audit Result" --text="Found new files in archive $itm_bn without hash in hvf" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 0
			;;
		64)
			somilog "run_hd_audit: hashdeep (stat 3) calling option error " -2
			yad --title="Audit Result" --text="Hashdeep calling option error" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
			;;
		128)
			somilog "run_hd_audit: hashdeep (stat 4) internal error " -1
			yad --title="Audit Result" --text="Hashdeep internal error" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
			;;
		*)
			somilog "run_hd_audit: hashdeep unknown error " -1
			yad --title="Audit Result" --text="Hashdeep unknown error" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
			;;
	esac
}
function doaudit() {
	local itm="$1"
	somilog "Start to audit item:$itm" -1
	check_arg "$itm"
	somilog "doaudit: Item type is:$itmtype" 3
	set_itmrefs "$itm"
	make_itm_pn "$itm"
	somilog "doaudit: Begin of audit for itm_pn:$itm_pn" 3
	docd "$pdir_fp" || {
		somilog "doaudit: Cd failed into item's parent dir:$pdir_fp"
		return 1
	}
	if [[ $itmtype == "zip" ]] ; then
		somilog "doaudit: Auditing zip $itm:" 3
		declare -i archblocks
		archblocks=$(du -k "$itm" | awk 'NR==1 {print $1}')
		local archMB
		archMB=$(echo "scale=2; $archblocks / 1024" | bc -l)
		archMB="${archMB//./,}"
		somilog "doaudit: Archive $itm has a size of $archblocks blocks / $archMB MB" 5
		local reqtmpblocks=$((archblocks * 10))
		get_tmpdir $reqtmpblocks || {
		somilog "doaudit: No sufficient tmp space to extract the archive for auditing found"
		return 1
		}
		if ! ex_arc ; then
			somilog "doaudit: Archive extraction failed. Terminating Auditing" 1
			return 1
		fi
		local exdir=${settings["exdir"]}
		docd "$tmpdir/$exdir" || {
			somilog "doaudit: Cd failed into archive extraction dir:$tmpdir/$exdir"
			return 1
			}
		if find_hvf "$arcert_bn" "$arcert_bn" ; then
			somilog "doaudit: Found hash value file $hvf_bn at root of extracted zip archive:" 2
			if mv -f "$hvf_rp" "$tmpdir/$exdir" ; then
				somilog "doaudit: Moved hvf $hvf_bn out of extr. archive root into $tmpdir/$exdir" -5
			else
				somilog "doaudit: Move of hvf $hvf_rp to $tmpdir/$exdir failed. Terminating Auditing"
				return 1
			fi
		else
			somilog "doaudit: Found no hash value file inside archive root. Terminating Auditing" 1
			return 1
		fi
		somilog "doaudit: Auditing extracted archive $itm_bn using hash file $hvf_rp" 3
		if run_hd_audit "$hvf_bn" "$arcert_bn"	; then
			somilog "doaudit: Archive $itm_bn successfully audited" 1
			yad --title="Audit Result" --text="Archive $itm_bn successfully audited" --button="OK":0 --width=400 --height=100 &>/dev/null &
		else
			somilog "doaudit: Auditing archive $itm_bn failed. Terminating Auditing"
			yad --title="Audit Result" --text="Auditing archive $itm_bn failed" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
		fi
		[ -d "$tmpdir/$exdir/$arcert_bn" ] && {
			somilog "doaudit: Removing remains of $tmpdir/$exdir/$arcert_bn after auditing" -1
		rm -rf "${tmpdir:?}/${exdir:?}/${arcert_bn:?}"
		}
		[ -f "$tmpdir/$exdir/$hvf_bn" ] && rm "$tmpdir/$exdir/$hvf_bn"
	fi
	if [[ $itmtype == "dir" ]] ; then
		somilog "doaudit: Auditing dir :" 3
		if find_hvf "$itm_bn" "." ; then
			somilog "doaudit: Found hash value File $hvf_rp besides dir:" 2
		elif find_hvf "$itm_bn" "$itm_rp" ; then
			somilog "doaudit: Found hash value File $hvf_rp inside dir:" 2
		else
			somilog "doaudit: Found no hash value File. Terminating Auditing" 1
			yad --title="Audit Result" --text="Found no hash value File for directory $itm_bn" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
		fi
		somilog "doaudit: Auditing directory $itm_bn using hash file $hvf_rp" 2
		somilog "doaudit: Running hashdeep ${auditopt[*]} $hvf_rp $itm_bn" -3
		hashdeep "${auditopt[@]}"  -k "$hvf_rp" "$itm_bn"
		if run_hd_audit "$hvf_rp" "$itm_bn" ; then
			somilog "doaudit: Directory $itm_bn successfully audited" 1
			yad --title="Audit Result" --text="Directory $itm_bn successfully audited" --button="OK":0 --width=400 --height=100 &>/dev/null &
		else
			somilog "doaudit: Auditing directory $itm_bn failed. Terminating Auditing" 1
			yad --title="Audit Result" --text="Auditing directory $itm_bn failed" --button="OK":0 --width=400 --height=100 &>/dev/null &
			return 1
		fi
	fi
	return 0
}
function del_hvf () {
	declare -a tmparr
	local hashalgo
	local file
	local delcnt
	declare -i errcnt
	for hashalgo in ${settings["hashalgs"]} ; do
		somilog "del_hvf: Removing an old $itm_bn.$hashalgo or .$itm_bn.$hashalgo if found" -5
		readarray -d '' tmparr < <(find . "./$itm_bn" -maxdepth 1 -type f \( -name "$itm_bn.$hashalgo" -o -name ".$itm_bn.$hashalgo" \) -print0)
		files+=( "${tmparr[@]}" )
	done
	somilog "del_hvf: Found ${#files[@]} old hvf files" -5
	log_arr "del_hvf: Found these old hvf files:" -3 files
	errcnt=0
	for file in "${files[@]}"; do
			rm -f "$file"  || { ((errcnt+=1)) ; somilog "del_hvf: $file could not be deleted" ;}
	done
	delcnt=$(( ${#files[@]} - errcnt ))
	somilog "del_hvf: $delcnt out of ${#files[@]} old hvf could be deleted" -3
	(( errcnt )) && return 1 || return 0
}
function makehvf () {
	local hvf_bnf="$1"
	declare -i hm=${settings["hm"]}
	hvf_fp="$pdir_fp/$hvf_bnf"
	somilog "makehvf: Hash Value file to create hvf_fp:$hvf_fp" 3
	if docd "$pdir_fp" ; then
		del_hvf || return 1
		somilog "makehvf: Started hash value file creation for dir:$itm_pn" 1
		somilog "makehvf: Running hashdeep ${hashopt[*]} $itm_bn  >$hvf_bnf" -3
		hashstart=$(date +%s%N)
		if hashdeep "${hashopt[@]}" "$itm_bn"  >"$hvf_bnf" ; then
			calc_deltaT hashtime hashstart
			upd_tasklist
			disp_tasklist "d" "hashing"
			somilog "makehvf: Hash value file $hvf_fp successfully created" 3
			if [ ${hm#-} -eq 2 ] ; then
				if mv "$hvf_fp" "$itm_fp" ; then
					hvf_fp="$itm_fp/$hvf_bnf"
					somilog "makehvf: Hash Value File successfully moved to $hvf_fp" 3
				else
					somilog "makehvf: Moveing $hvf_bnf into $itm_fp failed"
					return 1
				fi
			fi
		else
			somilog "makehvf: Hash value file $hvf_fp creation failed"
			return 1
		fi
	else
		somilog "makehvf: CD into $pdir_fp for hash file creation failed"
		return 1
	fi
	return 0
}
function docreate ()  {
	local mydir="$1"
	local mydirinfo
	local arcsize
	mydirinfo="$(file "$mydir")"
	declare -i cm=${settings["cm"]}
	declare -i hm=${settings["hm"]}
	local halgo=${settings["halg"]}
	somilog "docreate: Dir file info:$mydirinfo" 3
	set_itmrefs "$mydir"
	make_itm_pn "$mydir"
	if [ $cm -gt 2 ] ; then
		if [ $hm -gt 0 ]; then
			hvf_bn="$itm_bn.$halgo"
		else
			hvf_bn=".$itm_bn.$halgo"
		fi
		makehvf "$hvf_bn"
	else
		docd "$pdir_fp" || {
			somilog "docreate: CD into $pdir_fp for hash file creation failed"
			return 1
			}
	fi
	if [ $cm -lt 4 ] ; then
		af_bn="$itm_bn.zip"
		rm -f "$itm_bn.zip"
		hvf_bn="$itm_bn.$halgo"
		somilog "docreate: Started to create archive:$af_bn" 3
		somilog "docreate: Compression options:${zipopt[*]}" -1
		somilog "docreate: hm:$hm  |hm|:${hm#-}" 4
		if [ ${hm#-} -eq 1 ] ; then
			arcstart=$(date +%s%N)
			if zip "${zipopt[@]}" "$af_bn" "$hvf_bn" "$itm_bn" | grep -v "^  adding:" | form_nums_in_string ; then
				calc_deltaT arctime arcstart
				somilog "docreate: Dir+hvf successfully archived into $af_bn" 3
			else
				somilog "docreate: Creation of archive $af_bn failed"
				return 1
			fi
		else
			somilog "docreate: Adding Dir only:$itm_bn to archive:$af_bn" 4
			arcstart=$(date +%s%N)
			if zip "${zipopt[@]}" "$af_bn" "$itm_bn" | grep -v "^  adding:" | form_nums_in_string ; then
				calc_deltaT arctime arcstart
				somilog "docreate: Dir successfully archived into $af_bn" 3
			else
				somilog "docreate: Creation of archive $af_bn failed"
				return 1
			fi
		fi
		arcsize=$(ls -sh "$af_bn")
		arcsizelist[curtask]="${arcsize%% *}"
		somilog "docreate: Archive $af_bn has a size of:${arcsizelist[$curtask]}" 1
		upd_tasklist
		disp_tasklist "d" "archiving"
	fi
	if [ $cm -eq 3 ] ; then
		if doaudit "$af_bn" ; then
			donestat="true"
			somilog "Setting done status for task:$donestat"
			(( curtask <  ${#itemlist[@]} -1 )) && {
				upd_tasklist
				disp_tasklist "d" "task completed"
			}
		else
			return 1
		fi
	fi
	somilog "Dir $itm_pn successfully hashed and archived" 1
	return 0
}
function checkreq () {
	local cmd
	for cmd in "${reqcmds[@]}" ; do
		if ! command -v "$cmd" &> /dev/null ; then
			somilog "checkreq: Required command not found:$cmd" 1
			return 1
		fi
	done
	return 0
}
 function mytest () {
	 somilog "test: This is the value of test:$tst"
 }
{
	export LC_NUMERIC=de_DE.UTF-8
	read_conf || errmark=1
	prep_log || errmark=1
	(( errmark )) && term_script "base"
	checkreq || term_script "reqcmds"
	get_cliargs "$@"
	print_conf
	if [[ "$tst" -eq 1 ]]; then
		action="Testing"
		somilog "Starting in test mode" 2
		gui_term "Testing"
		term_script "end"
		breakpt "After initgui"
	fi
	check_args arglist || term_script "err"
	initgui
	if [[ "$audit" -eq 1 ]]; then
		action="audit"
		somilog "Starting in audit mode" 2
		for item in "${arglist[@]}"; do
			taskstart=$(date +%s%N)
			if doaudit "$item" ; then term_script "end"; else term_script "err"; fi
		done
	fi
	if [[ "$create" -eq 1 ]]; then
		action="hash &| archive"
		taskstart=$(date +%s%N)
		calc_sizelist
		calc_cntlist
		disp_arglist || term_script "nosel"
		somilog "Processing create tasklist with ${#itemlist[@]} tasks" 1
		for (( tasknr=0; tasknr<${#itemlist[@]}; tasknr++ )); do
			curtask=$tasknr
			prep4task
			somilog "Processing Task Nr.$((tasknr+1)): directory:${itemlist[tasknr]}" 1
			taskstart=$(date +%s%N)
			docreate "${itemlist[tasknr]}" || term_script "err"
		done
	fi
	upd_tasklist
	disp_tasklist "b" "Tasklist completed"
	term_script "end"
}
