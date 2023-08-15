program bininfo;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.RES}

uses
  getopts,
  SysUtils,
  windows,
  UtilStr,
  BinaryInfo;

const
  PROGRAM_NAME = 'bininfo';
  PROGRAM_COPYRIGHT = 'Copyright (C) 2023 by Bill Stewart';
  CMD_NONE = $00;
  CMD_HELP = $01;
  CMD_MACHINE = $02;
  CMD_BINTYPE = $04;
  CMD_VERSION = $08;

type
  TCommandLine = object
    Status: DWORD;
    Flags: DWORD;
    ArgMachine: string;
    ArgBinType: string;
    ArgVersion: string;
    CSVOutput: Boolean;
    Verbose: Boolean;
    Files: TArrayOfString;
    procedure Parse();
  end;

procedure Usage();
begin
  WriteLn(PROGRAM_NAME, ' ', GetBinaryFileVersion(ParamStr(0)), ' - ', PROGRAM_COPYRIGHT);
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('SYNOPSIS');
  WriteLn();
  WriteLn('Outputs and tests information about binary files.');
  WriteLn();
  WriteLn('USAGE');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' [parameter [...]] file');
  WriteLn();
  WriteLn('Parameter            Description');
  WriteLn('-------------------  --------------------------------------------------');
  WriteLn('--machine <machine>  Test if file compiled to run on a machine type');
  WriteLn('--bintype <bintype>  Test if file compiled as a specific type');
  WriteLn('--version <version>  Test if file version is at least specified version');
  WriteLn('--csv                Writes output in comma-separated format');
  WriteLn();
  WriteLn('<machine> is the machine type; e.g.: AMD64, x86, ARM64, etc.');
  WriteLn('<bintype> is the binary type; e.g.: Console, DLL, GUI, etc.');
  WriteLn('<version> is a file version number; e.g. 6.2.22621.1635');
  WriteLn();
  WriteLn('Parameter names are case-sensitive. Omit all parameters to output file details.');
  WriteLn('Specify one or more parameters to test whether the binary file matches. If the');
  WriteLn('file matches the parameters, the program will exit with an exit code of 1; if');
  WriteLn('the file does not match the parameters, the program will exit with an exit code');
  WriteLn('of 0.');
  WriteLn();
  WriteLn('EXIT CODES');
  WriteLn();
  WriteLn('0  - File does not match one or more test parameters');
  WriteLn('1  - File matches all test parameters');
  WriteLn('2  - File not found');
  WriteLn('3  - Path not found');
  WriteLn('11 - File is not recognized as a binary file');
  WriteLn('87 - One or more parameters is not correct');
  WriteLn();
  WriteLn('EXAMPLES');
  WriteLn();
  WriteLn('1. bininfo --csv C:\Windows\System32\*.dll');
  WriteLn('   Outputs information about the specified files in comma-separated format.');
  WriteLn();
  WriteLn('2. bininfo --machine amd64 x86_64\bininfo.exe');
  WriteLn('   Exit code will be 1 if the specified file is AMD64, or 0 otherwise.');
  WriteLn();
  WriteLn('3. bininfo --version 116.0 "C:\Program Files\Mozilla Firefox\firefox.exe"');
  WriteLn('   Exit code will be 1 if the specified file is version 116.0 or later, or 0');
  WriteLn('   otherwise.');
  WriteLn();
  WriteLn('4. bininfo --machine x86 --bintype console i386\bininfo.exe');
  WriteLn('   Exit code will be 1 if the specified file is x86 and a console application,');
  WriteLn('   or 0 otherwise.');
  WriteLn();
  WriteLn('5. bininfo --machine amd64 --bintype dll --version 12.8 myapp.dll');
  WriteLn('   Exit code will be 1 if the specified file is an AMD64 DLL version 12.8 or');
  WriteLn('   newer, or 0 otherwise.');
end;

function GetWindowsMessage(const MessageID: DWORD; const Prefix: Boolean): string;
const
  NOT_BINARY_STR = 'File is not recognized as a binary file.';
var
  FormatFlags: DWORD;
  pBuffer: PChar;
begin
  if MessageID = ERROR_BAD_FORMAT then
  begin
    if Prefix then
      result := 'Error ' + DWORDToStr(ERROR_BAD_FORMAT) + ': ' + NOT_BINARY_STR
    else
      result := NOT_BINARY_STR;
    exit;
  end;
  FormatFlags := FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_IGNORE_INSERTS or
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_MAX_WIDTH_MASK;
  if FormatMessageW(FormatFlags,                // DWORD   dwFlags
    nil,                                        // LPCVOID lpSource
    MessageID,                                  // DWORD   dwMessageId
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),  // DWORD   dwLanguageId
    @pBuffer,                                   // LPWSTR  lpBuffer
    0,                                          // DWORD   nSize
    nil) > 0 then                               // va_list *Arguments
  begin
    if MessageID = ERROR_SUCCESS then
      result := Trim(string(pBuffer))
    else
    begin
      if Prefix then
        result := 'Error ' + DWORDToStr(MessageID) + ': ' + Trim(string(pBuffer))
      else
        result := Trim(string(pBuffer));
    end;
    LocalFree(HLOCAL(pBuffer));  // HLOCAL hMem
  end
  else
    result := 'Error ' + DWORDToStr(MessageID);
