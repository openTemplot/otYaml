unit otYamlEvent;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  otYaml;

type

  { TYamlEvent }

  TYamlEvent = class
  private
    FEventType: TYamlEventType;
    FStartMark: TYamlMark;
    FEndMark: TYamlMark;
  public
    constructor Create(AEventType: TYamlEventType; AStartMark: TYamlMark;
      AEndMark: TYamlMark);

    property eventType: TYamlEventType Read FEventType;
  end;

  { TStreamStartEvent }

  TStreamStartEvent = class(TYamlEvent)
  private
    FEncoding: TYamlEncoding;
  public
    constructor Create(AEncoding: TYamlEncoding; AStartMark: TYamlMark; AEndMark: TYamlMark);

    property encoding: TYamlEncoding Read FEncoding;
  end;

  { TStreamEndEvent }

  TStreamEndEvent = class(TYamlEvent)
  public
    constructor Create(AStartMark: TYamlMark; AEndMark: TYamlMark);
  end;

  { TDocumentStartEvent }

  TDocumentStartEvent = class(TYamlEvent)
  private
    FVersionDirective: TYamlVersionDirective;
    FTagDirectives: TYamlTagDirectives;
    FImplicit: Boolean;

  public
    constructor Create(AVersionDirective: TYamlVersionDirective;
      ATagDirectives: TYamlTagDirectives; AImplicit: boolean; AStartMark: TYamlMark;
      AEndMark: TYamlMark);
    destructor Destroy; override;

    property versionDirective: TYamlVersionDirective Read FVersionDirective;
    property tagDirectives: TYamlTagDirectives Read FTagDirectives;
    property implicit: Boolean Read FImplicit;
  end;

  { TDocumentEndEvent }

  TDocumentEndEvent = class(TYamlEvent)
  private
    FImplicit: Boolean;

  public
    constructor Create(AImplicit: Boolean; AStartMark: TYamlMark; AEndMark: TYamlMark);

    property implicit: Boolean Read FImplicit;
  end;

  { TAliasEvent }

  TAliasEvent = class(TYamlEvent)
  private
    FAnchor: String;
  public
    constructor Create(const AAnchor: String; AStartMark: TYamlMark; AEndMark: TYamlMark);

    property anchor: String Read FAnchor;
  end;

  { TScalarEvent }

  TScalarEvent = class(TYamlEvent)
  private
    FAnchor: String;
    FTag: String;
    FValue: String;
    FPlainImplicit: Boolean;
    FQuotedImplicit: Boolean;
    FScalarStyle: TYamlScalarStyle;
  public
    constructor Create(const AAnchor, ATag, AValue: String;
      APlainImplicit, AQuotedImplicit: Boolean;
      AStyle: TYamlScalarStyle; AStartMark, AEndMark: TYamlMark);
    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property Value: String Read FValue;
    property plainImplicit: Boolean Read FPlainImplicit;
    property quotedImplicit: Boolean Read FQuotedImplicit;
    property scalarStyle: TYamlScalarStyle Read FScalarStyle;
  end;

  { TSequenceStartEvent }

  TSequenceStartEvent = class(TYamlEvent)
  private
    FAnchor: String;
    FTag: String;
    FImplicit: Boolean;
    FSequenceStyle: TYamlSequenceStyle;
  public
    constructor Create(const AAnchor, ATag: String; AImplicit: Boolean;
      AStyle: TYamlSequenceStyle; AStartMark, AEndMark: TYamlMark);

    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property implicit: Boolean Read FImplicit;
    property sequenceStyle: TYamlSequenceStyle Read FSequenceStyle;
  end;

  { TSequenceEndEvent }

  TSequenceEndEvent = class(TYamlEvent)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

  { TMappingStartEvent }

  TMappingStartEvent = class(TYamlEvent)
  private
    FAnchor: String;
    FTag: String;
    FImplicit: Boolean;
    FMappingStyle: TYamlMappingStyle;
  public
    constructor Create(const AAnchor, ATag: String; AImplicit: Boolean; AStyle: TYamlMappingStyle;
      AStartMark, AEndMark: TYamlMark);
    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property implicit: Boolean Read FImplicit;
    property mappingStyle: TYamlMappingStyle Read FMappingStyle;
  end;

  { TMappingEndEvent }

  TMappingEndEvent = class(TYamlEvent)
  public
    constructor Create(AStartMark, AEndMark: TYamlMark);
  end;

