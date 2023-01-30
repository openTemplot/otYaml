unit otYamlParser;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  otYaml,
  otStack,
  otYamlEvent,
  otYamlToken,
  otYamlScanner;


type

  { EYamlParserError }

  EYamlParserError = class(Exception)
  private
    FMark: TYamlMark;

  public
    constructor Create(const AProblem: String; AMark: TYamlMark);
  end;

  EYamlParserErrorContext = class(Exception)
  private
    FContext: String;
    FContextMark: TYamlMark;
    FProblemMark: TYamlMark;

  public
    constructor Create(const AContext: String; AContextMark: TYamlMark;
      const AProblem: String; AProblemMark: TYamlMark);

    property problemMark: TYamlMark Read FProblemMark;
  end;

  { TYamlParser }

  TYamlParser = class
  private
    (** indicates an error occurred on a previous call to the parser *)
    FError: Boolean;

    (**
     * @name Reader stuff
     * @{
     *)

    FScanner: TYamlScanner;

    (**
     * @name Parser stuff
     * @{
     *)

    (** The parser states stack. *)
    states: TOTStack<TYamlParserState>;

    (** The current parser state. *)
    state: TYamlParserState;

    (** The stack of marks. *)
    marks: TOTStack<TYamlMark>;

    (** The list of TAG directives. *)
    tagDirectives: TYamlTagDirectives;

    procedure SetParserError(const AProblem: String; AMark: TYamlMark);
    procedure SetParserErrorContext(const AContext: String; AContextMark: TYamlMark;
      const AProblem: String; AProblemMark: TYamlMark);

    function StateMachine: TYamlEvent;
    function ParseStreamStart: TYamlEvent;
    function ParseDocumentStart(AImplicit: Boolean): TYamlEvent;
    function ParseDocumentEnd: TYamlEvent;
    function ParseDocumentContent: TYamlEvent;
    function ParseNode(ABlock: Boolean; AIndentlessSequence: Boolean): TYamlEvent;
    function ParseBlockSequenceEntry(AFirst: Boolean): TYamlEvent;
    function ParseIndentlessSequenceEntry: TYamlEvent;
    function ParseBlockMappingKey(AFirst: Boolean): TYamlEvent;
    function ParseBlockMappingValue: TYamlEvent;
    function ParseFlowSequenceEntry(AFirst: Boolean): TYamlEvent;
    function ParseBlockSequenceEntryMappingKey: TYamlEvent;
    function ParseFlowSequenceEntryMappingValue: TYamlEvent;
    function ParseFlowSequenceEntryMappingEnd: TYamlEvent;
    function ParseFlowMappingKey(AFirst: Boolean): TYamlEvent;
    function ParseFlowMappingValue(AEmpty: Boolean): TYamlEvent;

    procedure ProcessDirectives(var AVersionDirective: TYamlVersionDirective);
    function ProcessEmptyScalar(AMark: TYamlMark): TYamlEvent;

    procedure AppendTagDirective(const AValue: TYamlTagDirective;
      AAllowDuplicates: Boolean; AMark: TYamlMark);

  public
    constructor Create;
    destructor Destroy; override;

    procedure SetInput(AStream: TStream);
    procedure SetEncoding(AEncoding: TYamlEncoding);

    function Parse: TYamlEvent;

  end;

implementation

{ EYamlParserError }

constructor EYamlParserError.Create(const AProblem: String; AMark: TYamlMark);
begin
  inherited Create(AProblem);
  FMark := AMark;
end;

constructor EYamlParserErrorContext.Create(const AContext: String; AContextMark: TYamlMark;
  const AProblem: String; AProblemMark: TYamlMark);
begin
  inherited Create(AProblem);
  FContext := AContext;
  FContextMark := AContextMark;
  FProblemMark := AProblemMark;
end;

{*
 * The parser implements the following grammar:
 *
 * stream               ::= STREAM-START implicit_document? explicit_document* STREAM-END
 * implicit_document    ::= block_node DOCUMENT-END*
 * explicit_document    ::= DIRECTIVE* DOCUMENT-START block_node? DOCUMENT-END*
 * block_node_or_indentless_sequence    ::=
 *                          ALIAS
 *                          | properties (block_content | indentless_block_sequence)?
 *                          | block_content
 *                          | indentless_block_sequence
 * block_node           ::= ALIAS
 *                          | properties block_content?
 *                          | block_content
 * flow_node            ::= ALIAS
 *                          | properties flow_content?
 *                          | flow_content
 * properties           ::= TAG ANCHOR? | ANCHOR TAG?
 * block_content        ::= block_collection | flow_collection | SCALAR
 * flow_content         ::= flow_collection | SCALAR
 * block_collection     ::= block_sequence | block_mapping
 * flow_collection      ::= flow_sequence | flow_mapping
 * block_sequence       ::= BLOCK-SEQUENCE-START (BLOCK-ENTRY block_node?)* BLOCK-END
 * indentless_sequence  ::= (BLOCK-ENTRY block_node?)+
 * block_mapping        ::= BLOCK-MAPPING_START
 *                          ((KEY block_node_or_indentless_sequence?)?
 *                          (VALUE block_node_or_indentless_sequence?)?)*
 *                          BLOCK-END
 * flow_sequence        ::= FLOW-SEQUENCE-START
 *                          (flow_sequence_entry FLOW-ENTRY)*
 *                          flow_sequence_entry?
 *                          FLOW-SEQUENCE-END
 * flow_sequence_entry  ::= flow_node | KEY flow_node? (VALUE flow_node?)?
 * flow_mapping         ::= FLOW-MAPPING-START
 *                          (flow_mapping_entry FLOW-ENTRY)*
 *                          flow_mapping_entry?
 *                          FLOW-MAPPING-END
 * flow_mapping_entry   ::= flow_node | KEY flow_node? (VALUE flow_node?)?
 *}


{ TYamlParser }

procedure TYamlParser.SetParserError(const AProblem: String; AMark: TYamlMark);
begin
  raise EYamlParserError.Create(AProblem, AMark);
end;

procedure TYamlParser.SetParserErrorContext(const AContext: String; AContextMark: TYamlMark;
  const AProblem: String; AProblemMark: TYamlMark);
begin
  raise EYamlParserErrorContext.Create(AContext, AContextMark, AProblem, AProblemMark);
end;

function TYamlParser.StateMachine: TYamlEvent;
begin
  case state of
    YAML_PARSE_STREAM_START_STATE:
      Exit(ParseStreamStart);

    YAML_PARSE_IMPLICIT_DOCUMENT_START_STATE:
      Exit(ParseDocumentStart(True));

    YAML_PARSE_DOCUMENT_START_STATE:
      Exit(ParseDocumentStart(False));

    YAML_PARSE_DOCUMENT_CONTENT_STATE:
      Exit(ParseDocumentContent);

    YAML_PARSE_DOCUMENT_END_STATE:
      Exit(ParseDocumentEnd);

    YAML_PARSE_BLOCK_NODE_STATE:
      Exit(ParseNode(True, False));

    YAML_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE:
      Exit(ParseNode(True, True));

    YAML_PARSE_FLOW_NODE_STATE:
      Exit(ParseNode(False, False));

    YAML_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE:
      Exit(ParseBlockSequenceEntry(True));

    YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE:
      Exit(ParseBlockSequenceEntry(False));

    YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE:
      Exit(ParseIndentlessSequenceEntry);

    YAML_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE:
      Exit(ParseBlockMappingKey(True));

    YAML_PARSE_BLOCK_MAPPING_KEY_STATE:
      Exit(ParseBlockMappingKey(False));

    YAML_PARSE_BLOCK_MAPPING_VALUE_STATE:
      Exit(ParseBlockMappingValue);

    YAML_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE:
      Exit(ParseFlowSequenceEntry(True));

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE:
      Exit(ParseFlowSequenceEntry(False));

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE:
      Exit(ParseBlockSequenceEntryMappingKey);

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE:
      Exit(ParseFlowSequenceEntryMappingValue);

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE:
      Exit(ParseFlowSequenceEntryMappingEnd);

    YAML_PARSE_FLOW_MAPPING_FIRST_KEY_STATE:
      Exit(ParseFlowMappingKey(True));

    YAML_PARSE_FLOW_MAPPING_KEY_STATE:
      Exit(ParseFlowMappingKey(False));

    YAML_PARSE_FLOW_MAPPING_VALUE_STATE:
      Exit(ParseFlowMappingValue(False));

    YAML_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE:
      Exit(ParseFlowMappingValue(True));
    else
      assert(False);      //* Invalid state. */
  end;

  Exit(nil);
end;

function TYamlParser.ParseStreamStart: TYamlEvent;
var
  token: TYamlToken;
  ssToken: TStreamStartToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if not (token is TStreamStartToken) then
    SetParserError('did not find expected <stream-start>', token.startMark);

  ssToken := TStreamStartToken(token);

  state := YAML_PARSE_IMPLICIT_DOCUMENT_START_STATE;
  Result := TStreamStartEvent.Create(ssToken.encoding, ssToken.startMark, ssToken.startMark);
  FScanner.SkipToken;
end;

function TYamlParser.ParseDocumentStart(AImplicit: Boolean): TYamlEvent;
var
  token: TYamlToken;
  versionDirective: TYamlVersionDirective;
  startMark: TYamlMark;
  endMark: TYamlMark;
  tagDirectives: TYamlTagDirectives;
begin
  versionDirective.Initialize;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  // Parse extra document end indicators.

  if not AImplicit then begin
    while (token is TDocumentEndToken) do begin
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
    end;
  end;

  // Parse an AImplicit document.

  if AImplicit and (not (token is TVersionDirectiveToken)) and
    (not (token is TTagDirectiveToken)) and
    (not (token is TDocumentStartToken)) and
    (not (token is TStreamEndToken)) then begin
    ProcessDirectives(versionDirective);
    states.push(YAML_PARSE_DOCUMENT_END_STATE);
    state := YAML_PARSE_BLOCK_NODE_STATE;

    versionDirective.Initialize;
    Exit(TDocumentStartEvent.Create(versionDirective, nil, True,
      token.startMark, token.endMark));
  end

  // Parse an explicit document.

  else
  if not (token is TStreamEndToken) then begin
    startMark := token.startMark;
    SetLength(tagDirectives, 0);
    ProcessDirectives(versionDirective);
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if not (token is TDocumentStartToken) then begin
      SetParserError('did not find expected <document start>', token.startMark);
    end;
    states.Push(YAML_PARSE_DOCUMENT_END_STATE);
    state := YAML_PARSE_DOCUMENT_CONTENT_STATE;
    endMark := token.endMark;

    Result := TDocumentStartEvent.Create(versionDirective, tagDirectives, False,
      startMark, endMark);
    FScanner.SkipToken;
    Exit;
  end

  // Parse the stream end. */

  else begin
    state := YAML_PARSE_END_STATE;
    Result := TStreamEndEvent.Create(token.startMark, token.endMark);
    FScanner.SkipToken;
    Exit;
  end;
end;

function TYamlParser.ParseDocumentEnd: TYamlEvent;
var
  token: TYamlToken;
  startMark: TYamlMark;
  endMark: TYamlMark;
  implicit: Boolean;
begin
  implicit := True;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  startMark := token.startMark;
  endMark := token.startMark;

  if (token is TDocumentEndToken) then begin
    endMark := token.endMark;
    FScanner.SkipToken;
    implicit := False;
  end;

  SetLength(tagDirectives, 0);

  state := YAML_PARSE_DOCUMENT_START_STATE;
  Result := TDocumentEndEvent.Create(implicit, startMark, endMark);
end;

function TYamlParser.ParseDocumentContent: TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TVersionDirectiveToken) or
    (token is TTagDirectiveToken) or
    (token is TDocumentStartToken) or
    (token is TDocumentEndToken) or
    (token is TStreamEndToken) then begin
    state := states.Pop;
    Result := ProcessEmptyScalar(token.startMark);
  end
  else begin
    Result := ParseNode(True, False);
  end;
end;

function TYamlParser.ParseNode(ABlock: Boolean; AIndentlessSequence: Boolean): TYamlEvent;
var
  token: TYamlToken;
  anchor: String;
  hasTag: Boolean;
  tag: String;
  tagHandle: String;
  tagSuffix: String;
  startMark: TYamlMark;
  endMark: TYamlMark;
  tagMark: TYamlMark;
  implicit: Boolean;
  tagDirecvtive: TYamlTagDirective;
  plainImplicit: Boolean;
  quotedImplicit: Boolean;
begin
  hasTag := False;
  tag := '';

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TAliasToken) then begin
    state := states.Pop;
    Result := TAliasEvent.Create(TAliasToken(token).Value, token.startMark, token.endMark);
    FScanner.SkipToken;
    Exit;
  end

  else begin
    startMark := token.startMark;
    endMark := token.startMark;

    if (token is TAnchorToken) then begin
      anchor := TAnchorToken(token).Value;
      startMark := token.startMark;
      endMark := token.endMark;
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
      if (token is TTagToken) then begin
        hasTag := True;
        tagHandle := TTagToken(token).handle;
        tagSuffix := TTagToken(token).suffix;
        tagMark := token.startMark;
        endMark := token.endMark;
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end;
    end
    else
    if (token is TTagToken) then begin
      hasTag := True;
      tagHandle := TTagToken(token).handle;
      tagSuffix := TTagToken(token).suffix;
      startMark := token.startMark;
      tagMark := token.startMark;
      endMark := token.endMark;
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
      if (token is TAnchorToken) then begin
        anchor := TAnchorToken(token).Value;
        endMark := token.endMark;
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end;
    end;

    if hasTag then begin
      if (tagHandle = '') then begin
        tag := tagSuffix;
      end
      else begin
        for tagDirecvtive in tagDirectives do begin
          if (tagDirecvtive.Handle = tagHandle) then begin
            tag := tagDirecvtive.Prefix + tagSuffix;
            break;
          end;
        end;
        if (tag = '') then
          SetParserErrorContext('while parsing a node', startMark,
            'found undefined tag handle', tagMark);
      end;
    end;

    implicit := (not hasTag) or (tag = '');
    if AIndentlessSequence and (token is TBlockEntryToken) then begin
      endMark := token.endMark;
      state := YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE;
      Result := TSequenceStartEvent.Create(anchor, tag, implicit,
        ysqBlockSequence, startMark, endMark);
      Exit;
    end
    else begin
      if (token is TScalarToken) then begin
        plainImplicit := False;
        quotedImplicit := False;
        endMark := token.endMark;
        if ((TScalarToken(token).scalarStyle = yssPlainScalar) and (not hasTag))
          or (hasTag and (tag = '!')) then begin
          plainImplicit := True;
        end
        else
        if (not hasTag) then begin
          quotedImplicit := True;
        end;
        state := states.Pop;
        Result := TScalarEvent.Create(anchor, tag,
          TScalarToken(token).Value,
          plainImplicit, quotedImplicit,
          TScalarToken(token).scalarStyle, startMark, endMark);
        FScanner.SkipToken;
        Exit;
      end
      else
      if (token is TFlowSequenceStartToken) then begin
        endMark := token.endMark;
        state := YAML_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE;
        Result := TSequenceStartEvent.Create(anchor, tag, implicit,
          ysqFlowSequence, startMark, endMark);
        Exit;
      end
      else
      if (token is TFlowMappingStartToken) then begin
        endMark := token.endMark;
        state := YAML_PARSE_FLOW_MAPPING_FIRST_KEY_STATE;
        Result := TMappingStartEvent.Create(anchor, tag, implicit,
          ympFlowMapping, startMark, endMark);
        Exit;
      end
      else
      if (ABlock and (token is TBlockSequenceStartToken)) then begin
        endMark := token.endMark;
        state := YAML_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE;
        Result := TSequenceStartEvent.Create(anchor, tag, implicit,
          ysqBlockSequence, startMark, endMark);
        Exit;
      end
      else
      if (ABlock and (token is TBlockMappingStartToken)) then begin
        endMark := token.endMark;
        state := YAML_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE;
        Result := TMappingStartEvent.Create(anchor, tag, implicit,
          ympBlockMapping, startMark, endMark);
        Exit;
      end
      else
      if (Length(anchor) > 0) or (Length(tag) > 0) then begin
        state := states.Pop;
        Result := TScalarEvent.Create(anchor, tag, '',
          implicit, False, yssPlainScalar,
          startMark, endMark);
        Exit;
      end
      else begin
        if ABlock then
          SetParserErrorContext(
            'while parsing a block node', startMark,
            'did not find expected node content', token.startMark)
        else
          SetParserErrorContext(
            'while parsing a flow node', startMark,
            'did not find expected node content', token.startMark);
      end;
    end;
  end;
