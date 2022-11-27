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
    constructor Create(event_type: TYamlEventType; start_mark: TYamlMark;
      end_mark: TYamlMark);

    property eventType: TYamlEventType Read FEventType;
  end;

  { TStreamStartEvent }

  TStreamStartEvent = class(TYamlEvent)
  private
    FEncoding: TYamlEncoding;
  public
    constructor Create(encoding: TYamlEncoding; start_mark: TYamlMark; end_mark: TYamlMark);

    property encoding: TYamlEncoding Read FEncoding;
  end;

  { TStreamEndEvent }

  TStreamEndEvent = class(TYamlEvent)
  public
    constructor Create(start_mark: TYamlMark; end_mark: TYamlMark);
  end;

  { TDocumentStartEvent }

  TDocumentStartEvent = class(TYamlEvent)
  private
    FVersionDirective: TYamlVersionDirective;
    FTagDirectives: TYamlTagDirectives;
    FImplicit: Boolean;

  public
    constructor Create(versionDirective: TYamlVersionDirective;
      tagDirectives: TYamlTagDirectives; implicit: boolean; startMark: TYamlMark;
      endMark: TYamlMark);
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
    constructor Create(implicit: Boolean; start_mark: TYamlMark; end_mark: TYamlMark);

    property implicit: Boolean Read FImplicit;
  end;

  { TAliasEvent }

  TAliasEvent = class(TYamlEvent)
  private
    FAnchor: String;
  public
    constructor Create(AAnchor: String; start_mark: TYamlMark; end_mark: TYamlMark);

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
    constructor Create(anchor, tag, Value: String; plain_implicit, quoted_implicit: Boolean;
      style: TYamlScalarStyle; start_mark, end_mark: TYamlMark);
    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property value: String Read FValue;
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
    constructor Create(anchor, tag: String; implicit: Boolean;
      style: TYamlSequenceStyle; start_mark, end_mark: TYamlMark);

    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property implicit: Boolean Read FImplicit;
    property sequenceStyle: TYamlSequenceStyle Read FSequenceStyle;
  end;

  { TSequenceEndEvent }

  TSequenceEndEvent = class(TYamlEvent)
  public
    constructor Create(start_mark, end_mark: TYamlMark);
  end;

  { TMappingStartEvent }

  TMappingStartEvent = class(TYamlEvent)
  private
    FAnchor: String;
    FTag: String;
    FImplicit: Boolean;
    FMappingStyle: TYamlMappingStyle;
  public
    constructor Create(anchor, tag: String; implicit: Boolean; style: TYamlMappingStyle;
      start_mark, end_mark: TYamlMark);
    property anchor: String Read FAnchor;
    property tag: String Read FTag;
    property implicit: Boolean Read FImplicit;
    property mappingStyle: TYamlMappingStyle Read FMappingStyle;
  end;

  { TMappingEndEvent }

  TMappingEndEvent = class(TYamlEvent)
  public
    constructor Create(start_mark, end_mark: TYamlMark);
  end;

implementation

{ TYamlEvent }

constructor TYamlEvent.Create(event_type: TYamlEventType;
  start_mark: TYamlMark; end_mark: TYamlMark);
begin
  inherited Create;

  FEventType := event_type;
  FStartMark := start_mark;
  FEndMark := end_mark;
end;


{ TStreamStartEvent }

constructor TStreamStartEvent.Create(encoding: TYamlEncoding;
  start_mark: TYamlMark; end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_STREAM_START_EVENT, start_mark, end_mark);

  FEncoding := encoding;
end;

{ TStreamEndEvent }

constructor TStreamEndEvent.Create(start_mark: TYamlMark;
  end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_STREAM_END_EVENT, start_mark, end_mark);
end;

{ TDocumentStartEvent }

constructor TDocumentStartEvent.Create(versionDirective: TYamlVersionDirective;
  tagDirectives: TYamlTagDirectives; implicit: boolean;
  startMark: TYamlMark; endMark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_DOCUMENT_START_EVENT, startMark, endMark);

  FVersionDirective := versionDirective;
  FTagDirectives := tagDirectives;
  FImplicit := implicit;

  if not Assigned(FTagDirectives) then
    FTagDirectives := TYamlTagDirectives.Create;
end;

destructor TDocumentStartEvent.Destroy;
begin
  inherited Destroy;
end;


{ TDocumentEndEvent }

constructor TDocumentEndEvent.Create(implicit: Boolean;
  start_mark: TYamlMark; end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_DOCUMENT_END_EVENT, start_mark, end_mark);

  FImplicit := implicit;
end;

{ TMappingStartEvent }

constructor TMappingStartEvent.Create(anchor, tag: String; implicit: Boolean;
  style: TYamlMappingStyle; start_mark, end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_MAPPING_START_EVENT, start_mark, end_mark);

  FAnchor := anchor;
  FTag := tag;
  FImplicit := implicit;
  FMappingStyle := style;
end;

{ TMappingEndEvent }

constructor TMappingEndEvent.Create(start_mark, end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_MAPPING_END_EVENT, start_mark, end_mark);
end;

{ TScalarEvent }

constructor TScalarEvent.Create(anchor, tag, Value: String; plain_implicit,
  quoted_implicit: Boolean; style: TYamlScalarStyle; start_mark, end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SCALAR_EVENT, start_mark, end_mark);

  FAnchor := anchor;
  FTag := tag;
  FValue := Value;
  FPlainImplicit := plain_implicit;
  FQuotedImplicit := quoted_implicit;
  FScalarStyle := style;
end;

{ TSequenceStartEvent }

constructor TSequenceStartEvent.Create(anchor, tag: String;
  implicit: Boolean; style: TYamlSequenceStyle; start_mark,
  end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SEQUENCE_START_EVENT, start_mark, end_mark);

  FAnchor := anchor;
  FTag := tag;
  FImplicit := implicit;
  FSequenceStyle := style;
end;

{ TSequenceEndEvent }

constructor TSequenceEndEvent.Create(start_mark, end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_SEQUENCE_END_EVENT, start_mark, end_mark);
end;

{ TAliasEvent }

constructor TAliasEvent.Create(AAnchor: String; start_mark: TYamlMark;
  end_mark: TYamlMark);
begin
  inherited Create(TYamlEventType.YAML_ALIAS_EVENT, start_mark, end_mark);
  FAnchor := AAnchor;
end;


end.
