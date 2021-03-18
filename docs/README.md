# HTTPDSH

HTTPDSH is a simple POSIX Shell web server designed to receive and respond to POST requests of application/json and multipart/form-data types. Server is only parsing sent .json files and data, with syntax validation and responding with basic statistics of those data.

## Requirements

To use this POSIX Shell server you need to have:

   - Ncat 7.91
   - JQ
   - Git

## Installation

To install this simplified server you just have to use this command:

```bash
git clone https://github.com/CezaryKierzyk/httpdsh
```

## Usage

To run this server go to cloned httpdsh directory and type:

```bash
./httpdsh
```

By default you can run this program using port 8080 to listen for incoming data and ~/.httpdsh/files to save parsed data. However you can change that behavior either by using flags:

```bash
./httpdsh.sh -p $PORT -d $WORKING_DIRECTORY
```

or just by using ncat 

```bash
ncat -k -lp $PORT -e "./parser $WORKING_DIRECTORY"
```

note that using f.e. port 80 you need to give sudo privilages to ncat.

Important note also is to not forget to upload json file of the same name as one given in URL when using multipart/form-data

example:

```bash
curl -F key1=value1 $SERVER_ADDR:$PORT/filename.json -F uplad=@filename.json
```

## Known issues

+ If you want to upload data in form of application/json, remember to put trailing empty line with one character due to issue with netcat not passing last line of request to script. Otherwise server will hang unable to parse entire request.

+ application/x-form-urlencoded is not implemented, due to sending json files, or any possibly nested files this way is... not ideal at best.

+ multipart/form-data request only cares for valid json file applying for criteria of same uri same name, any other file will be discared or will result in error 400.

## LICENSE

[MIT](https://choosealicense.com/licenses/mit/)