end;

function TYamlParser.ParseBlockSequenceEntry(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.startMark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TBlockEntryToken) then begin
    mark := token.endMark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TBlockEntryToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE);
      Exit(ParseNode(True, False));
    end
    else begin
      state := YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE;
      Exit(ProcessEmptyScalar(mark));
    end;
  end

  else
  if (token is TBlockEndToken) then begin
    state := states.Pop;
    marks.Pop;
    Result := TSequenceEndEvent.Create(token.startMark, token.endMark);
    FScanner.SkipToken;
    Exit;
  end
  else begin
    SetParserErrorContext(
      'while parsing a block collection', marks.Pop,
      'did not find expected "-" indicator', token.startMark);
  end;
end;

function TYamlParser.ParseIndentlessSequenceEntry: TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TBlockEntryToken) then begin
    mark := token.endMark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TBlockEntryToken)) and
      (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE);
      Exit(ParseNode(True, False));
    end
    else begin
      state := YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE;
      Exit(ProcessEmptyScalar(mark));
    end;
  end

  else begin
    state := states.Pop;
    Result := TSequenceEndEvent.Create(token.startMark, token.startMark);
    Exit;
  end;
end;

function TYamlParser.ParseBlockMappingKey(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.startMark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TKeyToken) then begin
    mark := token.endMark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_MAPPING_VALUE_STATE);
      Exit(ParseNode(True, True));
    end
    else begin
      state := YAML_PARSE_BLOCK_MAPPING_VALUE_STATE;
      Exit(ProcessEmptyScalar(mark));
    end;
  end

  else
  if (token is TBlockEndToken) then begin
    state := states.Pop;
    marks.Pop;
    Result := TMappingEndEvent.Create(token.startMark, token.endMark);
    FScanner.SkipToken;
    Exit;
  end

  else begin
    SetParserErrorContext(
      'while parsing a block mapping', marks.Pop,
      'did not find expected key', token.startMark);
  end;
