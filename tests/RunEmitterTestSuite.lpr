(*
This file is part of otYaml, a port of LibYAML and Neslib.Yaml
to FreePascal/Lazarus

Copyright (C) 2022 OpenTemplot project contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



Original LibYAML Copyright:
---------------------------
Copyright (c) 2017-2020 Ingy döt Net
Copyright (c) 2006-2016 Kirill Simonov

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Original Newlib.Yaml License and Copyright:
-------------------------------------------
Copyright (c) 2019 by Erik van Bilsen
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*)

program RunEmitterTestSuite;

uses
  Classes,
  Streamex,
  otYaml,
  otYamlEmitter;


  procedure Usage(AReturnCode: Integer);
  begin
    Halt(AReturnCode);
  end;

  function GetAnchor(ASigil: char; const ALine: String): String;
  var
    startPos: Integer;
    endPos: Integer;
  begin
    // anchor will always be the first entry in the ALine
    startPos := Pos(' ' + ASigil, ALine);
    if (startPos <> 5) then
      Exit('');

    Inc(startPos, 2);
    endPos := Pos(' ', ALine, startPos);
    if (endPos = 0) then
      endPos := Length(ALine) + 1;

    Result := Copy(ALine, startPos, endPos - startPos);
  end;

  function GetTag(const ALine: String): String;
  var
    startPos: Integer;
    endPos: Integer;
  begin
    startPos := Pos(' <', ALine);
    if startPos = 0 then
      Exit('');
    Inc(startPos, 2);

    endPos := Pos('>', ALine);
    if endPos = 0 then
      Exit('');
    Result := Copy(ALine, startPos, endPos - startPos);
  end;


  function GetValue(const ALine: String; out AStyle: TYamlScalarStyle): String;
  var
    ci: Integer;
    startPos: Integer;
    skipEscape: Boolean;
  begin
    startPos := 0;
    for ci := 5 to Length(ALine) do begin
      if (ALine[ci] = ' ') then begin
        startPos := ci + 1;
        if (ALine[startPos] = ':') then
          AStyle := yssPlainScalar
        else
        if (ALine[startPos] = '''') then
          AStyle := yssSingleQuotedScalar
        else
        if (ALine[startPos] = '"') then
          AStyle := yssDoubleQuotedScalar
        else
        if (ALine[startPos] = '|') then
          AStyle := yssLiteralScalar
        else
        if (ALine[startPos] = '>') then
          AStyle := yssFoldedScalar
        else begin
          startPos := 0;
          Continue;
        end;
        Inc(startPos);
        Break;
      end;
    end;
    if (startPos = 0) then
      Halt(1);

    Result := '';
    skipEscape := False;
    for ci := startPos to Length(ALine) do begin
      if skipEscape then begin
        skipEscape := False;
        Continue;
      end;

      if (ALine[ci] = '\') then begin
        skipEscape := True;
        case ALine[ci + 1] of
          '\':
            Result := Result + '\';
          '0':
            Result := Result + #0;
          'b':
            Result := Result + #08;
          'n':
            Result := Result + #$0A;
          'r':
            Result := Result + #$0D;
          't':
            Result := Result + #$09;
          else
            Halt(1);
        end;
      end
      else
        Result := Result + ALine[ci];
    end;
  end;


var
  i: Integer;
  minor: Integer;
  flow: Integer;
  input: TStreamReader;
  output: TStream;
  emitter: TYamlEmitter;
  line: String;
  tag: String;
  Value: String;
  implicit: Boolean;
  versionDirective: TYamlVersionDirective;
  mappingStyle: TYamlMappingStyle;
  sequenceStyle: TYamlSequenceStyle;
  scalarStyle: TYamlScalarStyle;
  canonical: Boolean;
begin
  flow := 0;
  i := 1;
  input := nil;
  output := nil;
  versionDirective.Initialize();
  canonical := False;

  while (i < argc) do begin
    if (argv[i] = '--flow') then begin
      if (i + 1 = argc) then
        Usage(1);
      Inc(i);
      if (argv[i] = 'keep') then
        flow := 0
      else
      if (argv[i] = 'on') then begin
        flow := 1;
      end
      else
      if (argv[i] = 'off') then begin
        flow := -1;
      end
      else
        Usage(1);
    end
    else
    if (argv[i] = '--directive') then begin
      if (i + 1 = argc) then
        Usage(1);
      Inc(i);
      if (argv[i] = '1.1') then begin
        minor := 1;
      end
      else
      if (argv[i] = '1.2') then begin
        minor := 2;
      end
      else
        Usage(1);
    end
    else
    if (argv[i] = '--help') or (argv[i] = '-h') then begin
      Usage(0);
    end
    else if (argv[i] = '-c') or (argv[i] = '--canonical') then begin
      canonical := true;
    end
    else
    if not Assigned(input) then begin
      input := TStreamReader.Create(TFileStream.Create(argv[i], fmOpenRead));
    end
    else
    if not Assigned(output) then begin
      output := TFileStream.Create(argv[i], fmCreate);
    end
    else
      Usage(1);

    Inc(i);
  end;

  if (minor > 0) then begin
    versionDirective.Major := 1;
    versionDirective.Minor := minor;
  end;

  if (not Assigned(input) or not Assigned(output)) then
    Usage(1);

  emitter := TYamlEmitter.Create;
  try
    emitter.SetOutput(output);
    emitter.SetCanonical(canonical);
    emitter.SetUnicode(False);


    while not input.EOF do begin
      line := input.ReadLine;

      if (Pos('+STR', line) = 1) then begin
        emitter.StreamStartEvent;
      end
      else
      if (Pos('-STR', line) = 1) then begin
        emitter.StreamEndEvent;
      end
      else
      if (Pos('+DOC', line) = 1) then begin
        implicit := (Pos(' ---', line) <> 5);
        emitter.DocumentStartEvent(versionDirective, nil, implicit);
      end
      else
      if (Pos('-DOC', line) = 1) then begin
        implicit := Pos(' ...', line) <> 5;
        emitter.DocumentEndEvent(implicit);
      end
      else
      if (Pos('+MAP', line) = 1) then begin
        mappingStyle := ympBlockMapping;
        if (flow = 1) then begin
          mappingStyle := ympFlowMapping;
        end
        else
        if (flow = 0) and (Pos(' {}', line) = 5) then begin
          mappingStyle := ympFlowMapping;
        end;
        emitter.MappingStartEvent(GetAnchor('&', line), GetTag(line), False, mappingStyle);
      end
      else
      if (Pos('-MAP', line) = 1) then begin
        emitter.MappingEndEvent;
      end
      else
      if (Pos('+SEQ', line) = 1) then begin
        sequenceStyle := ysqBlockSequence;
        if (flow = 1) then begin
          sequenceStyle := ysqFlowSequence;
        end
        else
        if (flow = 0) and (Pos(' []', line) = 5) then begin
          sequenceStyle := ysqFlowSequence;
        end;
        emitter.SequenceStartEvent(GetAnchor('&', line), GetTag(line), False, sequenceStyle);
      end
      else
      if (Pos('-SEQ', line) = 1) then begin
        emitter.SequenceEndEvent;
      end
      else
      if (Pos('=VAL', line) = 1) then begin
        tag := GetTag(line);
        Value := GetValue(line, scalarStyle);
        implicit := (tag = '');

        emitter.ScalarEvent(GetAnchor('&', line), tag, Value, implicit,
          implicit, scalarStyle);
      end
      else
      if (Pos('=ALI', line) = 1) then begin
        emitter.AliasEvent(GetAnchor('*', line));
      end
      else begin
        WriteLn('Unknown event: "', line, '"');
        Halt(1);
      end;
    end;


  finally
    emitter.Free;
  end;

end.
