unit otYamlReader;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  otYaml;

type

  EYamlReaderError = class(Exception)
  private
    FOffset: Int64;

  public
    constructor Create(const AProblem: String; AOffset: Int64);
  end;

  { TYamlReader }

  TYamlReader = class
  private
    FInput: TStream;

    FOffset: Int64;
    FBuffer: String;
    FEncoding: TYamlEncoding;
    FMark: TYamlMark;

    procedure SetReaderError(const AProblem: String; AOffset: Int64);

    procedure UpdateBuffer(ALength: Integer);
    procedure DetermineEncoding;

  public

    constructor Create;
    destructor Destroy; override;

    procedure SetInput(AInput: TStream);
    procedure SetEncoding(AEncoding: TYamlEncoding);

    procedure Cache(ALength: Integer);
    procedure Skip;
    procedure SkipLine;
    function Read: String;
    function ReadLine: String;

    procedure ForceNewLine;

    property buffer: String Read FBuffer;
    property encoding: TYamlEncoding Read FEncoding;
    property mark: TYamlMark Read FMark;

  end;

implementation

uses
  otYamlChars;

constructor EYamlReaderError.Create(const AProblem: String; AOffset: Int64);
begin
  inherited Create(AProblem);
  FOffset := AOffset;
end;

{ TYamlReader }

constructor TYamlReader.Create;
begin
  inherited Create;

end;

destructor TYamlReader.Destroy;
begin
  FInput.Free;

  inherited Destroy;
end;

procedure TYamlReader.SetReaderError(const AProblem: String; AOffset: Int64);
begin
  raise EYamlReaderError.Create(AProblem, AOffset);
end;


procedure TYamlReader.SetInput(AInput: TStream);
begin
  FInput := AInput;
end;

procedure TYamlReader.SetEncoding(AEncoding: TYamlEncoding);
begin
  FEncoding := AEncoding;
end;

procedure TYamlReader.Cache(ALength: Integer);
begin
  if Length(FBuffer) >= ALength then
    Exit;

  UpdateBuffer(ALength);
end;

procedure TYamlReader.Skip;
var
  Width: Integer;
begin
  Width := WidthAt(FBuffer, 1);
  FBuffer := Copy(FBuffer, 1 + Width, Length(FBuffer) - Width);
  Inc(FMark.Index);
  Inc(FMark.Column);
end;

procedure TYamlReader.SkipLine;
var
  Width: Integer;
begin
  if IsCrlfAt(FBuffer, 1) then begin
    Inc(FMark.Index, 2);
    FMark.Column := 0;
    Inc(FMark.Line);
    FBuffer := Copy(FBuffer, 3, Length(FBuffer) - 2);
  end
  else
  if IsBreakAt(FBuffer, 1) then begin
    Width := WidthAt(FBuffer, 1);
    Inc(FMark.Index, 1);
    FMark.Column := 0;
    Inc(FMark.Line);
    FBuffer := Copy(FBuffer, 1 + Width, Length(FBuffer) - Width);
  end;
end;

function TYamlReader.Read: String;
var
  Width: Integer;
begin
  Width := WidthAt(FBuffer, 1);
  Result := Copy(FBuffer, 1, Width);
  FBuffer := Copy(FBuffer, 1 + Width, Length(FBuffer) - Width);
  Inc(FMark.Index);
  Inc(FMark.Column);
end;

