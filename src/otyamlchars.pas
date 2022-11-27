unit otYamlChars;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils;

function IsAsciiAt(const AString: String; APos: Integer): Boolean;
function IsAlphaAt(const AString: String; APos: Integer): Boolean;
function IsZAt(const AString: String; APos: Integer): Boolean;
function IsCrlfAt(const AString: String; APos: Integer): Boolean;
function IsBreakAt(const AString: String; APos: Integer): Boolean;
function IsBreakZAt(const AString: String; APos: Integer): Boolean;
function IsSpaceAt(const AString: String; APos: Integer): Boolean;
function IsTabAt(const AString: String; APos: Integer): Boolean;
function IsBlankAt(const AString: String; APos: Integer): Boolean;
function IsBlankZAt(const AString: String; APos: Integer): Boolean;
function IsPrintableAt(const AString: String; APos: Integer): Boolean;
function IsBOMAt(const AString: String; APos: Integer): Boolean;
function IsDigitAt(const AString: String; APos: Integer): Boolean;
function IsHexAt(const AString: String; APos: Integer): Boolean;

function AsDigitAt(const AString: String; APos: Integer): Integer;
function AsHexAt(const AString: String; APos: Integer): Integer;

function WidthOctet(AOctet: Byte): Integer;
function WidthAt(const AString: String; APos: Integer): Integer;
function CodepointAt(const AString: String; APos: Integer): UInt32;


implementation

function IsAsciiAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] <= #$7F);
end;

function IsAlphaAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] in ['A'..'Z', 'a'..'z', '0'..'9']);
end;

function IsZAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$00);
end;

function IsCrlfAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$0D) and (AString[APos] = #$0A);
end;

function IsBreakAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$0D) // CR
    or (AString[APos] = #$0A)      // LF
    or ((AString[APos] = #$C2) and (AString[APos + 1] = #$85))  // NEL U+85
    or ((AString[APos] = #$E2) and (AString[APos + 1] = #$80) and
    (AString[APos + 2] = #$A8))  // LSEP U+2028
    or ((AString[APos] = #$E2) and (AString[APos + 1] = #$80) and (AString[APos + 2] = #$A9));
  // PSEP U+2029
end;

function IsBreakZAt(const AString: String; APos: Integer): Boolean;
begin
  Result := IsBreakAt(AString, APos) or IsZAt(AString, APos);
end;

function IsSpaceAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = ' ');
end;

function IsTabAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$09);
end;

function IsBlankAt(const AString: String; APos: Integer): Boolean;
begin
  Result := IsSpaceAt(AString, APos) or IsTabAt(AString, APos);
end;

function IsBlankZAt(const AString: String; APos: Integer): Boolean;
begin
  Result := IsBlankAt(AString, APos) or IsBreakZAt(AString, APos);
end;

function IsPrintableAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$0A)
    or ((AString[APos] >= #$20) and (AString[APos] <= #$7E))
    or ((AString[APos] = #$C2) and (AString[APos + 1] >= #$A0))
    or ((AString[APos] > #$C2) and (AString[APos] < #$ED))
    or ((AString[APos] = #$ED) and (AString[APos + 1] < #$A0))
    or (AString[APos] = #$EE)
    or ((AString[APos] = #$EF)
    and not ((AString[APos + 1] = #$BB) and (AString[APos + 2] = #$BF))
    and not ((AString[APos + 1] = #$BF) and ((AString[APos + 2] = #$BE) or
    (AString[APos + 2] = #$BF))));
end;

function IsBOMAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] = #$EF) and (AString[APos + 1] = #$BB) and (AString[APos + 2] = #$BF);
end;

function IsDigitAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] in ['0'..'9']);
end;

function IsHexAt(const AString: String; APos: Integer): Boolean;
begin
  Result := (AString[APos] in ['0'..'9', 'a'..'f', 'A'..'F']);
end;

function AsDigitAt(const AString: String; APos: Integer): Integer;
begin
  Result := Ord(AString[APos]) - Ord('0');
end;

function AsHexAt(const AString: String; APos: Integer): Integer;
var
  ch: Char;
begin
  ch := AString[APos];
  if (ch in ['0'..'9']) then
    Result := Ord(ch) - Ord('0')
  else
  if (ch in ['a'..'f']) then
    Result := Ord(ch) - Ord('a') + 10
  else
  if (ch in ['A'..'F']) then
    Result := Ord(ch) - Ord('A') + 10
  else
    raise Exception.Create(Format('invalid hex character "%c"', [ch]));

end;

function WidthOctet(AOctet: Byte): Integer;
begin
  if (AOctet and $80) = 0 then
    Result := 1
  else
  if (AOctet and $E0) = $C0 then
    Result := 2
  else
  if (AOctet and $F0) = $E0 then
    Result := 3
  else
  if (AOctet and $F8) = $F0 then
    Result := 4
  else
    Result := 0;
end;

function WidthAt(const AString: String; APos: Integer): Integer;
var
  octet: Byte;
begin
  octet := Ord(AString[APos]);
  Result := WidthOctet(octet);
end;

function CodepointAt(const AString: String; APos: Integer): UInt32;
var
  octet: Byte;
  Width: Integer;
  i: Integer;
begin
  Width := WidthAt(AString, APos);
  octet := Ord(AString[APos]);

  if (Width = 1) then
    Result := octet and $7F
  else
  if (Width = 2) then
    Result := octet and $1F
  else
  if (Width = 3) then
    Result := octet and $0F
  else
  if (Width = 4) then
    Result := octet and $07
  else begin
    Exit(0);
  end;

  for i := 1 to Width - 1 do begin
    Result := (Result shl 6) + (Ord(AString[APos + i]) and $3F);
  end;
end;

end.
