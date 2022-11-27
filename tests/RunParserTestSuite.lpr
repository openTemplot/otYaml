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

program RunParserTestSuite;

{$mode delphi}{$H+}

uses
 {$IFDEF UNIX}
  cthreads,
 {$ENDIF}
  Classes,
  otYaml,
  otYamlParser,
  otYamlEvent
 ;

  procedure Usage(AReturnCode: Integer);
  begin
    Halt(AReturnCode);
  end;

  procedure PrintEscaped(AString: String);
  var
    i: Integer;
    c: Char;
  begin
    for i := 1 to Length(AString) do begin
      c := AString[i];
      if (c = '\') then
        Write('\\')
      else
      if (c = #$00) then
        Write('\0')
      else
      if (c = #$08) then
        Write('\b')
      else
      if (c = #$0A) then
        Write('\n')
      else
      if (c = #$0D) then
        Write('\r')
      else
      if (c = #$09) then
        Write('\t')
      else
        Write(c);
    end;
  end;

var
  i: Integer;
  flow: Integer;
  input: TStream;
  parser: TYamlParser;
  foundFile: Boolean;
  ev: TYamlEvent;
begin
  foundFile := False;
  flow := 0;
  i := 1;
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
    if (argv[i] = '--help') or (argv[i] = '-h') then begin
      Usage(0);
    end
    else
    if not foundFile then begin
      input := TFileStream.Create(argv[i], fmOpenRead);
      foundFile := True;
    end
    else
      Usage(1);

    Inc(i);
  end;

  if not foundFile then begin
    Usage(1);
  end;

  parser := TYamlParser.Create;
  try
    parser.SetInput(input);

    while True do begin
      try
        try
          ev := parser.parse;
        except
          on e: EYamlParserError do begin
            WriteLn('Parse error: ', e.Message);
            Halt(1);
          end;
          on e: EYamlParserErrorContext do begin
            WriteLn('Parse error: ', e.Message);
            WriteLn('  Line: ', e.problemMark.Line, '   Column: ', e.problemMark.Column);
            Halt(1);
          end;
        end;

        if (ev is TStreamStartEvent) then begin
          WriteLn('+STR');
        end
        else
        if (ev is TStreamEndEvent) then begin
          WriteLn('-STR');
          Break;
        end
        else
        if (ev is TDocumentStartEvent) then begin
          Write('+DOC');
          if (not TDocumentStartEvent(ev).implicit) then
            Write(' ---');
          WriteLn;
        end
        else
        if (ev is TDocumentEndEvent) then begin
          Write('-DOC');
          if (not TDocumentEndEvent(ev).implicit) then
            Write(' ...');
          WriteLn;
        end
        else
        if (ev is TMappingStartEvent) then begin
          Write('+MAP');
          if (flow = 0) and (TMappingStartEvent(ev).mappingStyle = ympFlowMapping) then
            Write(' {}')
          else
          if (flow = 1) then
            Write(' {}');
          if (TMappingStartEvent(ev).anchor <> '') then
            Write(' &', TMappingStartEvent(ev).anchor);
          if (TMappingStartEvent(ev).tag <> '') then
            Write(' <', TMappingStartEvent(ev).tag, '>');
          WriteLn;
        end
        else
        if (ev is TMappingEndEvent) then
          WriteLn('-MAP')
        else
        if (ev is TSequenceStartEvent) then begin
          Write('+SEQ');
          if (flow = 0) and (TSequenceStartEvent(ev).sequenceStyle =
            ysqFlowSequence) then
            Write(' []')
          else
          if (flow = 1) then
            Write(' []');
          if (TSequenceStartEvent(ev).anchor <> '') then
            Write(' &', TSequenceStartEvent(ev).anchor);
          if (TSequenceStartEvent(ev).tag <> '') then
            Write(' <', TSequenceStartEvent(ev).tag, '>');
          WriteLn;
        end
        else
        if (ev is TSequenceEndEvent) then
          WriteLn('-SEQ')
        else
        if (ev is TScalarEvent) then begin
          Write('=VAL');
          if (TScalarEvent(ev).anchor <> '') then
            Write(' &', TScalarEvent(ev).anchor);
          if (TScalarEvent(ev).tag <> '') then
            Write(' <', TScalarEvent(ev).tag, '>');
          case TScalarEvent(ev).scalarStyle of
            yssPlainScalar:
              Write(' :');

            yssSingleQuotedScalar:
              Write(' ''');

            yssDoubleQuotedScalar:
              Write(' "');

            yssLiteralScalar:
              Write(' |');

            yssFoldedScalar:
              Write(' >');

            yssAnyStyle:
              Halt(1);
          end;
          PrintEscaped(TScalarEvent(ev).Value);
          WriteLn;
        end
        else
        if (ev is TAliasEvent) then
          WriteLn('=ALI *', TAliasEvent(ev).anchor)
        else
          Halt(1);


      finally
        ev.Free;
        ev := nil;
      end;
    end;
  finally
    parser.Free;
  end;

  Halt(0);
end.
