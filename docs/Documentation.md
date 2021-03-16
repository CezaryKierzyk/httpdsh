# HTTPDSH Documentation

## Objective

Basic POST method functionality implementation.

## Scope

| Must have | Nice to have | Out of scope|
|___________|____________|____________|
|1. Parsing POST requests| 1. Passes filename as an argument to handler | |
|2. Parsing request path | 2. Allows to define port | |
|3. Parsing JSON files | 3. Allows to define working directory | |
|4. Saves file in "files" folder| | |
|5. Checks if Content-Type is set| | |
|6. Drops requests above 10 kB | | |
|7. Validates URI and filename | | |
|8. Checks JSON file syntax | | |
|9. Displays file statistics: no. of lines, size, length of first level on stdout and in response| | |
