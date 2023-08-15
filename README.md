# bininfo

**bininfo** is a Windows console (command-line) utility that outputs and tests information about binary files.

## Copyright and Author

Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

## License

**bininfo** is covered by the GNU Public License (GPL). See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/bininfo/releases

## Usage

**bininfo** [_parameter_ [...]] _file_

| Parameter               | Description
| ---------               | -----------
| **--machine** _machine_ | Test if file compiled to run on a machine type
| **--bintype** _bintype_ | Test if file compiled as a specific type
| **--version** _version_ | Test if file version is at least specified version
| **--csv**               | Writes output in comma-separated format

Where:

* _machine_ is the machine type; e.g.: **AMD64**, **x86**, **ARM64**, etc.
* _bintype_ is the binary type; e.g.: **Console**, **DLL**, **GUI**, etc.
* _version_ is a file version; e.g.: **6.2.22621.1635**

Parameter names are case-sensitive. Omit all parameters to output file details. Specify one or more parameters to test whether the binary file matches. If the file matches the parameters, the program will exit with an exit code of 1; if the file does not match the parameters, the program will exit with an exit code of 0.

## Exit Codes

| Code | Description
| ---- | -----------
| 0    | File does not match one or more test parameters
| 1    | File matches all test parameters
| 2    | File not found
| 3    | Path not found
| 11   | File is not recognized as a binary file
| 87   | One or more parameters is not correct

## Examples

1. `bininfo --csv C:\Windows\System32\*.dll`

   Outputs information about the specified files in comma-separated format.

2. `bininfo --machine amd64 x86_64\bininfo.exe`

   Exit code will be 1 if the specified file is AMD64, or 0 otherwise.

3. `bininfo --version 116.0 "C:\Program Files\Mozilla Firefox\firefox.exe"`

   Exit code will be 1 if the specified file is version 116.0 or later, or 0 otherwise.

4. `bininfo --machine x86 --bintype console i386\bininfo.exe`

   Exit code will be 1 if the specified file is x86 and a console application, or 0 otherwise.

5. `bininfo --machine amd64 --bintype dll --version 12.8 myapp.dll`

   Exit code will be 1 if the specified file is an AMD64 DLL version 12.8 or newer, or 0 otherwise.

## Technical Details

**bininfo** uses the Windows [ImageLoad API function](https://learn.microsoft.com/en-us/windows/win32/api/imagehlp/nf-imagehlp-imageload) to retrieve information about binary files.

## Icon Attribution

Program icon courtesy of [Icons8](https://icons8.com/) - [Online Binary Code](https://icons8.com/icon/UVQTFk728g0D/online-binary-code)
