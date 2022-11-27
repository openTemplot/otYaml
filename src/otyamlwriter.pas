unit otYamlWriter;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  otYaml;

type

  { TYamlWriter }

  TYamlWriter = class
  private
    FStream: TStream;
    FEncoding: TYamlEncoding;

    FLineBreak: TYamlBreak;
    FLine: Integer;
    FColumn: Integer;

    procedure InternalWrite(AString: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure SetEncoding(AEncoding: TYamlEncoding);
    procedure SetOutput(AStream: TStream);
    procedure SetBreak(ABreak: TYamlBreak);

    procedure Put(AValue: char);
    procedure PutBreak;

    procedure WriteAt(const AString: string; APos: Integer);
    procedure WriteBreakAt(const AString: string; APos: Integer);

    property line: Integer Read FLine;
    property column: Integer Read FColumn;
  end;

implementation

uses
  otYamlChars;

{ TYamlWriter }

procedure TYamlWriter.InternalWrite(AString: string);
begin
  if FEncoding = yencUTF8 then begin
    FStream.Write(AString[1], Length(AString));
  end
  else begin

  end;
end;

constructor TYamlWriter.Create;
begin
  inherited Create;

  FLine := 0;
  FColumn := 0;
end;

destructor TYamlWriter.Destroy;
begin
  inherited;
end;

procedure TYamlWriter.SetOutput(AStream: TStream);
begin
  FStream := AStream;
end;

procedure TYamlWriter.SetEncoding(AEncoding: TYamlEncoding);
begin
  FEncoding := AEncoding;
end;

procedure TYamlWriter.SetBreak(ABreak: TYamlBreak);
begin
  FLineBreak := ABreak;
end;

procedure TYamlWriter.Put(AValue: char);
var
  temp: string;
begin
  temp := AValue;
  InternalWrite(temp);
  Inc(FColumn);
end;

procedure TYamlWriter.PutBreak;
var
  temp: String;
begin
  if FLineBreak = ybrkCR then
    temp := #$0D
  else
  if FLineBreak = ybrkLN then
    temp := #$0A
  else
  if FLineBreak = ybrkCRLN then
    temp := #$0D + #$0A;
  InternalWrite(temp);
  FColumn := 0;
  Inc(FLine);
end;

procedure TYamlWriter.WriteAt(const AString: string; APos: Integer);
var
  temp: string;
begin
  temp := Copy(AString, APos, WidthAt(AString, APos));
  InternalWrite(temp);
  Inc(FColumn);
end;

procedure TYamlWriter.WriteBreakAt(const AString: string; APos: Integer);
var
  temp: string;
begin
  if (AString[APos] = #$0A) then begin
    PutBreak;
  end
  else begin
    temp := Copy(AString, APos, WidthAt(AString, APos));
    InternalWrite(temp);
    FColumn := 0;
    Inc(FLine);
  end;
end;

end.
