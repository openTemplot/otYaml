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
    constructor Create(startMark, endMark: TYamlMark);

    property start_mark: TYamlMark Read FStartMark;
    property end_mark: TYamlMark Read FEndMark;
  end;

  TStreamStartToken = class(TYamlToken)
  private
    FEncoding: TYamlEncoding;

  public
    constructor Create(AEncoding: TYamlEncoding; startMark, endMark: TYamlMark);
    property encoding: TYamlEncoding Read FEncoding;
  end;

  { TStreamEndToken }

  TStreamEndToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TDocumentStartToken }

  TDocumentStartToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TDocumentEndToken }

  TDocumentEndToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  TVersionDirectiveToken = class(TYamlToken)
  private
    FMajor: Integer;
    FMinor: Integer;

  public
    constructor Create(AMajor, AMinor: Integer; startMark, endMark: TYamlMark);
    property major: Integer Read FMajor;
    property minor: Integer Read FMinor;

  end;

  TTagDirectiveToken = class(TYamlToken)
  private
    FHandle: String;
    FPrefix: String;

  public
    constructor Create( AHandle, APrefix: String; startMark, endMark: TYamlMark);
    property handle: String Read FHandle;
    property prefix: String Read FPrefix;

  end;

  TAliasToken = class(TYamlToken)
  private
    FValue: String;

  public
    constructor Create(AValue: String; startMark, endMark: TYamlMark);
    property Value: String Read FValue;
  end;

  TAnchorToken = class(TYamlToken)
  private
    FValue: String;

  public
    constructor Create(AValue: String; startMark, endMark: TYamlMark);
    property Value: String Read FValue;
  end;

  TTagToken = class(TYamlToken)
  private
    FHandle: String;
    FSuffix: String;

  public
    constructor Create(AHandle: String; ASuffix: String; startMark, endMark: TYamlMark);
    property handle: String Read FHandle;
    property suffix: String Read FSuffix;
  end;

  { TBlockEntryToken }

  TBlockEntryToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  TBlockEndToken = class(TYamlToken)
    public
      constructor Create(startMark, endMark: TYamlMark);
  end;

  TScalarToken = class(TYamlToken)
  private
    FValue: String;
    FScalarStyle: TYamlScalarStyle;

  public
    constructor Create(AValue: String; AStyle: TYamlScalarStyle; startMark, endMark: TYamlMark);
    property Value: String Read FValue;
    property scalar_style: TYamlScalarStyle Read FScalarStyle;
  end;

  { TFlowSequenceStartToken }

  TFlowSequenceStartToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TFlowSequenceEndToken }

  TFlowSequenceEndToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TFlowMappingStartToken }

  TFlowMappingStartToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TFlowMappingEndToken }

  TFlowMappingEndToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TFlowEntryToken }

  TFlowEntryToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TBlockSequenceStartToken }

  TBlockSequenceStartToken = class(TYamlToken)
  public
    constructor Create( startMark, endMark: TYamlMark);
  end;

  { TBlockMappingStartToken }

  TBlockMappingStartToken = class(TYamlToken)
  public
    constructor Create( startMark, endMark: TYamlMark);
  end;

  { TKeyToken }

  TKeyToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

  { TValueToken }

  TValueToken = class(TYamlToken)
  public
    constructor Create(startMark, endMark: TYamlMark);
  end;

implementation

{ TValueToken }

constructor TValueToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TKeyToken }

constructor TKeyToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TBlockEntryToken }

constructor TBlockEntryToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TFlowEntryToken }

constructor TFlowEntryToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TFlowMappingEndToken }

constructor TFlowMappingEndToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TFlowMappingStartToken }

constructor TFlowMappingStartToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TFlowSequenceEndToken }

constructor TFlowSequenceEndToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TFlowSequenceStartToken }

constructor TFlowSequenceStartToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TDocumentEndToken }

constructor TDocumentEndToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TDocumentStartToken }

constructor TDocumentStartToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TStreamEndToken }

constructor TStreamEndToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TBlockMappingStartToken }

constructor TBlockMappingStartToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

{ TBlockSequenceStartToken }

constructor TBlockSequenceStartToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

constructor TYamlToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create;

  FStartMark := startMark;
  FEndMark := endMark;
end;

constructor TStreamStartToken.Create(AEncoding: TYamlEncoding; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FEncoding := AEncoding;
end;

constructor TVersionDirectiveToken.Create(AMajor, AMinor: Integer; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FMajor := AMajor;
  FMinor := AMinor;
end;

constructor TTagDirectiveToken.Create( AHandle, APrefix: String; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FHandle := AHandle;
  FPrefix := APrefix;
end;

constructor TBlockEndToken.Create(startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
end;

constructor TAnchorToken.Create(AValue: String; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FValue := AValue;
end;

constructor TAliasToken.Create(AValue: String; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FValue := AValue;
end;

constructor TTagToken.Create(AHandle: String; ASuffix: String; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FHandle := AHandle;
  FSuffix := ASuffix;
end;

constructor TScalarToken.Create(AValue: String; AStyle: TYamlScalarStyle; startMark, endMark: TYamlMark);
begin
  inherited Create(startMark, endMark);
  FValue := AValue;
  FScalarStyle := AStyle;
end;

end.
