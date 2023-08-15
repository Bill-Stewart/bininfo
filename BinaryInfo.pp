{ Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

unit BinaryInfo;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

interface

uses
  Windows;

type
  TWindowsBinaryFile = class
  private
    var
      Error: DWORD;
      ImageFileName: string;
      ImageFileMachineName: string;
      ImageFileBinaryType: string;
      ImageFileVersion: string;
    function GetMachineName(const Machine: Word): string;
    function GetSubsystemName(const Subsystem: Word): string;
  public
    property Status: DWORD read Error;
    property FileName: string read ImageFileName;
    property MachineName: string read ImageFileMachineName;
    property BinaryType: string read ImageFileBinaryType;
    property Version: string read ImageFileVersion;
    constructor Create(const NameOfFile: string);
    destructor Destroy(); override;
  end;

function GetBinaryFileVersion(const FileName: string): string;

implementation

uses
  imagehlp,
  UtilStr;

const
  // Machine
  IMAGE_FILE_MACHINE_UNKNOWN = $0000;
  IMAGE_FILE_MACHINE_TARGET_HOST = $0001;
  IMAGE_FILE_MACHINE_I386 = $014C;
  IMAGE_FILE_MACHINE_R3000BE = $0160;
  IMAGE_FILE_MACHINE_R3000 = $0162;
  IMAGE_FILE_MACHINE_R4000 = $0166;
  IMAGE_FILE_MACHINE_R10000 = $0168;
  IMAGE_FILE_MACHINE_WCEMIPSV2 = $0169;
  IMAGE_FILE_MACHINE_ALPHA = $0184;
  IMAGE_FILE_MACHINE_SH3 = $01A2;
  IMAGE_FILE_MACHINE_SH3DSP = $01A3;
  IMAGE_FILE_MACHINE_SH3E = $01A4;
  IMAGE_FILE_MACHINE_SH4 = $01A6;
  IMAGE_FILE_MACHINE_SH5 = $01A8;
  IMAGE_FILE_MACHINE_ARM = $01C0;
  IMAGE_FILE_MACHINE_THUMB = $01C2;
  IMAGE_FILE_MACHINE_ARMNT = $01C4;
  IMAGE_FILE_MACHINE_AM33 = $01D3;
  IMAGE_FILE_MACHINE_POWERPC = $01F0;
  IMAGE_FILE_MACHINE_POWERPCFP = $01F1;
  IMAGE_FILE_MACHINE_IA64 = $0200;
  IMAGE_FILE_MACHINE_MIPS16 = $0266;
  //IMAGE_FILE_MACHINE_ALPHA64 = $0284;  // duplicate of AXP64
  IMAGE_FILE_MACHINE_AXP64 = $0284;
  IMAGE_FILE_MACHINE_MIPSFPU = $0366;
  IMAGE_FILE_MACHINE_MIPSFPU16 = $0466;
  IMAGE_FILE_MACHINE_TRICORE = $0520;
  IMAGE_FILE_MACHINE_CEF = $0CEF;
  IMAGE_FILE_MACHINE_EBC = $0EBC;
  IMAGE_FILE_MACHINE_AMD64 = $8664;
  IMAGE_FILE_MACHINE_M32R = $9041;
  IMAGE_FILE_MACHINE_ARM64 = $AA64;
  IMAGE_FILE_MACHINE_CEE = $C0EE;
  // Characteristics
  IMAGE_FILE_RELOCS_STRIPPED = $0001;
  IMAGE_FILE_EXECUTABLE_IMAGE = $0002;
  IMAGE_FILE_LINE_NUMS_STRIPPED = $0004;
  IMAGE_FILE_LOCAL_SYMS_STRIPPED = $0008;
  IMAGE_FILE_AGGRESIVE_WS_TRIM = $0010;
  IMAGE_FILE_LARGE_ADDRESS_AWARE = $0020;
  IMAGE_FILE_BYTES_REVERSED_LO = $0080;
  IMAGE_FILE_32BIT_MACHINE = $0100;
  IMAGE_FILE_DEBUG_STRIPPED = $0200;
  IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP = $0400;
  IMAGE_FILE_NET_RUN_FROM_SWAP = $0800;
  IMAGE_FILE_SYSTEM = $1000;
  IMAGE_FILE_DLL = $2000;
  IMAGE_FILE_UP_SYSTEM_ONLY = $4000;
  IMAGE_FILE_BYTES_REVERSED_HI = $8000;
  // Subsystem
  IMAGE_SUBSYSTEM_UNKNOWN = 0;
  IMAGE_SUBSYSTEM_NATIVE = 1;
  IMAGE_SUBSYSTEM_WINDOWS_GUI = 2;
  IMAGE_SUBSYSTEM_WINDOWS_CUI = 3;
  IMAGE_SUBSYSTEM_OS2_CUI = 5;
  IMAGE_SUBSYSTEM_POSIX_CUI = 7;
  IMAGE_SUBSYSTEM_WINDOWS_CE_GUI = 9;
  IMAGE_SUBSYSTEM_EFI_APPLICATION = 10;
  IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER = 11;
  IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER = 12;
  IMAGE_SUBSYSTEM_EFI_ROM = 13;
  IMAGE_SUBSYSTEM_XBOX = 14;
  IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION = 16;

function IntToStr(const I: LongInt): string;
begin
  Str(I, result);
end;

function GetBinaryFileVersion(const FileName: string): string;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  VerInfoSize := GetFileVersionInfoSizeW(PChar(FileName),  // LPCWSTR lptstrFilename
    Handle);                                               // LPDWORD lpdwHandle
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PChar(FileName),  // LPCWSTR lptstrFilename
      Handle,                                // DWORD   dwHandle
      VerInfoSize,                           // DWORD   dwLen
      pBuffer) then                          // LPVOID  lpData
    begin
      if VerQueryValueW(pBuffer,  // LPCVOID pBlock
        '\',                      // LPCWSTR lpSubBlock
        pFileInfo,                // LPVOID  *lplpBuffer
        Len) then                 // PUINT   puLen
      begin
        with pFileInfo^ do
        begin
          result := IntToStr(HiWord(dwFileVersionMS)) + '.' +
            IntToStr(LoWord(dwFileVersionMS)) + '.' +
            IntToStr(HiWord(dwFileVersionLS)) + '.' +
            IntToStr(LoWord(dwFileVersionLS));
        end;
      end;
    end;
    FreeMem(pBuffer, VerInfoSize);
  end;
