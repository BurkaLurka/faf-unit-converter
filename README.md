# faf-unit-converter

Converts unit LUA blueprint files to JSON. Built to provide an easy-to-use and web-friendly format for building an updated unit database.

### Readme

[Burke Lougheed](https://github.com/Burka-HWP)

Shell script to convert the unit LUA blueprint files to JSON, performs a series of regexes using sed and perl, then validates and formats using python's mjson.tool.

As of patch 3660, script successfully converts all unit.bp files found in the **units/** directory of the Forged Alliance: Forever's [fa/](https://github.com/FAForever/fa) repository.

Last tested October 16, 2016

### Dependencies

Forged Alliance: Forever's [fa/](https://github.com/FAForever/fa) repository

### Usage

- Clone the fa/ repository mentioned above
- Clone this repository
- Open a terminal window, navigate to this repository
- Run `./convert.sh [PATH TO fa/] [DESTINATION]`
- Allow script to complete, takes ~5 minutes. If any errors occur, please let me know or submit a pull request


Cheers!