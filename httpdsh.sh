#!/bin/sh
##################_____DECLARATIONS_____###################

declare -a PWD="${HOME}/.httpdsh/files/"
declare -a PORT="8080"

###################_____FUNCTIONS_____###################

function check_directory(){
	if [ -z $(ls -a ~ | grep ".httpdsh") ]
	then
		mkdir -p $PWD
	fi	
}

###################________MAIN__________##################
check_directory
ncat -k -lp $PORT -e "./handler.sh $PWD" 
