unit otYamlToken;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  otYaml;

type
  TYamlToken = class
  private
    FStartMark: TYamlMark;
    FEndMark: TYamlMark;

  public
    constructor Create(AStartMark, AEndMark: TYamlMark);

    property start_mark: TYamlMark Read FStartMark;
    property end_mark: TYamlMark Read FEndMark;
  end;

  TStreamStartToken = class(TYamlToken)
  private
    FEncoding: TYamlEncoding;

  public
    constructor Create(AEncoding: TYamlEncoding; AStartMark, AEndMark: TYamlMark);
    property encoding: TYamlEncoding Read FEncoding;
  end;

  { TStreamEndToken }

  TStreamEndToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TDocumentStartToken }

  TDocumentStartToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TDocumentEndToken }

  TDocumentEndToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  TVersionDirectiveToken = class(TYamlToken)
  private
    FMajor: Integer;
    FMinor: Integer;

  public
    constructor Create(AMajor, AMinor: Integer; AStartMark, AEndMark: TYamlMark);
    property major: Integer Read FMajor;
    property minor: Integer Read FMinor;

  end;

  TTagDirectiveToken = class(TYamlToken)
  private
    FHandle: String;
    FPrefix: String;

  public
    constructor Create(AHandle, APrefix: String; AStartMark, AEndMark: TYamlMark);
    property handle: String Read FHandle;
    property prefix: String Read FPrefix;

  end;

  TAliasToken = class(TYamlToken)
  private
    FValue: String;

  public
    constructor Create(AValue: String; AStartMark, AEndMark: TYamlMark);
    property Value: String Read FValue;
  end;

  TAnchorToken = class(TYamlToken)
  private
    FValue: String;

  public
    constructor Create(AValue: String; AStartMark, AEndMark: TYamlMark);
    property Value: String Read FValue;
  end;

  TTagToken = class(TYamlToken)
  private
    FHandle: String;
    FSuffix: String;

  public
    constructor Create(AHandle: String; ASuffix: String; AStartMark, AEndMark: TYamlMark);
    property handle: String Read FHandle;
    property suffix: String Read FSuffix;
  end;

  { TBlockEntryToken }

  TBlockEntryToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  TBlockEndToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  TScalarToken = class(TYamlToken)
  private
    FValue: String;
    FScalarStyle: TYamlScalarStyle;

  public
    constructor Create(AValue: String; AStyle: TYamlScalarStyle; AStartMark, AEndMark: TYamlMark);
    property Value: String Read FValue;
    property scalar_style: TYamlScalarStyle Read FScalarStyle;
  end;

  { TFlowSequenceStartToken }

  TFlowSequenceStartToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TFlowSequenceEndToken }

  TFlowSequenceEndToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TFlowMappingStartToken }

  TFlowMappingStartToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TFlowMappingEndToken }

  TFlowMappingEndToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TFlowEntryToken }

  TFlowEntryToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TBlockSequenceStartToken }

  TBlockSequenceStartToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TBlockMappingStartToken }

  TBlockMappingStartToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TKeyToken }

  TKeyToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TValueToken }

  TValueToken = class(TYamlToken)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

implementation

{ TValueToken }

constructor TValueToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TKeyToken }

constructor TKeyToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TBlockEntryToken }

constructor TBlockEntryToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TFlowEntryToken }

constructor TFlowEntryToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TFlowMappingEndToken }

constructor TFlowMappingEndToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TFlowMappingStartToken }

constructor TFlowMappingStartToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TFlowSequenceEndToken }

constructor TFlowSequenceEndToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TFlowSequenceStartToken }

constructor TFlowSequenceStartToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TDocumentEndToken }

constructor TDocumentEndToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TDocumentStartToken }

constructor TDocumentStartToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TStreamEndToken }

constructor TStreamEndToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TBlockMappingStartToken }

constructor TBlockMappingStartToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

{ TBlockSequenceStartToken }

constructor TBlockSequenceStartToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

constructor TYamlToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create;

  FStartMark := AStartMark;
  FEndMark := AEndMark;
end;

constructor TStreamStartToken.Create(AEncoding: TYamlEncoding; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FEncoding := AEncoding;
end;

constructor TVersionDirectiveToken.Create(AMajor, AMinor: Integer;
  AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FMajor := AMajor;
  FMinor := AMinor;
end;

constructor TTagDirectiveToken.Create(AHandle, APrefix: String; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FHandle := AHandle;
  FPrefix := APrefix;
end;

constructor TBlockEndToken.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
end;

constructor TAnchorToken.Create(AValue: String; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FValue := AValue;
end;

constructor TAliasToken.Create(AValue: String; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FValue := AValue;
end;

constructor TTagToken.Create(AHandle: String; ASuffix: String; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FHandle := AHandle;
  FSuffix := ASuffix;
end;

constructor TScalarToken.Create(AValue: String; AStyle: TYamlScalarStyle;
  AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(AStartMark, AEndMark);
  FValue := AValue;
  FScalarStyle := AStyle;
end;

end.
