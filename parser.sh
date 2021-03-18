#!/bin/sh

PWD="$1"
LOG="${PWD}httpdsh.log"

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

rx_tmp_filename=""
###########################_________________FUNCTIONS____________#############################################

function log (){
	echo $1 | tee /dev/tty >> $LOG
}						#########Log to /dev/tty and to logfile

function parse_request(){
	[ -n $(ls "$LOG") ] && rm "$LOG"
	i=0										#outer loop iterator
	rx_file_begin=0									#flag of form/data file beggining
	counter=0									#content length counter
	exit_loop=0									#if all data gathered flag

	{ while true;
	do
	{ while IFS= read -r line;
		do
			[ $i -eq 0 ] && line="${line%%$'\r'}"				#strip lines insignificant to length counter
			[ $i -eq 0 ] && [ -z "$line" ] && break						#if header ended jump to outer loop
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
				[[ $line == *"$RX_BOUNDARY"* ]]  && [ $rx_file_begin -eq 1 ] && rx_file_begin=0
				counter=$(($counter+$(echo "$line" | wc -c)))
				RX_BODIES+=("$line")
				[ $rx_file_begin -eq 1 ] && ! [[ $line == *'Content-Type'* ]] &&  RX_FILE="${RX_FILE}${line}"
				{ if [[ $line == *"filename"* ]]
				then       
					rx_tmp_filename="$(echo $line | cut -d ';' -f3 | cut  -d '=' -f2 | tr -d '\"')"
					[ ${rx_tmp_filename%%$'\r'} == ${RX_REQUESTED_RESOURCE} ] && rx_file_begin=1 && RX_FILENAME=$rx_tmp_filename
				fi }
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
		[ $RX_REQUEST_TYPE != "POST" ] && ./handler.sh -e 501			#if request type is other than post fail with 501
	       	[ -z "$RX_CONTENT_TYPE" ]  && log "no content type" && ./handler.sh -e 400			#if content type is empty fail with 400
		i=$(($i+1))
		
	done }
	! [ -z ${RX_FILENAME} ] && ./handler.sh -f $RX_FILENAME -u $RX_REQUESTED_RESOURCE -d "$RX_FILE" -w $PWD -l $LOG >&1
	[ -z ${RX_FILENAME} ] && ./handler.sh -u $RX_REQUESTED_RESOURCE -d "$RX_FILE" -w $PWD -l $LOG >&1
}										########Parser of the request


################################________________MAIN__________________####################################

parse_request