function TYamlReader.ReadLine: String;
begin
  if (FBuffer[1] = #$0D) and (FBuffer[2] = #$0A) then begin
    // CR LF -> LF
    Result := #$0A;
    FBuffer := Copy(FBuffer, 3, Length(FBuffer) - 2);
    Inc(FMark.Index, 2);
    Inc(FMark.Line);
    FMark.Column := 0;
  end
  else
  if (FBuffer[1] = #$0D) or (FBuffer[1] = #$0A) then begin
    // CR|LF -> LF
    Result := #$0A;
    FBuffer := Copy(FBuffer, 2, Length(FBuffer) - 1);
    Inc(FMark.Index);
    Inc(FMark.Line);
    FMark.Column := 0;
  end
  else
  if (FBuffer[1] = #$C2) and (FBuffer[2] = #$85) then begin
    // NEL -> LF
    Result := #$0A;
    FBuffer := Copy(FBuffer, 3, Length(FBuffer) - 2);
    Inc(FMark.Index);
    Inc(FMark.Line);
    FMark.Column := 0;
  end
  else
  if (FBuffer[1] = #$E2) and (FBuffer[2] = #$80) and (FBuffer[3] in [#$A8, #$A9]) then begin
    // LS|PS -> LS|PS
    Result := Copy(FBuffer, 1, 3);
    FBuffer := Copy(FBuffer, 4, Length(FBuffer) - 3);
    Inc(FMark.Index);
    Inc(FMark.Line);
    FMark.Column := 0;
  end;
end;

procedure TYamlReader.ForceNewLine;
begin
  if (FMark.Column <> 0) then begin
    FMark.Column := 0;
    Inc(FMark.Line);
  end;
end;

procedure TYamlReader.DetermineEncoding;
const
  BOM_UTF8: String = #$ef#$bb#$bf;
  BOM_UTF16LE: String = #$ff#$fe;
  BOM_UTF16BE: String = #$fe#$ff;
var
  buff: String;
  bytesRead: Integer;
begin
  if FInput.Position <> 0 then begin
    SetReaderError('Input Stream not at start', FInput.Position);
  end;

  //* Ensure that we had enough bytes in the raw buffer. */
  SetLength(buff, 3);
  bytesRead := FInput.Read(buff[1], 3);
  if (bytesRead < 3) then begin
    SetLength(buff, bytesRead);
  end;

  //* Determine the encoding. */
  if (bytesRead >= 2) and (Copy(buff, 1, 2) = BOM_UTF16LE) then begin
    FEncoding := yencUTF16LE;
    FInput.Seek(2, soBeginning);
  end
  else
  if (bytesRead >= 2) and (Copy(buff, 1, 2) = BOM_UTF16BE) then begin
    FEncoding := yencUTF16BE;
    FInput.Seek(2, soBeginning);
  end
  else
  if (bytesRead = 3) and (Copy(buff, 1, 3) = BOM_UTF8) then begin
    FEncoding := yencUTF8;
    FInput.Seek(3, soBeginning);
  end
  else begin
    FEncoding := yencUTF8;
    FInput.Seek(0, soBeginning);
  end;
end;

procedure TYamlReader.UpdateBuffer(ALength: Integer);
const
  MAX_FILE_SIZE = 2000000000;
var
  octet: Byte;
  bytesRead: Integer;
  Value: UInt32;
  value2: UInt32;
  incomplete: Boolean;
  Width: Integer;
  k: Integer;
  buff: array of Byte;
begin
  Assert(Assigned(FInput)); //* Input stream must be set. */

  //* If the EOF flag is set and the raw buffer is empty, do nothing. */
  if (FInput.Position >= FInput.Size) then
    Exit;

  //* Return if the buffer contains enough characters. */
  if (Length(FBuffer) >= ALength) then
    Exit;

  //* Determine the input encoding if it is not known yet. */
  if (FEncoding = yencAnyEncoding) then begin
    DetermineEncoding;
  end;

  //* Fill the buffer until it has enough characters. */
  while (Length(FBuffer) < ALength) do begin
    //* Decode the raw buffer. */
    bytesRead := FInput.Read(octet, 1);
    while (bytesRead = 1) do begin
      Value := 0;
      value2 := 0;
      incomplete := False;
      Width := 0;

      //* Decode the next character. */
      case FEncoding of
        yencUTF8: begin

          ///*
          // * Decode a UTF-8 character.  Check RFC 3629
          // * (http://www.ietf.org/rfc/rfc3629.txt) for more details.
          // *
          // * The following table (taken from the RFC) is used for
          // * decoding.
          // *
          // *    Char. number range |        UTF-8 octet sequence
          // *      (hexadecimal)    |              (binary)
          // *   --------------------+------------------------------------
          // *   0000 0000-0000 007F | 0xxxxxxx
          // *   0000 0080-0000 07FF | 110xxxxx 10xxxxxx
          // *   0000 0800-0000 FFFF | 1110xxxx 10xxxxxx 10xxxxxx
          // *   0001 0000-0010 FFFF | 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
          // *
          // * Additionally, the characters in the range 0xD800-0xDFFF
          // * are prohibited as they are reserved for use with UTF-16
          // * surrogate pairs.
          // */

          ///* Determine the length of the UTF-8 sequence. */

          Width := WidthOctet(octet);

          ///* Check if the leading octet is valid. */

          if Width = 0 then begin
            SetReaderError('invalid leading UTF-8 octet',
              FOffset);
          end;

          //* Check if the raw buffer contains an incomplete character. */

          if (Width > 1) then begin
            if (FInput.Position >= FInput.Size) then begin
              SetReaderError(
                'incomplete UTF-8 octet sequence',
                FOffset);
            end;
            incomplete := True;
            break;
          end;

          SetLength(buff, Width);
          buff[0] := octet;
          bytesRead := FInput.Read(buff[1], Width - 1);

          if (bytesRead < Width - 1) then begin
            SetReaderError('incomplete UTF-8 octet sequence', FOffset);
          end;


          //* Decode the leading octet. */

          if (octet and $80) = 0 then
            Value := octet and $7f
          else
          if (octet and $e0) = $c0 then
            Value := octet and $1f
          else
          if (octet and $f0) = $e0 then
            Value := octet and $0f
          else
          if (octet and $f8) = $f0 then
            Value := octet and $07
          else
            Value := 0;

          //* Check and decode the trailing octets. */

          for k := 1 to Width - 1 do begin
            octet := buff[k];

            //* Check if the octet is valid. */

            if ((octet and $c0) <> $80) then begin
              SetReaderError(
                'invalid trailing UTF-8 octet',
                FOffset + k);
            end;

            //* Decode the octet. */

            Value := (Value shl 6) + (octet and $3f);
          end;

          //* Check the length of the sequence against the value. */

          if not ((Width = 1) or
            ((Width = 2) and (Value >= $80)) or
            ((Width = 3) and (Value >= $800)) or
            ((Width = 4) and (Value >= $10000))) then  begin
            SetReaderError(
              'invalid length of a UTF-8 sequence',
              FOffset);
          end;

          //* Check the range of the value. */

          if ((Value >= $D800) and (Value <= $DFFF)) or (Value > $10FFFF) then begin
            SetReaderError(
              'invalid Unicode character',
              FOffset);

          end;
              (*

              case YAML_UTF16LE_ENCODING:
              case YAML_UTF16BE_ENCODING:

                  low = (parser->encoding == YAML_UTF16LE_ENCODING ? 0 : 1);
                  high = (parser->encoding == YAML_UTF16LE_ENCODING ? 1 : 0);

                  /*
                   * The UTF-16 encoding is not as simple as one might
                   * naively think.  Check RFC 2781
                   * (http://www.ietf.org/rfc/rfc2781.txt).
                   *
                   * Normally, two subsequent bytes describe a Unicode
                   * character.  However a special technique (called a
                   * surrogate pair) is used for specifying character
                   * values larger than 0xFFFF.
                   *
                   * A surrogate pair consists of two pseudo-characters:
                   *      high surrogate area (0xD800-0xDBFF)
                   *      low surrogate area (0xDC00-0xDFFF)
                   *
                   * The following formulas are used for decoding
                   * and encoding characters using surrogate pairs:
                   *
                   *  U  = U' + 0x10000   (0x01 00 00 <= U <= 0x10 FF FF)
                   *  U' = yyyyyyyyyyxxxxxxxxxx   (0 <= U' <= 0x0F FF FF)
                   *  W1 = 110110yyyyyyyyyy
                   *  W2 = 110111xxxxxxxxxx
                   *
                   * where U is the character value, W1 is the high surrogate
                   * area, W2 is the low surrogate area.
                   */

                  /* Check for incomplete UTF-16 character. */

                  if (raw_unread < 2) {
                      if (parser->eof) {
                          return yaml_parser_set_reader_error(parser,
                                  "incomplete UTF-16 character",
                                  parser->offset, -1);
                      }
                      incomplete = 1;
                      break;
                  }

                  /* Get the character. */

                  value = parser->raw_buffer.pointer[low]
                      + (parser->raw_buffer.pointer[high] << 8);

                  /* Check for unexpected low surrogate area. */

                  if ((value & 0xFC00) == 0xDC00)
                      return yaml_parser_set_reader_error(parser,
                              "unexpected low surrogate area",
                              parser->offset, value);

                  /* Check for a high surrogate area. */

                  if ((value & 0xFC00) == 0xD800) {

                      width = 4;

                      /* Check for incomplete surrogate pair. */

                      if (raw_unread < 4) {
                          if (parser->eof) {
                              return yaml_parser_set_reader_error(parser,
                                      "incomplete UTF-16 surrogate pair",
                                      parser->offset, -1);
                          }
                          incomplete = 1;
                          break;
                      }

                      /* Get the next character. */

                      value2 = parser->raw_buffer.pointer[low+2]
                          + (parser->raw_buffer.pointer[high+2] << 8);

                      /* Check for a low surrogate area. */

                      if ((value2 & 0xFC00) != 0xDC00)
                          return yaml_parser_set_reader_error(parser,
                                  "expected low surrogate area",
                                  parser->offset+2, value2);

                      /* Generate the value of the surrogate pair. */

                      value = 0x10000 + ((value & 0x3FF) << 10) + (value2 & 0x3FF);
                  }

                  else {
                      width = 2;
                  }

                  break;
               *)

        end;
        else
          Assert(False);      //* Impossible. */
      end;

      //* Check if the raw buffer contains enough bytes to form a character. */

      if (incomplete) then
        Break;

      ///*
      // * Check if the character is in the allowed range:
      // *      #x9 | #xA | #xD | [#x20-#x7E]               (8 bit)
      // *      | #x85 | [#xA0-#xD7FF] | [#xE000-#xFFFD]    (16 bit)
      // *      | [#x10000-#x10FFFF]                        (32 bit)
      // */

      if not ((Value = $09) or (Value = $0A) or (Value = $0D)
        or ((Value >= $20) and (Value <= $7E))
        or ((Value = $85) or ((Value >= $A0) and (Value <= $D7FF))
        or ((Value >= $E000) and (Value <= $FFFD))
        or ((Value >= $10000) and (Value <= $10FFFF)))) then begin
        SetReaderError(
          'control characters are not allowed',
          FOffset);
      end;

      Inc(FOffset, Width);

      //* Finally put the character into the buffer. */

      //* 0000 0000-0000 007F -> 0xxxxxxx */
      if (Value <= $7F) then begin
        FBuffer := FBuffer + Char(Value);
      end
      //* 0000 0080-0000 07FF -> 110xxxxx 10xxxxxx */
      else
      if (Value <= $7FF) then begin
        FBuffer := FBuffer + Char($C0 + (Value shr 6)) + Char($80 + (Value and $3f));
      end
      //* 0000 0800-0000 FFFF -> 1110xxxx 10xxxxxx 10xxxxxx */
      else
      if (Value <= $FFFF) then begin
        FBuffer := FBuffer + Char($E0 + (Value shr 12)) +
          Char($80 + ((Value shr 6) and $3f)) + Char($80 + (Value and $ef));
      end
      //* 0001 0000-0010 FFFF -> 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx */
      else begin
        FBuffer := FBuffer + Char($F0 + (Value shr 18)) +
          Char($80 + ((Value shr 12) and $3f)) + Char($80 + ((Value shr 6) and $3F)) +
          Char($80 + (Value and $3F));
      end;
    end;

    //* On EOF, put NUL into the buffer and return. */

    if (FInput.Position >= FInput.Size) then begin
      FBuffer := FBuffer + #$00;
      Exit;
    end;
  end;

  if (FOffset >= MAX_FILE_SIZE) then begin
    SetReaderError('input is too long',
      FOffset);
  end;

end;

end.
