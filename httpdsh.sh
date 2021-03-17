#!/bin/sh
##################_____DECLARATIONS_____###################

declare -a PWD="${HOME}/.httpdsh/files/"
declare -a PORT="8080"

###################_____FUNCTIONS_____###################
function print_help (){
	echo "	Simple POSIX Shell HTTP server
	USAGE:
	./httpdsh [option] <parameter>

	OPTIONS:

	-p <port_number> - choose port number to listen on
	-d <directory path> - choose working directory of the server
	-h display this help
	"
	exit
}
function check_directory(){ ! [ -d "$PWD" ] && mkdir -p "$PWD"; }

###################________MAIN__________##################
while test $# -gt 0
do
	case $1 in
		'-p') PORT=$2
			;;
		'-d') PWD="$2"
			;;
		'-*') print_help
			;;
		'-h') print_help
			;;
	esac
	shift
done
check_directory
ncat -k -lp $PORT -e "./handler.sh $PWD" 
