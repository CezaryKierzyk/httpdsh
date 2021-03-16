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

RX_FULL_REQUEST=()					#Received Full request
RX_HEADERS=()						#Received Header 
RX_BODIES=()						#Received body
RX_URI=""						#Received URI
RX_CONTENT_LENGTH=500					#Received content-length
RX_BOUNDARY=""						#Boundary of form data request
RX_REQUEST_TYPE=""					#f.e. GET, POST, PUT
RX_REQUESTED_RESOURCE=""				#f.e. from uri /file.json
RX_FILENAME=""						#file from multipart/form-data
RX_CONTENT_TYPE=""					#Received body content type

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
function parse_request(){
	[[ $(ls $PWD) == *"$LOG"* ]] rm "$PWD$LOG"
	i=0										#outer loop iterator
	rx_file_begin=0									#flag of form/data file beggining
	counter=0									#content length counter
	exit_loop=0									#if all data gathered flag

	{ while true;
	do
	{ while IFS= read -r line;
		do
			[ $i -eq 0 ] && line="${line%%$'\r'}"				#strip lines insignificant to length counter
			[ -z "$line" ] && break						#if header ended jump to outer loop
			RX_FULL_REQUEST+=("$line")	
			if [ -z $RX_BOUNDARY ]
			then
			
				if [ $i -eq 0 ]
				then
					
					RX_HEADERS+=("$line")	 			#Fetch all application/json headers
				else 
					RX_BODIES+=("$line")				#fetch all body lines
					RX_FILE=$RX_FILE"$line"
					counter=$(($counter+$(echo "$line" | wc -c)))
				fi
			else
				[ -n "$RX_BOUNDARY" ] && [[ $line == *"$RX_BOUNDARY"* ]]  && [ $rx_file_begin -eq 1 ] && rx_file_begin=0
				counter=$(($counter+$(echo "$line" | wc -c)))
				RX_BODIES+=("$line")
				[ $rx_file_begin -eq 1 ] && ! [[ $line == *'Content-Type'* ]] &&  RX_FILE="${RX_FILE}${line}"
				[[ $line == *"filename"* ]] && RX_FILENAME=$(echo $line | cut -d ';' -f3 | cut  -d '=' -f2 | tr -d '\"') && rx_file_begin=1 
		fi	
		[[ $counter -ge $(($RX_CONTENT_LENGTH-1)) ]] && exit_loop=1 && break	#if gathered all data exit all loops
		done }
	
		[ $exit_loop -eq 1 ] && break
		if [ $i -eq 0 ]	
		then
			RX_URI=$(echo ${RX_FULL_REQUEST[0]} | cut -d ' ' -f2)
			RX_REQUESTED_RESOURCE="$(echo $RX_URI | cut -d '/' -f2)"
			RX_REQUEST_TYPE=$(echo $RX_FULL_REQUEST[0] | cut -d ' ' -f1)
			{ for f in "${RX_FULL_REQUEST[@]}"
			do
				[[ $f == *'Content-Length'* ]] && RX_CONTENT_LENGTH=$(echo $f | cut -d ':' -f2)
				[[ $f == *'multipart/form-data'* ]] && RX_CONTENT_TYPE="form-data"
				[[ $f == *'application/json'* ]] && RX_CONTENT_TYPE="json"
				[[ $f == *'form-data'* ]] && RX_BOUNDARY=$(echo $f | cut -d '=' -f2)
			done }							
		fi								    #####fetch all significant info from headers
		[ $RX_REQUEST_TYPE != "POST" ] && fail_with_code 501			#if request type is other than post fail with 501
		[ $RX_CONTENT_LENGTH -ge 10000 ] && fail_with_code 400			#if content length is bigger than 10kB fail wit 400
	       	[ -z "$RX_CONTENT_TYPE" ]  && fail_with_code 400			#if content type is empty fail with 400
		i=$(($i+1))
		
	done }
}										########Parser of the request

function check_pattern(){ ! [[ $1 =~ [a-z0-9_] ]] && fail_with_code 400;} 	########if pattern is not matched fail with bad request

function check_file_syntax(){
	if [ $(echo $RX_FILE | jq empty > /dev/null 2>&1; echo $?) -ne 0 ]
       	then
		fail_with_code 400
	fi
}										#######Using jq tool (1.6 or above) check if file has correct syntax

function check_request(){
	[ -n $RX_BOUNDARY ] && check_pattern "$RX_FILENAME"
	check_pattern "$RX_REQUESTED_RESOURCE"
	[ -n "${RX_BOUNDARY}" ] && ! [ ${RX_FILENAME%%$'\r'} == $RX_REQUESTED_RESOURCE ] && fail_with_code 400
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
	echo "$TX_BODY"	| tee /dev/tty >&1
}										########Send prebuild response
######################################___________MAIN____________############################################

parse_request 
check_request
save_file
build_response_body
build_response_header
send
