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
./httpdsh.sh
```

or

```bash
ncat -k -lp $PORT -e "./handler.sh $WorkingDirectoryPath"
```

note that using f.e. port 80 you need to give sudo privilages to ncat default port is 8080 and default working directory is ~/.httpdsh/files

Important note also is to not forget to upload json file of the same name as one given in URL when using multipart/form-data
example:

```bash
curl -F key1=value1 $SERVER_ADDR:$PORT/filename.json -F uplad=@filename.json
```

## Known issues

If you want to upload data in form of application/json, remember to put trailing empty line with one character due to issue with netcat not passing last line of request to script. Otherwise server will hang unable to parse entire request.

## LICENSE

[MIT](https://choosealicense.com/licenses/mit/)
