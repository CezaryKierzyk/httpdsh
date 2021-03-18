#!/bin/sh

#AUTHOR=Cezary Kierzyk
#DATE=12.03.2021
#MAIL=cezary@ckierzyk.com
#GITHUB=github.com/CezaryKierzyk

######################################______DECLARATIONS_______###################################################
 
PWD=$1							#working directory 
LOG="server_log.log"					#logfile
declare -a HTTP_RESPCODES=(				#HTTP responses
	[200]="OK"
	[400]="Bad Request"
	[403]="Forbidden"
	[404]="Not Found"
	[405]="Method not allowed"
	[500]="Internal Server Error"
	[501]="Not Implemented"
	[502]="Bad Gateway"
)

#######################________________RESPONSE DATA FIELDS_______________####################################

TX_CONTENT_TYPE=""					#Response Content-Type
TX_CONTENT_LENGTH=""					#Response Content-Length	
TX_SERVER="HTTPDSH - POSIX Shell HTTP Server"		#Server name
TX_BODY=""						#Response body

###############################___________RECEIVED DATA FIELDS_____________###################################

RX_REQUESTED_RESOURCE=""				#f.e. from uri /file.json
RX_FILENAME=""						#file from multipart/form-data
RX_FILE=""						#Posted file content
###########################_________________FUNCTIONS____________#############################################

function log (){
	echo $1 | tee /dev/tty >> $LOG
}						#########Log to /dev/tty and to logfile

function count_first_level(){

	cat $1 | tr -d '\n' | tr -d '\t'|		#remove all newlines and tabulations for easier json sedding
	sed 's/\[[^][]*\]//g'|				#remove all arrays (content in brackets [])
	sed 's/^{//g'|					#remove first brace {
	sed 's/}$//g'|					#remove last brace }
	sed 's/{[^{}]*}//g'|				#remove all subobjects (content of {})
	tr -cd ',' | wc -c				#leave only commas and count them (number of fields on first level)

} 						#########function to calculate number of fields on first level of json

function fail_with_code (){
	fail_response="HTTP/1.1 $1 ${HTTP_RESPCODES[$1]}"
	echo -e $fail_response
	exit
}						#########Respond to client with given fail code 

function ok (){
	response="HTTP/1.1 200 ${HTTP_RESPCODES[200]}"
	echo -e $response
}
						#######Give a OK to client

function check_pattern(){ ! [[ $1 =~ [a-z0-9_] ]] && log "wrong $1 pattern" && fail_with_code 400;} 	########if pattern is not matched fail with bad request

function check_file_syntax(){
	if [ $(echo $RX_FILE | jq empty > /dev/null 2>&1; echo $?) -ne 0 ]
       	then
		log "wrong syntax"
		fail_with_code 400
	fi
}										#######Using jq tool (1.6 or above) check if file has correct syntax

function check_request(){
	[ $(echo $RX_FILE | wc -c) -gt 10000 ] && log "file too large" && fail_with_code 400
	! [ -z ${RX_FILENAME} ] && check_pattern "$RX_FILENAME"
	check_pattern "$RX_REQUESTED_RESOURCE"
	! [ -z ${RX_FILENAME} ] && ! [ ${RX_FILENAME%%$'\r'} == $RX_REQUESTED_RESOURCE ] && log " $RX_FILENAME differs from uri" && fail_with_code 400
	check_file_syntax
}										#######Check for invalid patterns or paths in request


function counts(){

	count=$(count_first_level $1)						
	first_level_count=$(($count+1))							#Get first level object length
	line_count=$(cat $1 | wc -l)							#Get line count
	bytes=$(cat $1 | wc -c) 							#Get filesize in bytes
	size="$bytes B" 
	if [ $bytes -ge 1000 ]
	then
		size="$(bc -l <<< "a=$bytes/1000; a+=0.05; scale=1; a/1")K" 		#convert from bytes to kilobytes
	fi
	echo -e "number of main object fields: $first_level_count; number of lines: $line_count; file size: $size" 	#echo all the statistics for the sake of response
}										#########Collectively calculate file statistics 


function save_file(){
	echo "$RX_FILE" | jq . > ${PWD}${RX_REQUESTED_RESOURCE}
}										#########Save parsed file to working directory
function build_response_body (){
	
	TX_BODY="$(counts $RX_REQUESTED_RESOURCE)"
}										########Build response body from gathered data

function build_response_header () {
	TX_CONTENT_LENGTH=$(echo "$TX_BODY" | wc -c)
	TX_CONTENT_TYPE="text/html"
}										########Build response header for received request

function send (){
	ok
	echo "Server: $TX_SERVER"
	echo "Content-Type: $TX_CONTENT_TYPE"
	echo "Content-Length: $TX_CONTENT_LENGTH"
	echo ""
	log "$TX_BODY"
	echo "$TX_BODY"
}										########Send prebuild response
######################################___________MAIN____________############################################
while test $# -gt 0
do
	case $1 in
		'-f') RX_FILENAME=$2
			;;
		'-u') RX_REQUESTED_RESOURCE=$2
			;;
		'-d') RX_FILE=$2
			;;
		'-w') PWD=$2
			;;
		'-l') LOG=$2
			;;
		'-e') fail_with_code $2
	esac
	shift
done

check_request
save_file
build_response_body
build_response_header
send