end;

procedure TCommandLine.Parse();
var
  Opts: array[1..7] of TOption;
  Opt: Char;
  I, FileCount, J: LongInt;
  LongOptName: string;
begin
  with Opts[1] do
  begin
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'h';
  end;
  with Opts[2] do
  begin
    Name := 'machine';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'm';
  end;
  with Opts[3] do
  begin
    Name := 'bintype';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 't';
  end;
  with Opts[4] do
  begin
    Name := 'version';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'v';
  end;
  with Opts[5] do
  begin
    Name := 'csv';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[6] do
  begin
    Name := 'verbose';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with Opts[7] do
  begin
    Name := '';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  Status := 0;
  Flags := CMD_NONE;
  ArgMachine := '';
  ArgBinType := '';
  ArgVersion := '';
  CSVOutput := false;
  Verbose := false;
  OptErr := false;
  repeat
    Opt := GetLongOpts('+hm:t:v:', @Opts[1], I);
    case Opt of
      'h':
      begin
        Flags := CMD_HELP;
      end;
      'm':
      begin
        Flags := Flags or CMD_MACHINE;
        ArgMachine := AnsiToString(OptArg, CP_ACP);
      end;
      't':
      begin
        Flags := Flags or CMD_BINTYPE;
        ArgBinType := AnsiToString(OptArg, CP_ACP);
      end;
      'v':
      begin
        Flags := Flags or CMD_VERSION;
        ArgVersion := AnsiToString(OptArg, CP_ACP);
        if not TestVersionString(ArgVersion) then
          Status := ERROR_INVALID_PARAMETER;
      end;
      '?':
      begin
        Status := ERROR_INVALID_PARAMETER;
      end;
      #0:
      begin
        LongOptName := AnsiToString(Opts[I].Name, CP_ACP);
        case LongOptName of
          'csv': CSVOutput := true;
          'verbose': Verbose := true;
          else
            Status := ERROR_INVALID_PARAMETER;
        end;
      end;
    end;
  until Opt = EndOfOptions;
  FileCount := ParamCount() - OptInd + 1;
  if FileCount > 0 then
  begin
    SetLength(Files, FileCount);
    J := OptInd;
    for I := 0 to FileCount - 1 do
    begin
      Files[I] := ParamStr(J);
      Inc(J);
    end;
  end
  else
    Status := ERROR_INVALID_PARAMETER;
end;

function LongIntToBool(const I: LongInt): Boolean;
begin
  if I <> 0 then
    result := true
  else
    result := false;
end;

function AttrToString(const Attr: LongInt): string;
const
  FA_ARCHIVE = $20;
  FA_READONLY = $01;
  FA_HIDDEN = $02;
  FA_SYSFILE = $04;
begin
  result := '----';
  if (Attr and FA_ARCHIVE) <> 0 then
    result[1] := 'a';
  if (Attr and FA_READONLY) <> 0 then
    result[2] := 'r';
  if (Attr and FA_HIDDEN) <> 0 then
    result[3] := 'h';
  if (Attr and FA_SYSFILE) <> 0 then
    result[4] := 's';
end;

procedure WriteBinInfo(const FileName: string; CSVOutput: Boolean);
const
  COL1_WIDTH = 6;
  COL2_WIDTH = 11;
  COL3_WIDTH = 9;
  COL4_WIDTH = 25;
var
  PathPart, Attrs, MachineName, BinaryType, Version, Info: string;
  Status: LongInt;
  SR: TUnicodeSearchRec;
  BinaryFile: TWindowsBinaryFile;