end;

function TYamlParser.ParseBlockMappingValue: TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TValueToken) then begin
    mark := token.endMark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_MAPPING_KEY_STATE);
      Exit(ParseNode(True, True));
    end
    else begin
      state := YAML_PARSE_BLOCK_MAPPING_KEY_STATE;
      Exit(ProcessEmptyScalar(mark));
    end;
  end

  else begin
    state := YAML_PARSE_BLOCK_MAPPING_KEY_STATE;
    Exit(ProcessEmptyScalar(token.startMark));
  end;

end;

function TYamlParser.ParseFlowSequenceEntry(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.startMark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if not (token is TFlowSequenceEndToken) then begin
    if (not AFirst) then begin
      if (token is TFlowEntryToken) then begin
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end
      else begin
        SetParserErrorContext(
          'while parsing a flow sequence', marks.Pop,
          'did not find expected "," or "]"', token.startMark);
      end;
    end;

    if (token is TKeyToken) then begin
      state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE;
      Result := TMappingStartEvent.Create('', '',
        True, ympFlowMapping,
        token.startMark, token.endMark);
      FScanner.SkipToken;
      Exit;
    end

    else
    if not (token is TFlowSequenceEndToken) then begin
      states.Push(YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE);
      Exit(ParseNode(False, False));
    end;
  end;

  state := states.Pop;
  marks.Pop;
  Result := TSequenceEndEvent.Create(token.startMark, token.endMark);
  FScanner.SkipToken;
  Exit;
end;

function TYamlParser.ParseBlockSequenceEntryMappingKey: TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (not (token is TValueToken)) and (not (token is TFlowEntryToken))
    and (not (token is TFlowSequenceEndToken)) then begin
    states.Push(YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE);
    Exit(ParseNode(False, False));
  end
  else begin
    mark := token.endMark;
    FScanner.SkipToken;
    state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE;
    Exit(ProcessEmptyScalar(mark));
  end;
end;

function TYamlParser.ParseFlowSequenceEntryMappingValue: TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TValueToken) then begin
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TFlowEntryToken))
      and (not (token is TFlowSequenceEndToken)) then begin
      states.Push(YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE);
      Exit(ParseNode(False, False));
    end;
  end;
  state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE;
  Exit(ProcessEmptyScalar(token.startMark));