end;

function TWindowsBinaryFile.GetMachineName(const Machine: Word): string;
begin
  case Machine of
    IMAGE_FILE_MACHINE_UNKNOWN: result := 'UNKNOWN';
    //IMAGE_FILE_MACHINE_TARGET_HOST: result := 'TARGET_HOST';
    IMAGE_FILE_MACHINE_I386: result := 'i386';
    IMAGE_FILE_MACHINE_R3000BE: result := 'R3000';
    IMAGE_FILE_MACHINE_R3000: result := 'R3000';
    IMAGE_FILE_MACHINE_R4000: result := 'R4000';
    IMAGE_FILE_MACHINE_R10000: result := 'R10000';
    IMAGE_FILE_MACHINE_WCEMIPSV2: result := 'WCEMIPSV2';
    IMAGE_FILE_MACHINE_ALPHA: result := 'ALPHA';
    IMAGE_FILE_MACHINE_SH3: result := 'SH3';
    IMAGE_FILE_MACHINE_SH3DSP: result := 'SH3DSP';
    IMAGE_FILE_MACHINE_SH3E: result := 'SH3E';
    IMAGE_FILE_MACHINE_SH4: result := 'SH4';
    IMAGE_FILE_MACHINE_SH5: result := 'SH5';
    IMAGE_FILE_MACHINE_ARM: result := 'ARM';
    IMAGE_FILE_MACHINE_THUMB: result := 'ARM';
    IMAGE_FILE_MACHINE_ARMNT: result := 'ARMNT';
    IMAGE_FILE_MACHINE_AM33: result := 'AM33';
    IMAGE_FILE_MACHINE_POWERPC: result := 'PowerPC';
    IMAGE_FILE_MACHINE_POWERPCFP: result := 'PowerPCFP';
    IMAGE_FILE_MACHINE_IA64: result := 'IA64';
    IMAGE_FILE_MACHINE_MIPS16: result := 'MIPS16';
    //IMAGE_FILE_MACHINE_ALPHA64: result := 'ALPHA64';
    IMAGE_FILE_MACHINE_AXP64: result := 'AXP64';
    IMAGE_FILE_MACHINE_MIPSFPU: result := 'MIPSFPU';
    IMAGE_FILE_MACHINE_MIPSFPU16: result := 'MIPSFPU16';
    IMAGE_FILE_MACHINE_TRICORE: result := 'Tricore';
    IMAGE_FILE_MACHINE_CEF: result := 'CEF';
    IMAGE_FILE_MACHINE_EBC: result := 'EBC';
    IMAGE_FILE_MACHINE_AMD64: result := 'AMD64';
    IMAGE_FILE_MACHINE_M32R: result := 'M32R';
    IMAGE_FILE_MACHINE_ARM64: result := 'ARM64';
    IMAGE_FILE_MACHINE_CEE: result := 'CEE';
    else
      result := '0x' + AnsiToString(HexStr(Machine, 4), CP_ACP);
  end;
end;

function TWindowsBinaryFile.GetSubsystemName(const Subsystem: Word): string;
begin
  case Subsystem of
    IMAGE_SUBSYSTEM_UNKNOWN: result := 'Unknown';
    IMAGE_SUBSYSTEM_NATIVE: result := 'Native';
    IMAGE_SUBSYSTEM_WINDOWS_GUI: result := 'GUI';
    IMAGE_SUBSYSTEM_WINDOWS_CUI: result := 'Console';
    IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION: result := 'Boot';
    else
      result := '0x' + AnsiToString(HexStr(Subsystem, 4), CP_ACP);
  end;
end;

constructor TWindowsBinaryFile.Create(const NameOfFile: string);
var
  pLoadedImage: PLOADED_IMAGE;
  Machine, Characteristics, Subsystem: Word;
begin
  ImageFileName := NameOfFile;
  Error := ERROR_SUCCESS;
  pLoadedImage := ImageLoad(PAnsiChar(StringToAnsi(ImageFileName, CP_ACP)), '');
  if not Assigned(pLoadedImage) then
  begin
    Error := GetLastError();
    exit;
  end;
  Machine := pLoadedImage^.FileHeader^.FileHeader.Machine;
  Characteristics := pLoadedImage^.FileHeader^.FileHeader.Characteristics;
  Subsystem := pLoadedImage^.FileHeader^.OptionalHeader.Subsystem;
  ImageUnload(pLoadedImage);
  ImageFileMachineName := GetMachineName(Machine);
  if (Characteristics and IMAGE_FILE_DLL) <> 0 then
    ImageFileBinaryType := 'DLL'
  else
    ImageFileBinaryType := GetSubsystemName(Subsystem);
  ImageFileVersion := GetBinaryFileVersion(ImageFileName);
end;

destructor TWindowsBinaryFile.Destroy();
begin
end;

begin
end.