begin
  PathPart := ExtractFilePath(FileName);
  Attrs := '-';
  MachineName := '-';
  BinaryType := '-';
  Version := '-.-.-.-';
  Status := SysUtils.FindFirst(FileName, faAnyFile and (not faDirectory), SR);
  if Status = 0 then
  begin
    repeat
      Attrs := AttrToString(SR.Attr);
      BinaryFile := TWindowsBinaryFile.Create(PathPart + SR.Name);
      case BinaryFile.Status of
        ERROR_SUCCESS:
        begin
          MachineName := BinaryFile.MachineName;
          BinaryType := BinaryFile.BinaryType;
          Version := BinaryFile.Version;
          Info := PathPart + SR.Name;
        end;
        ERROR_BAD_FORMAT:
        begin
          MachineName := 'N/A';
          BinaryType := 'N/A';
          Version := 'N/A';
          Info := PathPart + SR.Name + ' <' +
            GetWindowsMessage(BinaryFile.Status, false) + '>';
        end;
        else
        begin
          Info := PathPart + SR.Name + ' <' +
            GetWindowsMessage(BinaryFile.Status, false) + '>';
        end;
      end;
      BinaryFile.Destroy();
      if CSVOutput then
        WriteLn('"', Attrs, '",',
          '"', MachineName, '",',
          '"', BinaryType, '",',
          '"', Version, '",',
          '"', Info, '"')
      else
        WriteLn(PadRight(Attrs, COL1_WIDTH),
          PadRight(MachineName, COL2_WIDTH),
          PadRight(BinaryType, COL3_WIDTH),
          PadRight(Version, COL4_WIDTH),
          Info);
    until SysUtils.FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end
  else
  begin
    Info := FileName + ' <' + GetWindowsMessage(DWORD(Status), false) + '>';
    if CSVOutput then
        WriteLn('"', Attrs, '",',
          '"', MachineName, '",',
          '"', BinaryType, '",',
          '"', Version, '"',
          '"', Info, '"')
    else
      WriteLn(PadRight(Attrs, COL1_WIDTH),
        PadRight(MachineName, COL2_WIDTH),
        PadRight(BinaryType, COL3_WIDTH),
        PadRight(Version, COL4_WIDTH),
        Info);
  end;
end;

var
  CommandLine: TCommandLine;
  I: LongInt;
  ArgsMatch: DWORD;
  BinaryFile: TWindowsBinaryFile;

begin
  CommandLine.Parse();
  if (ParamStr(1) = '/?') or ((CommandLine.Flags and CMD_HELP) <> 0) or
    (Length(CommandLine.Files) < 1) then
  begin
    Usage();
    exit;
  end;

  if CommandLine.Status = ERROR_INVALID_PARAMETER then
  begin
    WriteLn(GetWindowsMessage(CommandLine.Status, true));
    ExitCode := LongInt(CommandLine.Status);
    exit;
  end;

  if CommandLine.Flags = CMD_NONE then
  begin
    for I := 0 to Length(CommandLine.Files) - 1 do
      WriteBinInfo(CommandLine.Files[I], CommandLine.CSVOutput);
    exit;
  end;

  BinaryFile := TWindowsBinaryFile.Create(CommandLine.Files[0]);
  if BinaryFile.Status <> ERROR_SUCCESS then
  begin
    WriteLn(GetWindowsMessage(BinaryFile.Status, true));
    ExitCode := LongInt(BinaryFile.Status);
    BinaryFile.Destroy();
    exit;
  end;

  ArgsMatch := 0;

  if (CommandLine.Flags and CMD_MACHINE) <> 0 then
  begin
    if SameText(BinaryFile.MachineName, CommandLine.ArgMachine) then
    begin
      ArgsMatch := ArgsMatch or CMD_MACHINE;
      if CommandLine.Verbose then
        WriteLn('--machine "', CommandLine.ArgMachine, '" matches file.');
    end
    else
    begin
      if CommandLine.Verbose then
        WriteLn('--machine "', CommandLine.ArgMachine, '" does not match file (',
          BinaryFile.MachineName, ').');
    end;
  end;

  if (CommandLine.Flags and CMD_BINTYPE) <> 0 then
  begin
    if SameText(BinaryFile.BinaryType, CommandLine.ArgBinType) then
    begin
      ArgsMatch := ArgsMatch or CMD_BINTYPE;
      if CommandLine.Verbose then
        WriteLn('--bintype "', CommandLine.ArgBinType, '" matches file.');
    end
    else
    begin
      if CommandLine.Verbose then
        WriteLn('--bintype "', CommandLine.ArgBinType, '" does not match file (',
          BinaryFile.BinaryType, ').');
    end;
  end;

  if (CommandLine.Flags and CMD_VERSION) <> 0 then
  begin
    if BinaryFile.Version = '' then
    begin
      if CommandLine.Verbose then
      WriteLn('File does not have version information');
    end
    else if CompareVersionStrings(BinaryFile.Version, CommandLine.ArgVersion) >= 0 then
    begin
      ArgsMatch := ArgsMatch or CMD_VERSION;
      if CommandLine.Verbose then
        WriteLn('--version "', CommandLine.ArgVersion, '" is <= file version (',
          BinaryFile.Version, ').');
    end
    else
    begin
      if CommandLine.Verbose then
        WriteLn('--version "', CommandLine.ArgVersion, '" is > file version (',
          BinaryFile.Version, ').');
    end;
  end;

  BinaryFile.Destroy();

  if ArgsMatch = CommandLine.Flags then
    ExitCode := 1
  else
    ExitCode := 0;

  if CommandLine.Verbose then
    WriteLn('Test success = ', LongIntToBool(ExitCode), '; exit code = ', ExitCode);

end.