end;

function TYamlParser.ParseFlowSequenceEntryMappingEnd: TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE;

  Exit(TMappingEndEvent.Create(token.startMark, token.startMark));
end;

function TYamlParser.ParseFlowMappingKey(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.startMark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if not (token is TFlowMappingEndToken) then begin
    if (not AFirst) then begin
      if (token is TFlowEntryToken) then begin
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end
      else begin
        SetParserErrorContext(
          'while parsing a flow mapping', marks.Pop,
          'did not find expected "," or "}"', token.startMark);
      end;
    end;

    if (token is TKeyToken) then begin
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
      if (not (token is TValueToken))
        and (not (token is TFlowEntryToken))
        and (not (token is TFlowMappingEndToken)) then begin
        states.Push(YAML_PARSE_FLOW_MAPPING_VALUE_STATE);
        Exit(ParseNode(False, False));
      end
      else begin
        state := YAML_PARSE_FLOW_MAPPING_VALUE_STATE;
        Exit(ProcessEmptyScalar(token.startMark));
      end;
    end
    else
    if not (token is TFlowMappingEndToken) then begin
      states.Push(YAML_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE);
      Exit(ParseNode(False, False));
    end;
  end;

  state := states.Pop;
  marks.Pop;
  Result := TMappingEndEvent.Create(token.startMark, token.endMark);
  FScanner.SkipToken;
end;

function TYamlParser.ParseFlowMappingValue(AEmpty: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (AEmpty) then begin
    state := YAML_PARSE_FLOW_MAPPING_KEY_STATE;
    Exit(ProcessEmptyScalar(token.startMark));
  end;

  if (token is TValueToken) then begin
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TFlowEntryToken))
      and (not (token is TFlowMappingEndToken)) then begin
      states.Push(YAML_PARSE_FLOW_MAPPING_KEY_STATE);
      Exit(ParseNode(False, False));
    end;
  end;

  state := YAML_PARSE_FLOW_MAPPING_KEY_STATE;
  Exit(ProcessEmptyScalar(token.startMark));
