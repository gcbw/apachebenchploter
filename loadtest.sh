#!/usr/bin/env bash
set -e

usage(){
	echo "$0 [-d|-r] [-v] [-l logfilename] totalrequests concurrentrequests1 concurrent2 concurrent3 url"
	echo "-d		Graph Y axis as duration"
	echo "-r		Graph Y axis as requests per second"
	echo "-v		debug."
}

# check dependencies
for dependency in "gnuplot" "ab"; do
	command -v $dependency >/dev/null 2>&1 || { echo "Require $dependency command. Not found." >&2; exit 1; }
done

# set values for flags
MODE=""
LOGFILE=""
URLFILE=""

# set list of ordered params, in order
declare -a LISTOFPARAMS=("TOTALREQUESTS" "CONCURRENTREQUESTS1" "CONCURRENTREQUESTS2" "CONCURRENTREQUESTS3" "URL")

# TODO: handle long opt
while (( $# )); do
	# always reset OPTIND before calling getopts, specially if we are calling it multiple times like here.
	OPTIND=1
	while getopts ":vhrdl:-:" opt "$@"; do
	case "${opt}" in
		-) echo "--long options are not suported. Blame getopts."; exit 1;;
		\?) echo "Invalid option: -$OPTARG" >&2; exit 1;;
		:) echo "Option -$OPTARG requires an argument." >&2; exit 1;;
		v|verbose) echo "verbose set"; set -x;;
		h|help) usage; exit 0;;
		d|r) MODE="${OPTARG}"; echo "not implemented. showing both always";;
		l|logfile) LOGFILE="${OPTARG}";;
		f|urlFILE) URLFILE="${OPTARG}";;
	esac
	done
	
	# drop all parameters parsed via getopt flags and parse positional ones
	shift $((OPTIND-1))

	# only process a single positional param and then run getopt again, this allow `-f fvalue positionali1 -x -v positional2 -d`
	if [ ${#LISTOFPARAMS[@]} -gt 0 ]; then
		PARAM=${LISTOFPARAMS[0]}
		LISTOFPARAMS=("${LISTOFPARAMS[@]:1}")
		eval ${PARAM}=$1;
		shift;
	else
		echo "Unexpected parameter \"$1\"."
		exit 1
	fi
done

if [ ${#LISTOFPARAMS[@]} -gt 0 ]; then
	echo "Missing required parameter ${LISTOFPARAMS[@]}"
	exit 1
fi

ab -k -n ${TOTALREQUESTS} -c ${CONCURRENTREQUESTS1} -g ${LOGFILE}-${CONCURRENTREQUESTS1}.tsv "${URL}"
sleep 1
ab -k -n ${TOTALREQUESTS} -c ${CONCURRENTREQUESTS2} -g ${LOGFILE}-${CONCURRENTREQUESTS2}.tsv "${URL}"
sleep 1
ab -k -n ${TOTALREQUESTS} -c ${CONCURRENTREQUESTS3} -g ${LOGFILE}-${CONCURRENTREQUESTS3}.tsv "${URL}"

cat << ENDPLOT > ${LOGFILE}.plot
set datafile separator "\\t"
set terminal png font "ubuntu mono, 11" size 800
set output "${LOGFILE}.png"

set multiplot layout 2, 1 title "Load test\n ${URL}"

set title "histogram ${TOTALREQUESTS} requests"
# the data is already sorted by duration, so just plot as is for histogram
set grid
set key below
#set xdata time
set timefmt "%a %b %d %H:%M:%S %Y"
set xlabel "bucket"
set ylabel "response time (ms)"
plot "${LOGFILE}-${CONCURRENTREQUESTS1}.tsv" using 5 smooth sbezier with lines lc "#00ff00" title "${CONCURRENTREQUESTS1} concurrent requests", \\
     "${LOGFILE}-${CONCURRENTREQUESTS2}.tsv" using 5 smooth sbezier with lines lc "#0066ff" title "${CONCURRENTREQUESTS2} concurrent requests", \\
     "${LOGFILE}-${CONCURRENTREQUESTS3}.tsv" using 5 smooth sbezier with lines lc "#ffaa00" title "${CONCURRENTREQUESTS3} concurrent requests", \\


set title "${TOTALREQUESTS} requests"
set grid
set key below
set xdata time
set timefmt "%a %b %d %H:%M:%S %Y"
set xlabel "start time"
set ylabel "response time (ms)"
plot "${LOGFILE}-${CONCURRENTREQUESTS1}.tsv" using 1:5  lc "#00ff00" title "${CONCURRENTREQUESTS1} concurrent requests", \\
     "${LOGFILE}-${CONCURRENTREQUESTS2}.tsv" using 1:5  lc "#0066ff" title "${CONCURRENTREQUESTS2} concurrent requests", \\
     "${LOGFILE}-${CONCURRENTREQUESTS3}.tsv" using 1:5  lc "#ffaa00" title "${CONCURRENTREQUESTS3} concurrent requests", \\


#set title "by time"
#set key below
## to get by time, use seconds(2) or date(1) as X
#set timefmt "%s"
#set xdata time
##set xrange [ * : * ] noreverse nowriteback
#set timefmt "%a %b %d %H:%M:%S %Y"
#plot "${LOGFILE}-${CONCURRENTREQUESTS2}.tsv" using 1:(\$5-\$3)                 with filledcurve title "ttime" lc "#000000"
##    "${LOGFILE}-s-${CONCURRENTREQUESTS2}.tsv" using 2:(\$3+\$4)         with filledcurve title "dtime" lc "#00ff00"
##    "${LOGFILE}-${CONCURRENTREQUESTS1}.tsv" using 2:(3+4+5)     with filledcurve title "ttime" lc "#00ffff", \\
##    "${LOGFILE}-${CONCURRENTREQUESTS1}.tsv" using 2:(3+4+5+6) with filledcurve title "wait"  lc "#ff0000"
unset multiplot
ENDPLOT

command gnuplot ${LOGFILE}.plot