implementation

{ TYamlEvent }

constructor TYamlEvent.Create(AEventType: TYamlEventType;
  AStartMark: TYamlMark; AEndMark: TYamlMark);
begin
  inherited Create;

  FEventType := AEventType;
  FStartMark := AStartMark;
  FEndMark := AEndMark;
end;


{ TStreamStartEvent }

constructor TStreamStartEvent.Create(AEncoding: TYamlEncoding;
  AStartMark: TYamlMark; AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_STREAM_START_EVENT, AStartMark, AEndMark);

  FEncoding := AEncoding;
end;

{ TStreamEndEvent }

constructor TStreamEndEvent.Create(AStartMark: TYamlMark;
  AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_STREAM_END_EVENT, AStartMark, AEndMark);
end;

{ TDocumentStartEvent }

constructor TDocumentStartEvent.Create(AVersionDirective: TYamlVersionDirective;
  ATagDirectives: TYamlTagDirectives; AImplicit: boolean;
  AStartMark: TYamlMark; AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_DOCUMENT_START_EVENT, AStartMark, AEndMark);

  FVersionDirective := AVersionDirective;
  FTagDirectives := ATagDirectives;
  FImplicit := AImplicit;

  if not Assigned(FTagDirectives) then
    FTagDirectives := TYamlTagDirectives.Create;
end;

destructor TDocumentStartEvent.Destroy;
begin
  inherited Destroy;
end;


{ TDocumentEndEvent }

constructor TDocumentEndEvent.Create(AImplicit: Boolean;
  AStartMark: TYamlMark; AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_DOCUMENT_END_EVENT, AStartMark, AEndMark);

  FImplicit := AImplicit;
end;

{ TMappingStartEvent }

constructor TMappingStartEvent.Create(const AAnchor, ATag: String; AImplicit: Boolean;
  AStyle: TYamlMappingStyle; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_MAPPING_START_EVENT, AStartMark, AEndMark);

  FAnchor := AAnchor;
  FTag := ATag;
  FImplicit := AImplicit;
  FMappingStyle := AStyle;
end;

{ TMappingEndEvent }

constructor TMappingEndEvent.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_MAPPING_END_EVENT, AStartMark, AEndMark);
end;

{ TScalarEvent }

constructor TScalarEvent.Create(const AAnchor, ATag, AValue: String; APlainImplicit,
  AQuotedImplicit: Boolean; AStyle: TYamlScalarStyle; AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SCALAR_EVENT, AStartMark, AEndMark);

  FAnchor := AAnchor;
  FTag := ATag;
  FValue := AValue;
  FPlainImplicit := APlainImplicit;
  FQuotedImplicit := AQuotedImplicit;
  FScalarStyle := AStyle;
end;

{ TSequenceStartEvent }

constructor TSequenceStartEvent.Create(const AAnchor, ATag: String;
  AImplicit: Boolean; AStyle: TYamlSequenceStyle; AStartMark,
  AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SEQUENCE_START_EVENT, AStartMark, AEndMark);

  FAnchor := AAnchor;
  FTag := ATag;
  FImplicit := AImplicit;
  FSequenceStyle := AStyle;
end;

{ TSequenceEndEvent }

constructor TSequenceEndEvent.Create(AStartMark, AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SEQUENCE_END_EVENT, AStartMark, AEndMark);
end;

{ TAliasEvent }

constructor TAliasEvent.Create(const AAnchor: String; AStartMark: TYamlMark;
  AEndMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_ALIAS_EVENT, AStartMark, AEndMark);
  FAnchor := AAnchor;
end;


end.