end;

procedure TYamlParser.ProcessDirectives(var AVersionDirective: TYamlVersionDirective);
var
  token: TYamlToken;
  defaultTagDirectives: TYamlTagDirectives;
  versionToken: TVersionDirectiveToken;
  tagDirective: TYamlTagDirective;
begin
  SetLength(defaultTagDirectives, 2);
  defaultTagDirectives[0] := TYamlTagDirective.Build('!', '!');
  defaultTagDirectives[1] := TYamlTagDirective.Build('!!', 'tag:yaml.org,2002:');

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit;

  while (token is TVersionDirectiveToken) or
    (token is TTagDirectiveToken) do begin
    if (token is TVersionDirectiveToken) then begin
      if (AVersionDirective.Major <> 0) then begin
        SetParserError(
          'found duplicate %YAML directive', token.startMark);
      end;
      versionToken := TVersionDirectiveToken(token);
      if (versionToken.major <> 1)
        or (
        (versionToken.minor <> 1)
        and (versionToken.minor <> 2)
        ) then begin
        SetParserError(
          'found incompatible YAML document', token.startMark);
      end;
      AVersionDirective.Major := versionToken.major;
      AVersionDirective.Minor := versionToken.minor;
    end
    else
    if (token is TTagDirectiveToken) then begin
      tagDirective.Handle := TTagDirectiveToken(token).handle;
      tagDirective.Prefix := TTagDirectiveToken(token).prefix;

      AppendTagDirective(tagDirective, False, token.startMark);
    end;

    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit;
  end;

  for tagDirective in defaultTagDirectives do begin
    AppendTagDirective(tagDirective, True, token.startMark);
  end;
