#!/usr/bin/env bash
set -e

usage(){
	echo "$0 [-d|-r] [-v] [-l logfilename] totalrequests concurrentrequests url"
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
declare -a LISTOFPARAMS=("TOTALREQUESTS" "CONCURRENTREQUESTS" "URL")

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
		d|r) MODE="${OPTARG}";;
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

ab -k -n ${TOTALREQUESTS} -c ${CONCURRENTREQUESTS} -g ${LOGFILE}.tsv "${URL}"

cat << ENDPLOT > ${LOGFILE}.plot
set terminal png size 600 set output "${LOGFILE}.png"set title"${TOTALREQUESTS} requests, ${CONCURRENTREQUESTS} concurrent requests "set size ratio 0.6 set grid and set xlabel"requests" set ylabel"response time (ms)" plot"${LOGFILE}.tsv"using 9 smooth sbezier with lines title"TESTING 123"
ENDPLOT

command gnuplot ${LOGFILE}.plot

