{ Copyright (C) 2023 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

unit UtilStr;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

interface

uses
  Windows;

type
  TArrayOfString = array of string;

function AnsiToString(const S: AnsiString; const CodePage: UINT): string;

function PadRight(const S: string; N: Integer): string;

function Trim(S: string): string;

function SameText(const S1, S2: string): Boolean;

function StringToAnsi(const S: string; const CodePage: UINT): AnsiString;

function DWORDToStr(const N: DWORD): string;

function TestVersionString(const S: string): Boolean;

function CompareVersionStrings(V1, V2: string): LongInt;

implementation

type
  TVersionArray = array[0..3] of Word;

function AnsiToString(const S: AnsiString; const CodePage: UINT): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := MultiByteToWideChar(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PAnsiChar(S),                            // LPCCH  lpMultiByteStr
    -1,                                      // int    cbMultiByte
    nil,                                     // LPWSTR lpWideCharStr
    0);                                      // int    cchWideChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(Char);
    GetMem(pBuffer, BufSize);
    if MultiByteToWideChar(CodePage,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PAnsiChar(S),                   // LPCCH  lpMultiByteStr
      -1,                             // int    cbMultiByte
      pBuffer,                        // LPWSTR lpWideCharStr
      NumChars) > 0 then              // int    cchWideChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
  end;
end;

function StringOfChar(const C: AnsiChar; const N: Integer): string;
var
  S: AnsiString;
begin
  SetLength(S, N);
  FillChar(Pointer(@S[1])^, N * SizeOf(AnsiChar), C);
  result := AnsiToString(S, CP_ACP);
end;

function PadRight(const S: string; N: Integer): string;
var
  L: Integer;
begin
  result := S;
  L := Length(result);
  if L < N then
    result := result + StringOfChar(' ', N - L);
end;

function Trim(S: string): string;
var
  I, J: LongInt;
begin
  I := Length(S);
  if I > 0 then
  begin
    J := I;
    while (J > 0) and (S[J] = ' ') do
      Dec(J);
    if J <> I Then
      SetLength(S, J);
  end;
  result := S;
end;

function SameText(const S1, S2: string): Boolean;
const
  CSTR_EQUAL = 2;
begin
  result := CompareStringW(GetThreadLocale(),  // LCID    Locale
    LINGUISTIC_IGNORECASE,                     // DWORD   dwCmpFlags
    PChar(S1),                                 // PCNZWCH lpString1
    -1,                                        // int     cchCount1
    PChar(S2),                                 // PCNZWCH lpString2
    -1) = CSTR_EQUAL;                          // int     cchCount2
end;

function StringToAnsi(const S: string; const CodePage: UINT): AnsiString;
var
  NumChars, BufSize: DWORD;
  pBuffer: PAnsiChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := WideCharToMultiByte(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PChar(S),                                // LPCWCH lpWideCharStr
    -1,                                      // int    cchWideChar
    nil,                                     // LPSTR  lpMultiByteStr
    0,                                       // int    cbMultiByte
    nil,                                     // LPCCH  lpDefaultChar
    nil);                                    // LPBOOL lpUsedDefaultChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(AnsiChar);
    GetMem(pBuffer, BufSize);
    if WideCharToMultiByte(CodePage,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PChar(S),                       // LPCWCH lpWideCharStr
      -1,                             // int    cchWideChar
      pBuffer,                        // LPSTR  lpMultiByteStr
      NumChars,                       // int    cbMultiByte
      nil,                            // LPCCH  lpDefaultChar
      nil) > 0 then                   // LPBOOL lpUsedDefaultChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
  end;
end;

// Returns the number of times Substring appears in S
function CountSubstring(const Substring, S: string): LongInt;
var
  P: LongInt;
begin
  result := 0;
  P := Pos(Substring, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := Pos(Substring, S, P + Length(Substring));
  end;
end;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: string; var Dest: TArrayOfString);
var
  I, P: LongInt;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit;
  end;
  SetLength(Dest, I + 1);
  for I := 0 to Length(Dest) - 1 do
  begin
    P := Pos(Delim, S);
    if P > 0 then
    begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
    end
    else
      Dest[I] := S;
  end;
end;

function DWORDToStr(const N: DWORD): string;
begin
  Str(N, result);
end;

function StrToInt(const S: string; var I: LongInt): Boolean;
var
  Code: Word;
begin
  Val(S, I, Code);
  result := Code = 0;
end;

function StrToWord(const S: string; var W: Word): Boolean;
var
  Code: Word;
begin
  Val(S, W, Code);
  result := Code = 0;
end;

function GetVersionArray(const S: string; var Version: TVersionArray): Boolean;
var
  A: TArrayOfString;
  ALen, I, Part: LongInt;
begin
  result := false;
  StrSplit(S, '.', A);
  ALen := Length(A);
  if ALen > 4 then
    exit;
  if ALen < 4 then
  begin
    SetLength(A, 4);
    for I := ALen to 3 do
      A[I] := '0';
  end;
  for I := 0 to Length(A) - 1 do
  begin
    result := StrToInt(A[I], Part);
    if not result then
      exit;
    result := (Part >= 0) and (Part <= $FFFF);
    if not result then
      exit;
  end;
  for I := 0 to 3 do
  begin
    result := StrToWord(A[I], Version[I]);
    if not result then
      exit;
  end;
end;

function TestVersionString(const S: string): Boolean;
var
  Version: TVersionArray;
begin
  result := GetVersionArray(S, Version);
end;

// Compares two version strings 'a[.b[.c[.d]]]'
// Returns:
// < 0  if V1 < V2
// 0    if V1 = V2
// > 0  if V1 > V2
function CompareVersionStrings(V1, V2: string): LongInt;
var
  Ver1, Ver2: TVersionArray;
  I: LongInt;
  Word1, Word2: Word;
begin
  result := 0;
  if not GetVersionArray(V1, Ver1) then
    exit;
  if not GetVersionArray(V2, Ver2) then
    exit;
  for I := 0 to 3 do
  begin
    Word1 := Ver1[I];
    Word2 := Ver2[I];
    if Word1 > Word2 then
    begin
      result := 1;
      exit;
    end
    else if Word1 < Word2 then
    begin
      result := -1;
      exit;
    end;
  end;
end;

begin
end.