end;

function TYamlParser.ProcessEmptyScalar(AMark: TYamlMark): TYamlEvent;
begin
  Result := TScalarEvent.Create('', '', '',
    True, False, yssPlainScalar, AMark, AMark);
end;

procedure TYamlParser.AppendTagDirective(const AValue: TYamlTagDirective;
  AAllowDuplicates: Boolean; AMark: TYamlMark);
var
  i: Integer;
begin
  for i := 0 to High(tagDirectives) do begin
    if AValue.Handle = tagDirectives[i].Handle then begin
      if AAllowDuplicates then
        Exit;
      SetParserError('duplicate %TAG directive', AMark);
    end;
  end;

  SetLength(tagDirectives, Length(tagDirectives) + 1);
  tagDirectives[High(tagDirectives)] := AValue;
end;


constructor TYamlParser.Create;
begin
  inherited Create;

  FError := False;

  FScanner := TYamlScanner.Create;

  states := TOTStack<TYamlParserState>.Create;
  marks := TOTStack<TYamlMark>.Create;
  SetLength(tagDirectives, 0);
end;

destructor TYamlParser.Destroy;
begin
  FScanner.Free;
  states.Free;
  marks.Free;

  inherited Destroy;
end;

procedure TYamlParser.SetInput(AStream: TStream);
begin
  FScanner.SetInput(AStream);
end;

procedure TYamlParser.SetEncoding(AEncoding: TYamlEncoding);
begin
  FScanner.SetEncoding(AEncoding);
end;

function TYamlParser.Parse: TYamlEvent;
begin
  if FScanner.streamEndProduced or (FError) or (state = YAML_PARSE_END_STATE) then begin
    Exit(nil);
  end;

  try
    Exit(StateMachine());
  except
    on Exception do begin
      FError := True;
      raise;
    end;
  end;
end;

end.
