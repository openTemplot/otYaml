unit otYamlEmitter;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  otYaml,
  otYamlEvent,
  otQueue,
  otYamlWriter;

(**
 * The emitter structure.
 *
 * All members are internal.  Manage the structure using the @c yaml_emitter_
 * family of functions.
 *)
type

  { EYamlEmitterError }

  EYamlEmitterError = class(Exception)
  private
    FMark: TYamlMark;

  public
    constructor Create(const AProblem: String);
  end;


  { TYamlEmitter }

  TYamlEmitter = class
  private
    (**
     * @name Writer stuff
     * @{
     *)

    FWriter: TYamlWriter;


    (** The stream encoding. *)
    FEncoding: TYamlEncoding;

    (**
     * @name Emitter stuff
     * @{
     *)

    (** If the output is in the canonical style? *)
    FCanonical: Boolean;
    (** The number of indentation spaces. *)
    FBestIndent: Integer;
    (** The preferred width of the output lines. *)
    FBestWidth: Integer;
    (** Allow unescaped non-ASCII characters? *)
    FAllowUnescapedUnicode: Boolean;

    (** The preferred line break. *)
    FLineBreak: TYamlBreak;

    (** The stack of states. *)
    FStates: TStack<TYamlEmitterState>;

    (** The current emitter state. *)
    FState: TYamlEmitterState;

    (** The event queue. *)
    FEvents: TOTQueue<TYamlEvent>;

    (** The stack of indentation levels. *)
    FIndents: TStack<Integer>;

    (** The list of tag directives. *)
    FTagDirectives: TYamlTagDirectives;

    (** The current indentation level. *)
    FIndent: Integer;

    (** The current flow level. *)
    FFlowLevel: Integer;

    (** Is it the document root context? *)
    FIsRootContext: Boolean;
    (** Is it a sequence context? *)
    FIsSequenceContext: Boolean;
    (** Is it a mapping context? *)
    FIsMappingContext: Boolean;
    (** Is it a simple mapping key context? *)
    FIsSimpleKeyContext: Boolean;

    (** If the last character was a whitespace? *)
    FPrevWasWhitespace: Boolean;
    (** If the last character was an indentation character (' ', '-', '?', ':')? *)
    FPrevWasIndentation: Boolean;
    (** If an explicit document end is required? *)
    FExplicitDocEndRequired: Integer;

    FAnchors: THashSet<String>;

    (** Anchor analysis. *)
    FAnchorData: record
      FAnchor: String;
      (** Is it an alias? *)
      FIsAlias: Boolean;
      end;

    (** Tag analysis. *)
    FTagData: record
      (** The tag handle. *)
      FHandle: string;
      (** The tag suffix. *)
      FSuffix: string;
      end;

    (** Scalar analysis. *)
    FScalarData: record
      (** The scalar value. *)
      FValue: string;
      (** Does the scalar contain line breaks? *)
      FIsMultiline: Boolean;
      (** Can the scalar be expessed in the flow plain style? *)
      FFlowPlainAllowed: Boolean;
      (** Can the scalar be expressed in the block plain style? *)
      FBlockPlainAllowed: Boolean;
      (** Can the scalar be expressed in the single quoted style? *)
      FSingleQuotedAllowed: Boolean;
      (** Can the scalar be expressed in the literal or folded styles? *)
      FBlockAllowed: Boolean;
      (** The output style. *)
      FStyle: TYamlScalarStyle;
      end;

    procedure SetEmitterError(const AProblem: String);
    procedure AppendTagDirective(const AValue: TYamlTagDirective;
      AAllowDuplicates: Boolean);
    function NeedMoreEvents: Boolean;
    procedure IncreaseIndent(AFlow, AIndentless: Boolean);


    function emit(event: TYamlEvent): Boolean;

    procedure ProcessAnchor;
    procedure ProcessTag;
    procedure ProcessScalar;

    procedure AnalyzeEvent(AEvent: TYamlEvent);
    procedure AnalyzeAnchor(const AAnchor: String; AIsAlias: Boolean);
    procedure AnalyzeTag(const ATag: String);
    procedure AnalyzeScalar(const AValue: String);
    procedure AnalyzeVersionDirective(const AVersionDirective: TYamlVersionDirective);
    procedure AnalyzeTagDirective(const AValue: TYamlTagDirective);

    function StateMachine(AEvent: TYamlEvent): Boolean;

    function EmitStreamStart(AEvent: TYamlEvent): Boolean;
    function EmitDocumentStart(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
    function EmitDocumentContent(AEvent: TYamlEvent): Boolean;
    function EmitDocumentEnd(AEvent: TYamlEvent): Boolean;
    function EmitFlowSequenceItem(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
    function EmitFlowMappingKey(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
    function EmitFlowMappingValue(AEvent: TYamlEvent; ASimple: Boolean): Boolean;
    function EmitBlockSequenceItem(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
    function EmitBlockMappingKey(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
    function EmitBlockMappingValue(AEvent: TYamlEvent; ASimple: Boolean): Boolean;
    function EmitNode(AEvent: TYamlEvent;
      ARoot, ASequence, AMapping, ASimpleKey: Boolean): Boolean;
    function EmitAlias(AEvent: TAliasEvent): Boolean;
    function EmitScalar(AEvent: TScalarEvent): Boolean;
    function EmitSequenceStart(AEvent: TSequenceStartEvent): Boolean;
    function EmitMappingStart(AEvent: TMappingStartEvent): Boolean;

    procedure WriteBOM;
    procedure WriteIndent;
    procedure WriteIndicator(const AIndicator: string; ANeedWhitespace: boolean;
      AIsWhitespace: boolean; AIsIndentation: boolean);
    procedure WriteAnchor(const AValue: string);
    procedure WriteTagHandle(const AValue: string);
    procedure WriteTagContent(const AValue: string; ANeedWhitespace: Boolean);
    procedure WritePlainScalar(const AValue: string; AAllowBreaks: Boolean);
    procedure WriteSingleQuotedScalar(const AValue: string; AAllowBreaks: Boolean);
    procedure WriteDoubleQuotedScalar(const AValue: string; AAllowBreaks: Boolean);
    procedure WriteBlockScalarHints(const AValue: string);
    procedure WriteLiteralScalar(const AValue: string);
    procedure WriteFoldedScalar(const AValue: string);

    function CheckEmptyDocument: Boolean;
    function CheckEmptySequence: Boolean;
    function CheckEmptyMapping: Boolean;
    function CheckSimpleKey: Boolean;
    function SelectScalarStyle(AEvent: TScalarEvent): TYamlScalarStyle;


  public
    constructor Create;
    destructor Destroy; override;

    procedure SetOutput(AStream: TStream);
    procedure SetCanonical(ACanonical: Boolean);
    procedure SetUnicode(AAllowUnescapedUnicode: Boolean);
    procedure SetIndent(AIndent: Integer);
    procedure SetWidth(AWidth: Integer);
    procedure SetBreak(ABreak: TYamlBreak);

    procedure StreamStartEvent;
    procedure StreamEndEvent;
    procedure DocumentStartEvent(AVersionDirective: TYamlVersionDirective;
      ATagDirectives: TYamlTagDirectives; AImplicit: boolean);
    procedure DocumentEndEvent(AImplicit: Boolean);
    procedure SequenceStartEvent(const AAnchor, ATag: String; AImplicit: Boolean;
      AStyle: TYamlSequenceStyle);
    procedure SequenceEndEvent;
    procedure MappingStartEvent(const AAnchor, ATag: String; AImplicit: Boolean;
      AStyle: TYamlMappingStyle);
    procedure MappingEndEvent;
    procedure ScalarEvent(const AAnchor, ATag, AValue: String;
      APlainImplicit, AQuotedImplicit: Boolean;
      AStyle: TYamlScalarStyle);
    procedure AliasEvent(const AAnchor: String);

    function HasAnchor(const AAnchor: String): Boolean;
  end;


implementation

uses
  otYamlChars;

{ EYamlEmitterError }

constructor EYamlEmitterError.Create(const AProblem: String);
begin
  inherited Create(AProblem);
end;

{ TYamlEmitter }

procedure TYamlEmitter.SetEmitterError(const AProblem: String);
begin
  raise EYamlEmitterError(AProblem);
end;

function TYamlEmitter.emit(event: TYamlEvent): Boolean;
begin
  FEvents.Enqueue(event);

  while not NeedMoreEvents do begin
    AnalyzeEvent(FEvents.Peek);
    if not StateMachine(FEvents.Peek) then
      Exit(False);
    FEvents.Dequeue;
  end;

  Result := True;
end;

function TYamlEmitter.NeedMoreEvents: Boolean;
var
  level: Integer;
  accumulate: Integer;
  event: TYamlEvent;
begin
  if FEvents.Count = 0 then
    Exit(True);

  level := 0;

  case FEvents.Peek.eventType of
    YAML_DOCUMENT_START_EVENT:
      accumulate := 1;
    YAML_SEQUENCE_START_EVENT:
      accumulate := 2;
    YAML_MAPPING_START_EVENT:
      accumulate := 3;
    else
      Exit(False);
  end;

  if FEvents.Count >= accumulate then
    Exit(False);

  for event in FEvents do begin
    if event = FEvents.Tail then
      break;

    case event.eventType of
      YAML_STREAM_START_EVENT,
      YAML_DOCUMENT_START_EVENT,
      YAML_SEQUENCE_START_EVENT,
      YAML_MAPPING_START_EVENT:
        Inc(level);

      YAML_STREAM_END_EVENT,
      YAML_DOCUMENT_END_EVENT,
      YAML_SEQUENCE_END_EVENT,
      YAML_MAPPING_END_EVENT:
        Dec(level);
    end;

    if level = 0 then
      Exit(False);
  end;

  Exit(True);
end;

procedure TYamlEmitter.AppendTagDirective(const AValue: TYamlTagDirective;
  AAllowDuplicates: Boolean);
var
  i: Integer;
begin
  for i := 0 to High(FTagDirectives) do begin
    if AValue.Handle = FTagDirectives[i].Handle then begin
      if AAllowDuplicates then
        Exit;
      SetEmitterError('duplicate %TAG directive');
    end;
  end;

  SetLength(FTagDirectives, Length(FTagDirectives) + 1);
  FTagDirectives[High(FTagDirectives)] := AValue;
end;

procedure TYamlEmitter.IncreaseIndent(AFlow, AIndentless: Boolean);
begin
  FIndents.Push(FIndent);

  if (FIndent < 0) then begin
    if AFlow then
      FIndent := FBestIndent
    else
      FIndent := 0;
  end
  else
  if (not AIndentless) then begin
    FIndent := FIndent + FBestIndent;
  end;
end;

procedure TYamlEmitter.ProcessAnchor;
var
  indicator: string;
begin
  if (FAnchorData.FAnchor = '') then
    Exit;

  if FAnchorData.FIsAlias then
    indicator := '*'
  else
    indicator := '&';
  WriteIndicator(indicator, True, False, False);
  WriteAnchor(FAnchorData.FAnchor);
end;

procedure TYamlEmitter.ProcessTag;
begin
  if (FTagData.FHandle = '') and (FTagData.FSuffix = '') then
    Exit;

  if (FTagData.FHandle <> '') then begin
    WriteTagHandle(FTagData.FHandle);
    if (FTagData.FSuffix <> '') then begin
      WriteTagContent(FTagData.FSuffix, False);
    end;
  end
  else begin
    WriteIndicator('!<', True, False, False);
    WriteTagContent(FTagData.FSuffix, False);
    WriteIndicator('>', False, False, False);
  end;
end;

procedure TYamlEmitter.ProcessScalar;
begin
  case FScalarData.FStyle of
    yssPlainScalar:
      WritePlainScalar(
        FScalarData.FValue, not FIsSimpleKeyContext);

    yssSingleQuotedScalar:
      WriteSingleQuotedScalar(
        FScalarData.FValue, not FIsSimpleKeyContext);

    yssDoubleQuotedScalar:
      WriteDoubleQuotedScalar(
        FScalarData.FValue, not FIsSimpleKeyContext);

    yssLiteralScalar:
      WriteLiteralScalar(FScalarData.FValue);

    yssFoldedScalar:
      WriteFoldedScalar(FScalarData.FValue);
    else
      assert(False);      // Impossible.
  end;
end;

procedure TYamlEmitter.AnalyzeEvent(AEvent: TYamlEvent);
var
  scalarEvent: TScalarEvent;
  sequenceStartEvent: TSequenceStartEvent;
  mappingStartEvent: TMappingStartEvent;
begin
  FAnchorData.FAnchor := '';
  FTagData.FHandle := '';
  FTagData.FSuffix := '';
  FScalarData.FValue := '';

  case AEvent.eventType of
    YAML_ALIAS_EVENT: begin
      AnalyzeAnchor(TAliasEvent(AEvent).anchor, True);
      Exit;
    end;

    YAML_SCALAR_EVENT: begin
      scalarEvent := TScalarEvent(AEvent);
      if (scalarEvent.anchor <> '') then begin
        AnalyzeAnchor(scalarEvent.anchor, False);
      end;
      if (scalarEvent.tag <> '') and (FCanonical or
        (not scalarEvent.plainImplicit
        and not scalarEvent.quotedImplicit)) then begin
        AnalyzeTag(scalarEvent.tag);
      end;
      AnalyzeScalar(scalarEvent.Value);
      Exit;
    end;

    YAML_SEQUENCE_START_EVENT: begin
      sequenceStartEvent := TSequenceStartEvent(AEvent);
      if (sequenceStartEvent.anchor <> '') then begin
        AnalyzeAnchor(sequenceStartEvent.anchor, False);
      end;
      if (sequenceStartEvent.TAG <> '') and (FCanonical or
        not sequenceStartEvent.implicit) then begin
        AnalyzeTag(sequenceStartEvent.tag);
      end;
      Exit;
    end;

    YAML_MAPPING_START_EVENT: begin
      mappingStartEvent := TMappingStartEvent(AEvent);
      if (mappingStartEvent.anchor <> '') then begin
        AnalyzeAnchor(mappingStartEvent.anchor, False);
      end;
      if (mappingStartEvent.tag <> '') and (FCanonical or
        not mappingStartEvent.implicit) then begin
        AnalyzeTag(mappingStartEvent.tag);
      end;
      Exit;
    end

    else
      Exit;
  end;
end;

procedure TYamlEmitter.AnalyzeAnchor(const AAnchor: String; AIsAlias: Boolean);
var
  i: Integer;
begin
  if AAnchor = '' then begin
    if AIsAlias then
      SetEmitterError('alias value must not be empty')
    else
      SetEmitterError('anchor value must not be empty');
  end;

  for i := 1 to Length(AAnchor) do begin
    if not IsAlphaAt(AAnchor, i) then begin
      if AIsAlias then
        SetEmitterError('alias value must contain alphanumerical characters only')
      else
        SetEmitterError('anchor value must contain alphanumerical characters only');
    end;
  end;

  FAnchorData.FAnchor := AAnchor;
  FAnchorData.FIsAlias := AIsAlias;

  FAnchors.Add(AAnchor);
end;

procedure TYamlEmitter.AnalyzeTag(const ATag: String);
var
  tag_directive: TYamlTagDirective;
  prefix_length: Integer;
begin
  if ATag = '' then
    SetEmitterError('tag value must not be empty');

  for tag_directive in FTagDirectives do begin
    prefix_length := Length(tag_directive.Prefix);

    if (prefix_length < Length(ATag)) and (Pos(tag_directive.Prefix, ATag) = 1) then begin
      FTagData.FHandle := tag_directive.Handle;
      FTagData.FSuffix := Copy(ATag, prefix_length + 1, Length(ATag) - prefix_length);
      Exit;
    end;
  end;

  FTagData.FSuffix := ATag;
end;

procedure TYamlEmitter.AnalyzeScalar(const AValue: String);
var
  block_indicators: Boolean;
  flow_indicators: Boolean;
  line_breaks: Boolean;
  special_characters: Boolean;
  leading_space: Boolean;
  leading_break: Boolean;
  trailing_space: Boolean;
  trailing_break: Boolean;
  break_space: Boolean;
  space_break: Boolean;
  preceded_by_whitespace: Boolean;
  followed_by_whitespace: Boolean;
  previous_space: Boolean;
  previous_break: Boolean;
  p: Integer;
begin
  block_indicators := False;
  flow_indicators := False;
  line_breaks := False;
  special_characters := False;
  leading_space := False;
  leading_break := False;
  trailing_space := False;
  trailing_break := False;
  break_space := False;
  space_break := False;
  preceded_by_whitespace := False;
  followed_by_whitespace := False;
  previous_space := False;
  previous_break := False;


  FScalarData.FValue := AValue;

  if (AValue = '') then begin
    FScalarData.FIsMultiline := False;
    FScalarData.FFlowPlainAllowed := False;
    FScalarData.FBlockPlainAllowed := True;
    FScalarData.FSingleQuotedAllowed := True;
    FScalarData.FBlockAllowed := False;

    Exit;
  end;

  if (Pos('---', AValue) = 1) or (Pos('...', AValue) = 1) then begin
    block_indicators := True;
    flow_indicators := True;
  end;

  preceded_by_whitespace := True;
  followed_by_whitespace := IsBlankZAt(AValue, Length(AValue));

  p := 1;
  while p <= Length(AValue) do begin
    if (p = 1) then begin
      if (AValue[p] in ['#', ',', '[', ']', '{', '}', '&', '*', '!', '|',
        '>', '''', '"', '%', '@', '`']) then begin
        flow_indicators := True;
        block_indicators := True;
      end;

      if (AValue[p] in ['?', ':']) then begin
        flow_indicators := True;
        if (followed_by_whitespace) then begin
          block_indicators := True;
        end;
      end;

      if (AValue[p] = '-') and followed_by_whitespace then begin
        flow_indicators := True;
        block_indicators := True;
      end;
    end
    else begin
      if AValue[p] in [',', '?', '[', ']', '{', '}'] then begin
        flow_indicators := True;
      end;

      if (AValue[p] = ':') then begin
        flow_indicators := True;
        if (followed_by_whitespace) then begin
          block_indicators := True;
        end;
      end;

      if (AValue[p] = '#') and preceded_by_whitespace then begin
        flow_indicators := True;
        block_indicators := True;
      end;
    end;

    if (not IsPrintableAt(AValue, p)) or ((not IsAsciiAt(AValue, p)) and
      (not FAllowUnescapedUnicode)) then begin
      special_characters := True;
    end;

    if (IsBreakAt(AValue, p)) then begin
      line_breaks := True;
    end;

    if IsSpaceAt(AValue, p) then begin
      if p = 1 then begin
        leading_space := True;
      end;
      if (p + WidthAt(AValue, p) > Length(AValue)) then begin
        trailing_space := True;
      end;
      if (previous_break) then begin
        break_space := True;
      end;
      previous_space := True;
      previous_break := False;
    end
    else
    if IsBreakAt(AValue, p) then begin
      if p = 1 then begin
        leading_break := True;
      end;
      if (p + WidthAt(AValue, p) > Length(AValue)) then begin
        trailing_break := True;
      end;
      if (previous_space) then begin
        space_break := True;
      end;
      previous_space := False;
      previous_break := True;
    end
    else begin
      previous_space := False;
      previous_break := False;
    end;

    preceded_by_whitespace := IsBlankzAt(AValue, p);
    Inc(p, WidthAt(AValue, p));
    if p <= Length(AValue) then begin
      followed_by_whitespace := IsBlankzAt(AValue, p + WidthAt(AValue, p));
    end;
  end;

  FScalarData.FIsMultiline := line_breaks;

  FScalarData.FFlowPlainAllowed := True;
  FScalarData.FBlockPlainAllowed := True;
  FScalarData.FSingleQuotedAllowed := True;
  FScalarData.FBlockAllowed := True;

  if (leading_space or leading_break or trailing_space or trailing_break) then begin
    FScalarData.FFlowPlainAllowed := False;
    FScalarData.FBlockPlainAllowed := False;
  end;

  if (trailing_space) then begin
    FScalarData.FBlockAllowed := False;
  end;

  if (break_space) then begin
    FScalarData.FFlowPlainAllowed := False;
    FScalarData.FBlockPlainAllowed := False;
    FScalarData.FSingleQuotedAllowed := False;
  end;

  if (space_break or special_characters) then begin
    FScalarData.FFlowPlainAllowed := False;
    FScalarData.FBlockPlainAllowed := False;
    FScalarData.FSingleQuotedAllowed := False;
    FScalarData.FBlockAllowed := False;
  end;

  if (line_breaks) then begin
    FScalarData.FFlowPlainAllowed := False;
    FScalarData.FBlockPlainAllowed := False;
  end;

  if (flow_indicators) then begin
    FScalarData.FFlowPlainAllowed := False;
  end;

  if (block_indicators) then begin
    FScalarData.FBlockPlainAllowed := False;
  end;
end;

procedure TYamlEmitter.AnalyzeVersionDirective(
  const AVersionDirective: TYamlVersionDirective);
begin
  if ((AVersionDirective.Major <> 1) or (
    (AVersionDirective.Minor <> 1)
    and (AVersionDirective.Minor <> 2)
    )) then begin
    SetEmitterError('incompatible %YAML directive');
  end;
end;

procedure TYamlEmitter.AnalyzeTagDirective(const AValue: TYamlTagDirective);
var
  handle: String;
  prefix: String;
  i: Integer;
begin
  handle := AValue.Handle;
  prefix := AValue.Prefix;

  if (Length(handle) = 0) then begin
    SetEmitterError('tag handle must not be empty');
  end;

  if (handle[1] <> '!') then begin
    SetEmitterError('tag handle must start with "!"');
  end;

  if (handle[Length(handle)] <> '!') then begin
    SetEmitterError('tag handle must end with "!"');
  end;

  for i := 2 to Length(handle) - 1 do begin
    if not IsAlphaAt(handle, i) then begin
      SetEmitterError('tag handle must contain alphanumerical characters only');
    end;
  end;

  if (Length(prefix) = 0) then begin
    SetEmitterError('tag prefix must not be empty');
  end;
end;

function TYamlEmitter.StateMachine(AEvent: TYamlEvent): Boolean;
begin
  case FState of
    YAML_EMIT_STREAM_START_STATE:
      Exit(EmitStreamStart(AEvent));

    YAML_EMIT_FIRST_DOCUMENT_START_STATE:
      Exit(EmitDocumentStart(AEvent, True));

    YAML_EMIT_DOCUMENT_START_STATE:
      Exit(EmitDocumentStart(AEvent, False));

    YAML_EMIT_DOCUMENT_CONTENT_STATE:
      Exit(EmitDocumentContent(AEvent));

    YAML_EMIT_DOCUMENT_END_STATE:
      Exit(EmitDocumentEnd(AEvent));

    YAML_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE:
      Exit(EmitFlowSequenceItem(AEvent, True));

    YAML_EMIT_FLOW_SEQUENCE_ITEM_STATE:
      Exit(EmitFlowSequenceItem(AEvent, False));

    YAML_EMIT_FLOW_MAPPING_FIRST_KEY_STATE:
      Exit(EmitFlowMappingKey(AEvent, True));

    YAML_EMIT_FLOW_MAPPING_KEY_STATE:
      Exit(EmitFlowMappingKey(AEvent, False));

    YAML_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE:
      Exit(EmitFlowMappingValue(AEvent, True));

    YAML_EMIT_FLOW_MAPPING_VALUE_STATE:
      Exit(EmitFlowMappingValue(AEvent, False));

    YAML_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE:
      Exit(EmitBlockSequenceItem(AEvent, True));

    YAML_EMIT_BLOCK_SEQUENCE_ITEM_STATE:
      Exit(EmitBlockSequenceItem(AEvent, False));

    YAML_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE:
      Exit(EmitBlockMappingKey(AEvent, True));

    YAML_EMIT_BLOCK_MAPPING_KEY_STATE:
      Exit(EmitBlockMappingKey(AEvent, False));

    YAML_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE:
      Exit(EmitBlockMappingValue(AEvent, True));

    YAML_EMIT_BLOCK_MAPPING_VALUE_STATE:
      Exit(EmitBlockMappingValue(AEvent, False));

    YAML_EMIT_END_STATE:
      SetEmitterError('expected nothing after STREAM-END');

    else
      assert(False);      // Invalid FState.
  end;

  Exit(False);
end;

function TYamlEmitter.EmitStreamStart(AEvent: TYamlEvent): Boolean;
begin
  FExplicitDocEndRequired := 0;
  if (AEvent is TStreamStartEvent) then begin
    if (FEncoding = yencAnyEncoding) then begin
      FEncoding := TStreamStartEvent(AEvent).encoding;
    end;

    if (FEncoding = yencAnyEncoding) then begin
      FEncoding := yencUTF8;
    end;

    FWriter.SetEncoding(FEncoding);

    if (FBestIndent < 2) or (FBestIndent > 9) then begin
      FBestIndent := 2;
    end;

    if (FBestWidth >= 0)
      and (FBestWidth <= FBestIndent * 2) then begin
      FBestWidth := 80;
    end;

    if (FBestWidth < 0) then begin
      FBestWidth := MaxInt;
    end;

    if (FLineBreak = ybrkAnyBreak) then begin
      FLineBreak := ybrkLN;
      FWriter.SetBreak(FLineBreak);
    end;

    FIndent := -1;

    FPrevWasWhitespace := True;
    FPrevWasIndentation := True;

    if (FEncoding <> yencUTF8) then begin
      WriteBOM();
    end;

    FState := YAML_EMIT_FIRST_DOCUMENT_START_STATE;

    Exit(True);
  end;

  SetEmitterError('expected STREAM-START');
end;

function TYamlEmitter.EmitDocumentStart(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
var
  docStartEvent: TDocumentStartEvent;
  defaultTagDirectives: TYamlTagDirectives;
  implicit: Boolean;
  td: TYamlTagDirective;
begin
  if (AEvent is TDocumentStartEvent) then begin
    docStartEvent := TDocumentStartEvent(AEvent);

    FAnchors.Clear;

    SetLength(defaultTagDirectives, 2);
    defaultTagDirectives[0] := TYamlTagDirective.Build('!', '!');
    defaultTagDirectives[1] := TYamlTagDirective.Build('!!', 'tag:yaml.org,2002:');


    if (docStartEvent.versionDirective.Major > 0) then begin
      AnalyzeVersionDirective(docStartEvent.versionDirective);
    end;

    for td in docStartEvent.tagDirectives do begin
      AnalyzeTagDirective(td);
      AppendTagDirective(td, False);
    end;

    for td in defaultTagDirectives do begin
      AppendTagDirective(td, True);
    end;

    implicit := docStartEvent.implicit;
    if (not AFirst) or FCanonical then begin
      implicit := False;
    end;

    if ((docStartEvent.versionDirective.Major > 0) or
      (Length(docStartEvent.tagDirectives) > 0)) and
      (FExplicitDocEndRequired > 0) then begin
      WriteIndicator('...', True, False, False);
      WriteIndent;
    end;
    FExplicitDocEndRequired := 0;

    if (docStartEvent.versionDirective.Major > 0) then begin
      implicit := False;
      WriteIndicator('%YAML', True, False, False);
      if (docStartEvent.versionDirective.Minor = 1) then begin
        WriteIndicator('1.1', True, False, False);
      end
      else begin
        WriteIndicator('1.2', True, False, False);
      end;
      WriteIndent;
    end;

    if Length(docStartEvent.tagDirectives) > 0 then begin
      implicit := False;
      for td in docStartEvent.tagDirectives do begin
        WriteIndicator('%TAG', True, False, False);
        WriteTagHandle(td.Handle);
        WriteTagContent(td.Prefix, True);
        WriteIndent;
      end;
    end;

    if (CheckEmptyDocument()) then begin
      implicit := False;
    end;

    if (not implicit) then begin
      WriteIndent;
      WriteIndicator('---', True, False, False);
      if FCanonical then begin
        WriteIndent;
      end;
    end;

    FState := YAML_EMIT_DOCUMENT_CONTENT_STATE;

    FExplicitDocEndRequired := 0;
    Exit(True);
  end

  else
  if (AEvent is TStreamEndEvent) then begin
    //**
    // * This can happen if a block scalar with trailing empty lines
    // * is at the end of the stream
    // */
    if FExplicitDocEndRequired = 2 then begin
      WriteIndicator('...', True, False, False);
      FExplicitDocEndRequired := 0;
      WriteIndent;
    end;

    FState := YAML_EMIT_END_STATE;

    Exit(False);
  end;

  SetEmitterError('expected DOCUMENT-START or STREAM-END');
end;

function TYamlEmitter.EmitDocumentContent(AEvent: TYamlEvent): Boolean;
begin
  FStates.Push(YAML_EMIT_DOCUMENT_END_STATE);

  Exit(EmitNode(AEvent, True, False, False, False));
end;

function TYamlEmitter.EmitDocumentEnd(AEvent: TYamlEvent): Boolean;
begin
  if (AEvent is TDocumentEndEvent) then begin
    WriteIndent;
    if not TDocumentEndEvent(AEvent).implicit then begin
      WriteIndicator('...', True, False, False);
      FExplicitDocEndRequired := 0;
      WriteIndent;
    end
    else
    if (FExplicitDocEndRequired = 0) then
      FExplicitDocEndRequired := 1;

    FState := YAML_EMIT_DOCUMENT_START_STATE;

    SetLength(FTagDirectives, 0);
    Exit(True);
  end;

  SetEmitterError('expected DOCUMENT-END');
end;

function TYamlEmitter.EmitFlowSequenceItem(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
begin
  if (AFirst) then begin
    WriteIndicator('[', True, True, False);
    IncreaseIndent(True, False);
    Inc(FFlowLevel);
  end;

  if (AEvent is TSequenceEndEvent) then begin
    Dec(FFlowLevel);
    FIndent := FIndents.Pop;
    if (FCanonical and not AFirst) then begin
      WriteIndicator(',', False, False, False);
      WriteIndent;
    end;
    WriteIndicator(']', False, False, False);
    FState := FStates.Pop;

    Exit(True);
  end;

  if (not AFirst) then begin
    WriteIndicator(',', False, False, False);
  end;

  if FCanonical or (FWriter.column > FBestWidth) then begin
    WriteIndent;
  end;
  FStates.push(YAML_EMIT_FLOW_SEQUENCE_ITEM_STATE);

  Exit(EmitNode(AEvent, False, True, False, False));
end;

function TYamlEmitter.EmitFlowMappingKey(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
begin
  if (AFirst) then begin
    WriteIndicator('{', True, True, False);
    IncreaseIndent(True, False);
    Inc(FFlowLevel);
  end;

  if (AEvent is TMappingEndEvent) then begin
    Dec(FFlowLevel);
    FIndent := FIndents.Pop;
    if (FCanonical and not AFirst) then begin
      WriteIndicator(',', False, False, False);
      WriteIndent;
    end;
    WriteIndicator('}', False, False, False);
    FState := FStates.Pop;

    Exit(True);
  end;

  if (not AFirst) then begin
    WriteIndicator(',', False, False, False);
  end;
  if (FCanonical or (FWriter.column > FBestWidth)) then begin
    WriteIndent;
  end;

  if (not FCanonical) and CheckSimpleKey then begin
    FStates.Push(YAML_EMIT_FLOW_MAPPING_SIMPLE_VALUE_STATE);

    Exit(EmitNode(AEvent, False, False, True, True));
  end
  else begin
    WriteIndicator('?', True, False, False);
    FStates.Push(YAML_EMIT_FLOW_MAPPING_VALUE_STATE);

    Exit(EmitNode(AEvent, False, False, True, False));
  end;

end;

function TYamlEmitter.EmitFlowMappingValue(AEvent: TYamlEvent; ASimple: Boolean): Boolean;
begin
  if (ASimple) then begin
    WriteIndicator(':', False, False, False);
  end
  else begin
    if FCanonical or (FWriter.column > FBestWidth) then begin
      WriteIndent;
    end;
    WriteIndicator(':', True, False, False);
  end;
  FStates.Push(YAML_EMIT_FLOW_MAPPING_KEY_STATE);
  Exit(EmitNode(AEvent, False, False, True, False));
end;

function TYamlEmitter.EmitBlockSequenceItem(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
begin
  if (AFirst) then begin
    IncreaseIndent(False,
      (FIsMappingContext and not FPrevWasIndentation));
  end;

  if (AEvent is TSequenceEndEvent) then begin
    FIndent := FIndents.Pop;
    FState := FStates.Pop;

    Exit(True);
  end;

  WriteIndent;
  WriteIndicator('-', True, False, True);
  FStates.Push(YAML_EMIT_BLOCK_SEQUENCE_ITEM_STATE);

  Exit(EmitNode(AEvent, False, True, False, False));
end;

function TYamlEmitter.EmitBlockMappingKey(AEvent: TYamlEvent; AFirst: Boolean): Boolean;
begin
  if (AFirst) then begin
    IncreaseIndent(False, False);
  end;

  if (AEvent is TMappingEndEvent) then begin
    FIndent := FIndents.Pop;
    FState := FStates.Pop;

    Exit(True);
  end;

  WriteIndent;

  if CheckSimpleKey then begin
    FStates.Push(YAML_EMIT_BLOCK_MAPPING_SIMPLE_VALUE_STATE);

    Exit(EmitNode(AEvent, False, False, True, True));
  end
  else begin
    WriteIndicator('?', True, False, True);
    FStates.Push(YAML_EMIT_BLOCK_MAPPING_VALUE_STATE);

    Exit(EmitNode(AEvent, False, False, True, False));
  end;

end;

function TYamlEmitter.EmitBlockMappingValue(AEvent: TYamlEvent; ASimple: Boolean): Boolean;
begin
  if (ASimple) then begin
    WriteIndicator(':', False, False, False);
  end
  else begin
    WriteIndent;
    WriteIndicator(':', True, False, True);
  end;

  FStates.Push(YAML_EMIT_BLOCK_MAPPING_KEY_STATE);

  Exit(EmitNode(AEvent, False, False, True, False));

end;

function TYamlEmitter.EmitNode(AEvent: TYamlEvent;
  ARoot, ASequence, AMapping, ASimpleKey: Boolean): Boolean;
begin
  FIsRootContext := ARoot;
  FIsSequenceContext := ASequence;
  FIsMappingContext := AMapping;
  FIsSimpleKeyContext := ASimpleKey;

  if (AEvent is TAliasEvent) then
    Exit(EmitAlias(TAliasEvent(AEvent)))
  else
  if (AEvent is TScalarEvent) then
    Exit(EmitScalar(TScalarEvent(AEvent)))
  else
  if (AEvent is TSequenceStartEvent) then
    Exit(EmitSequenceStart(TSequenceStartEvent(AEvent)))
  else
  if (AEvent is TMappingStartEvent) then
    Exit(EmitMappingStart(TMappingStartEvent(AEvent)))
  else
    SetEmitterError('expected SCALAR, SEQUENCE-START, MAPPING-START, or ALIAS');
end;


function TYamlEmitter.EmitAlias(AEvent: TAliasEvent): Boolean;
begin
  ProcessAnchor;
  if (FIsSimpleKeyContext) then begin
    FWriter.Put(' ');
  end;

  FState := FStates.Pop;
  Exit(True);
end;

function TYamlEmitter.EmitScalar(AEvent: TScalarEvent): Boolean;
begin
  FScalarData.FStyle := SelectScalarStyle(AEvent);
  ProcessAnchor;
  ProcessTag;
  IncreaseIndent(True, False);
  ProcessScalar;
  FIndent := FIndents.Pop;
  FState := FStates.Pop;

  Exit(True);
end;

function TYamlEmitter.EmitSequenceStart(AEvent: TSequenceStartEvent): Boolean;
begin
  ProcessAnchor;
  ProcessTag;

  if (FFlowLevel > 0) or FCanonical
    or (TSequenceStartEvent(AEvent).sequenceStyle = ysqFlowSequence)
    or CheckEmptySequence then begin
    FState := YAML_EMIT_FLOW_SEQUENCE_FIRST_ITEM_STATE;
  end
  else begin
    FState := YAML_EMIT_BLOCK_SEQUENCE_FIRST_ITEM_STATE;
  end;

  Exit(True);
end;

function TYamlEmitter.EmitMappingStart(AEvent: TMappingStartEvent): Boolean;
begin
  ProcessAnchor;
  ProcessTag;

  if (FFlowLevel > 0) or FCanonical
    or (AEvent.mappingStyle = ympFlowMapping)
    or CheckEmptyMapping then begin
    FState := YAML_EMIT_FLOW_MAPPING_FIRST_KEY_STATE;
  end
  else begin
    FState := YAML_EMIT_BLOCK_MAPPING_FIRST_KEY_STATE;
  end;

  Exit(True);
end;


procedure TYamlEmitter.WriteBOM;
begin
  FWriter.put(#$EF);
  FWriter.put(#$BB);
  FWriter.put(#$BF);
end;

procedure TYamlEmitter.WriteIndent;
var
  indent_spaces: Integer;
begin
  if FIndent >= 0 then
    indent_spaces := FIndent
  else
    indent_spaces := 0;

  if (not FPrevWasIndentation) or (FWriter.column > indent_spaces)
    or ((FWriter.column = indent_spaces) and (not FPrevWasWhitespace)) then begin
    FWriter.PutBreak;
  end;

  while (FWriter.column < indent_spaces) do begin
    FWriter.put(' ');
  end;

  FPrevWasWhitespace := True;
  FPrevWasIndentation := True;
end;

procedure TYamlEmitter.WriteIndicator(const AIndicator: string; ANeedWhitespace: boolean;
  AIsWhitespace: boolean; AIsIndentation: boolean);
var
  i: Integer;
begin
  if (ANeedWhitespace and not FPrevWasWhitespace) then begin
    FWriter.put(' ');
  end;

  i := 1;
  while i <= Length(AIndicator) do begin
    FWriter.WriteAt(AIndicator, i);
    Inc(i, WidthAt(AIndicator, i));
  end;

  FPrevWasWhitespace := AIsWhitespace;
  FPrevWasIndentation := (FPrevWasIndentation and AIsIndentation);
end;

procedure TYamlEmitter.WriteAnchor(const AValue: string);
var
  i: Integer;
begin
  i := 1;
  while i <= Length(AValue) do begin
    FWriter.WriteAt(AValue, i);
    Inc(i, WidthAt(AValue, i));
  end;

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WriteTagHandle(const AValue: string);
var
  i: Integer;
begin
  if not FPrevWasWhitespace then begin
    FWriter.put(' ');
  end;

  i := 1;
  while i <= Length(AValue) do begin
    FWriter.WriteAt(AValue, i);
    Inc(i, WidthAt(AValue, i));
  end;

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WriteTagContent(const AValue: string; ANeedWhitespace: Boolean);
const
  hex_digits: string = '0123456789ABCDEF';
var
  i: Integer;
  byte_count: Integer;
  aByte: Byte;
begin
  if (ANeedWhitespace and not FPrevWasWhitespace) then begin
    FWriter.put(' ');
  end;

  i := 1;
  while (i <= Length(AValue)) do begin
    if (IsAlphaAt(AValue, i) or
      (AValue[i] in [';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '_',
      '.', '~', '*', '''', '(', ')', '[', ']'])) then begin
      FWriter.put(AValue[i]);
      Inc(i);
    end
    else begin
      byte_count := WidthAt(AValue, i);
      while (byte_count > 0) do begin
        aByte := Ord(AValue[i]);
        Inc(i);
        FWriter.put('%');
        FWriter.put(hex_digits[aByte shr 4]);
        FWriter.put(hex_digits[aByte and $0F]);
        Dec(byte_count);
      end;
    end;
  end;

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WritePlainScalar(const AValue: string; AAllowBreaks: Boolean);
var
  i: Integer;
  spaces: Boolean;
  breaks: Boolean;
begin
  spaces := False;
  breaks := False;

  //**
  // * Avoid trailing spaces for empty values in block mode.
  // * In flow mode, we still want the space to prevent ambiguous things
  // * like {a:}.
  // * Currently, the emitter forbids any plain empty scalar in flow mode
  // * (e.g. it outputs {a: ''} instead), so emitter->FFlowLevel will
  // * never be true here.
  // * But if the emitter is ever changed to allow emitting empty values,
  // * the check for FFlowLevel is already here.
  // */
  if (not FPrevWasWhitespace and ((Length(AValue) > 0) or (FFlowLevel > 0))) then begin
    FWriter.put(' ');
  end;

  i := 1;
  while i <= Length(AValue) do begin
    if (IsSpaceAt(AValue, i)) then begin
      if (AAllowBreaks and (not spaces)
        and (FWriter.column > FBestWidth)
        and (not IsSpaceAt(AValue, i + 1))) then begin
        WriteIndent;
        Inc(i, WidthAt(AValue, i));
      end
      else begin
        FWriter.WriteAt(AValue, i);
        Inc(i, WidthAt(AValue, i));
      end;
      spaces := True;
    end
    else
    if (IsBreakAt(AValue, i)) then begin
      if ((not breaks) and (AValue[i] = #$0A)) then begin
        FWriter.PutBreak;
      end;
      FWriter.WriteBreakAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      FPrevWasIndentation := True;
      breaks := True;
    end
    else begin
      if (breaks) then begin
        WriteIndent;
      end;
      FWriter.WriteAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      FPrevWasIndentation := False;
      spaces := False;
      breaks := False;
    end;
  end;

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WriteSingleQuotedScalar(const AValue: string; AAllowBreaks: Boolean);
var
  i: Integer;
  spaces: boolean;
  breaks: boolean;
begin
  spaces := False;
  breaks := False;
  WriteIndicator('''', True, False, False);

  i := 1;
  while i <= Length(AValue) do begin
    if (IsSpaceAt(AValue, i)) then begin
      if (AAllowBreaks and (not spaces)
        and (FWriter.column > FBestWidth)
        and (i <> 1)
        and (i <> Length(AValue))
        and (not IsSpaceAt(AValue, i + 1))) then begin
        WriteIndent;
        Inc(i, WidthAt(AValue, i));
      end
      else begin
        FWriter.WriteAt(AValue, i);
        Inc(i, WidthAt(AValue, i));
      end;
      spaces := True;
    end
    else
    if (IsBreakAt(AValue, i)) then begin
      if (not breaks) and (AValue[i] = #$0A) then begin
        FWriter.PutBreak;
      end;
      FWriter.WriteBreakAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      FPrevWasIndentation := True;
      breaks := True;
    end
    else begin
      if (breaks) then begin
        WriteIndent;
      end;
      if (AValue[i] = '''') then begin
        FWriter.put('''');
      end;
      FWriter.WriteAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      FPrevWasIndentation := False;
      spaces := False;
      breaks := False;
    end;
  end;

  if (breaks) then begin
    WriteIndent;
  end;

  WriteIndicator('''', False, False, False);

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WriteDoubleQuotedScalar(const AValue: string; AAllowBreaks: Boolean);
const
  hex_digits: string = '0123456789ABCDEF';
var
  i: Integer;
  spaces: Boolean;
  codepoint: UInt32;
  Width: Integer;
  k: Integer;
  digit: Integer;
begin
  spaces := False;

  WriteIndicator('"', True, False, False);

  i := 1;
  while i <= Length(AValue) do begin
    if (not IsPrintableAt(AValue, i)) or (not FAllowUnescapedUnicode and not IsAsciiAt(AValue, i))
      or IsBOMAt(AValue, i) or IsBreakAt(AValue, i)
      or (AValue[i] = '"') or (AValue[i] = '\') then begin
      codepoint := CodepointAt(AValue, i);
      Inc(i, WidthAt(AValue, i));

      FWriter.put('\');

      case codepoint of
        $00:
          FWriter.Put('0');

        $07:
          FWriter.Put('a');

        $08:
          FWriter.Put('b');

        $09:
          FWriter.Put('t');

        $0A:
          FWriter.Put('n');

        $0B:
          FWriter.Put('v');

        $0C:
          FWriter.Put('f');

        $0D:
          FWriter.Put('r');

        $1B:
          FWriter.Put('e');

        $22:
          FWriter.Put('"');

        $5C:
          FWriter.Put('\');

        $85:
          FWriter.Put('N');

        $A0:
          FWriter.Put('_');

        $2028:
          FWriter.Put('L');

        $2029:
          FWriter.Put('P');
        else
          if (codepoint <= $FF) then begin
            FWriter.Put('x');
            Width := 2;
          end
          else
          if (codepoint <= $FFFF) then begin
            FWriter.Put('u');
            Width := 4;
          end
          else begin
            FWriter.Put('U');
            Width := 8;
          end;
          k := (Width - 1) * 4;
          while k >= 0 do begin
            digit := (codepoint shr k) and $0F;
            FWriter.Put(hex_digits[digit + 1]);
            Dec(k, 4);
          end;
      end;
      spaces := False;
    end
    else
    if IsSpaceAt(AValue, i) then begin
      if AAllowBreaks and (not spaces)
        and (FWriter.column > FBestWidth)
        and (i <> 1)
        and (i <> Length(AValue)) then begin
        WriteIndent;
        if IsSpaceAt(AValue, i + 1) then begin
          FWriter.put('\');
        end;
        Inc(i, WidthAt(AValue, i));
      end
      else begin
        FWriter.WriteAt(AValue, i);
        Inc(i, WidthAt(AValue, i));
      end;
      spaces := True;
    end
    else begin
      FWriter.WriteAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      spaces := False;
    end;
  end;

  WriteIndicator('"', False, False, False);

  FPrevWasWhitespace := False;
  FPrevWasIndentation := False;
end;

procedure TYamlEmitter.WriteBlockScalarHints(const AValue: string);
var
  indent_hint: string;
  chomp_hint: string;
  i: Integer;
begin
  if IsSpaceAt(AValue, 1) or IsBreakAt(AValue, 1) then begin
    indent_hint := IntToStr(FBestIndent);
    WriteIndicator(indent_hint, False, False, False);
  end;

  chomp_hint := '';
  FExplicitDocEndRequired := 0;

  if Length(AValue) = 0 then begin
    chomp_hint := '-';
  end
  else begin
    i := Length(AValue);
    while (Ord(AValue[i]) and $C0) = $80 do
      Dec(i);
    if not IsBreakAt(AValue, i) then begin
      chomp_hint := '-';
    end
    else
    if i = 1 then begin
      chomp_hint := '+';
      FExplicitDocEndRequired := 2;
    end
    else begin
      Dec(i);
      while (Ord(AValue[i]) and $C0) = $80 do
        Dec(i);
      if IsBreakAt(AValue, i) then begin
        chomp_hint := '+';
        FExplicitDocEndRequired := 2;
      end;
    end;
  end;

  if (Length(chomp_hint) > 0) then begin
    WriteIndicator(chomp_hint, False, False, False);
  end;
end;

procedure TYamlEmitter.WriteLiteralScalar(const AValue: string);
var
  breaks: boolean;
  i: Integer;
begin
  breaks := True;

  WriteIndicator('|', True, False, False);
  WriteBlockScalarHints(AValue);
  FWriter.PutBreak;
  FPrevWasIndentation := True;
  FPrevWasWhitespace := True;

  i := 1;
  while i <= Length(AValue) do begin
    if IsBreakAt(AValue, i) then begin
      FWriter.WriteBreakAt(AValue, i);
      FPrevWasIndentation := True;
      breaks := True;
    end
    else begin
      if (breaks) then begin
        WriteIndent;
      end;
      FWriter.WriteAt(AValue, i);
      FPrevWasIndentation := False;
      breaks := False;
    end;
    Inc(i, WidthAt(AValue, i));
  end;
end;

procedure TYamlEmitter.WriteFoldedScalar(const AValue: string);
var
  breaks: boolean;
  leading_spaces: boolean;
  i: integer;
  k: integer;
begin
  breaks := True;
  leading_spaces := True;

  WriteIndicator('>', True, False, False);
  WriteBlockScalarHints(AValue);
  FWriter.PutBreak;
  FPrevWasIndentation := True;
  FPrevWasWhitespace := True;

  i := 1;
  while i <= Length(AValue) do begin
    if IsBreakAt(AValue, i) then begin
      if (not breaks) and (not leading_spaces) and (AValue[i] = #$0A) then begin
        k := 0;
        while IsBreakAt(AValue, i + k) do begin
          Inc(k, WidthAt(AValue, i + k));
        end;
        if IsBlankZAt(AValue, i + k) then begin
          FWriter.PutBreak;
        end;
      end;
      FWriter.WriteBreakAt(AValue, i);
      Inc(i, WidthAt(AValue, i));
      FPrevWasIndentation := True;
      breaks := True;
    end
    else begin
      if (breaks) then begin
        WriteIndent;
        leading_spaces := IsBlankAt(AValue, i);
      end;
      if (not breaks) and IsSpaceAt(AValue, i) and (not isSpaceAt(AValue, i + 1))
        and (FWriter.column > FBestWidth) then begin
        WriteIndent;
        Inc(i, WidthAt(AValue, i));
      end
      else begin
        FWriter.WriteAt(AValue, i);
        Inc(i, WidthAt(AValue, i));
      end;
      FPrevWasIndentation := False;
      breaks := False;
    end;
  end;
end;

function TYamlEmitter.CheckEmptyDocument: Boolean;
begin
  Result := False;
end;

function TYamlEmitter.CheckEmptySequence: Boolean;
begin
  if FEvents.Count < 2 then
    Exit(False);

  Result := (FEvents[0] is TSequenceStartEvent) and (FEvents[1] is TSequenceEndEvent);
end;

function TYamlEmitter.CheckEmptyMapping: Boolean;
begin
  if FEvents.Count < 2 then
    Exit(False);

  Result := (FEvents[0] is TMappingStartEvent) and (FEvents[1] is TMappingEndEvent);
end;

function TYamlEmitter.CheckSimpleKey: Boolean;
var
  event: TYamlEvent;
  key_length: Integer;
begin
  event := FEvents.Peek;
  key_length := 0;

  if (event is TAliasEvent) then begin
    key_length := Length(FAnchorData.FAnchor);
  end
  else
  if (event is TScalarEvent) then begin
    if (FScalarData.FIsMultiline) then
      Exit(False);
    key_length := Length(FAnchorData.FAnchor)
      + Length(FTagData.FHandle)
      + Length(FTagData.FSuffix)
      + Length(FScalarData.FValue);
  end
  else
  if (event is TSequenceStartEvent) then begin
    if not CheckEmptySequence then
      Exit(False);
    key_length := Length(FAnchorData.FAnchor)
      + Length(FTagData.FHandle)
      + Length(FTagData.FSuffix);
  end
  else
  if (event is TMappingStartEvent) then begin
    if not CheckEmptyMapping then
      Exit(False);
    key_length := Length(FAnchorData.FAnchor)
      + Length(FTagData.FHandle)
      + Length(FTagData.FSuffix);
  end
  else
    Exit(False);

  if (key_length > 128) then
    Exit(False);

  Exit(True);
end;

function TYamlEmitter.SelectScalarStyle(AEvent: TScalarEvent): TYamlScalarStyle;
var
  style: TYamlScalarStyle;
  no_tag: Boolean;
begin
  style := AEvent.scalarStyle;
  no_tag := (Length(FTagData.FHandle) = 0) and (Length(FTagData.FSuffix) = 0);

  if no_tag and (not AEvent.plainImplicit)
    and (not AEvent.quotedImplicit) then begin
    SetEmitterError('neither tag nor implicit flags are specified');
  end;

  if (style = yssAnyStyle) then
    style := yssPlainScalar;

  if (FCanonical) then
    style := yssDoubleQuotedScalar;

  if (FIsSimpleKeyContext and FScalarData.FIsMultiline) then
    style := yssDoubleQuotedScalar;

  if (style = yssPlainScalar) then begin
    if (((FFlowLevel > 0) and (not FScalarData.FFlowPlainAllowed))
      or ((FFlowLevel = 0) and (not FScalarData.FBlockPlainAllowed))) then
      style := yssSingleQuotedScalar;
    if (Length(FScalarData.FValue) = 0)
      and ((FFlowLevel > 0) or FIsSimpleKeyContext) then
      style := yssSingleQuotedScalar;
    if (no_tag and not AEvent.plainImplicit) then
      style := yssSingleQuotedScalar;
  end;

  if (style = yssSingleQuotedScalar) then begin
    if (not FScalarData.FSingleQuotedAllowed) then
      style := yssDoubleQuotedScalar;
  end;

  if (style = yssLiteralScalar) or (style = yssFoldedScalar) then begin
    if (not FScalarData.FBlockAllowed)
      or (FFlowLevel > 0) or FIsSimpleKeyContext then
      style := yssDoubleQuotedScalar;
  end;

  if no_tag and (not AEvent.quotedImplicit)
    and (style <> yssPlainScalar) then begin
    FTagData.FHandle := '!';
  end;

  Exit(style);
end;

constructor TYamlEmitter.Create;
begin
  inherited;

  FWriter := TYamlWriter.Create;

  FStates := TStack<TYamlEmitterState>.Create;
  FEvents := TOTQueue<TYamlEvent>.Create;
  FIndents := TStack<Integer>.Create;

  FAnchors := THashSet<String>.Create;

  SetLength(FTagDirectives, 0);
end;

destructor TYamlEmitter.Destroy;
begin
  FWriter.Free;
  FStates.Free;
  FEvents.Free;
  FIndents.Free;
  FAnchors.Free;
  inherited;
end;

procedure TYamlEmitter.SetOutput(AStream: TStream);
begin
  FWriter.SetOutput(AStream);
end;

procedure TYamlEmitter.SetCanonical(ACanonical: Boolean);
begin
  FCanonical := ACanonical;
end;


procedure TYamlEmitter.SetUnicode(AAllowUnescapedUnicode: Boolean);
begin
  FAllowUnescapedUnicode := AAllowUnescapedUnicode;
end;

procedure TYamlEmitter.SetIndent(AIndent: Integer);
begin
  if (1 < AIndent) and (AIndent < 10) then
    FBestIndent := AIndent
  else
    FBestIndent := 2;
end;

procedure TYamlEmitter.SetWidth(AWidth: Integer);
begin
  if (AWidth > 0) then
    FBestWidth := AWidth
  else
    FBestWidth := -1;
end;

procedure TYamlEmitter.SetBreak(ABreak: TYamlBreak);
begin
  FLineBreak := ABreak;
  FWriter.SetBreak(ABreak);
end;

procedure TYamlEmitter.StreamStartEvent;
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TStreamStartEvent.Create(FEncoding, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.StreamEndEvent;
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TStreamEndEvent.Create(mark, mark);
  emit(event);
end;

procedure TYamlEmitter.DocumentStartEvent(AVersionDirective: TYamlVersionDirective;
  ATagDirectives: TYamlTagDirectives; AImplicit: boolean);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TDocumentStartEvent.Create(AVersionDirective, ATagDirectives, AImplicit, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.DocumentEndEvent(AImplicit: Boolean);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TDocumentEndEvent.Create(AImplicit, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.SequenceStartEvent(const AAnchor, ATag: String; AImplicit: Boolean;
  AStyle: TYamlSequenceStyle);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TSequenceStartEvent.Create(AAnchor, ATag, AImplicit, AStyle, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.SequenceEndEvent;
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TSequenceEndEvent.Create(mark, mark);
  emit(event);
end;

procedure TYamlEmitter.MappingStartEvent(const AAnchor, ATag: String; AImplicit: Boolean;
  AStyle: TYamlMappingStyle);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TMappingStartEvent.Create(AAnchor, ATag, AImplicit, AStyle, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.MappingEndEvent;
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TMappingEndEvent.Create(mark, mark);
  emit(event);
end;

procedure TYamlEmitter.ScalarEvent(const AAnchor, ATag, AValue: String; APlainImplicit,
  AQuotedImplicit: Boolean; AStyle: TYamlScalarStyle);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TScalarEvent.Create(AAnchor, ATag, AValue, APlainImplicit, AQuotedImplicit,
    AStyle, mark, mark);
  emit(event);
end;

procedure TYamlEmitter.AliasEvent(const AAnchor: String);
var
  mark: TYamlMark;
  event: TYamlEvent;
begin
  mark.Column := 0;
  mark.Line := 0;
  mark.Index := 0;
  event := TAliasEvent.Create(AAnchor, mark, mark);
  emit(event);
end;

function TYamlEmitter.HasAnchor(const AAnchor: String): Boolean;
begin
  Result := FAnchors.Contains(AAnchor);
end;

end.
