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
    constructor Create(AProblem: String; AMark: TYamlMark);
  end;

  EYamlParserErrorContext = class(Exception)
  private
    FContext: String;
    FContextMark: TYamlMark;
    FProblemMark: TYamlMark;

  public
    constructor Create(AContext: String; AContextMark: TYamlMark;
      AProblem: String; AProblemMark: TYamlMark);

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

    procedure set_parser_error(AProblem: String; AMark: TYamlMark);
    procedure set_parser_error_context(AContext: String; AContextMark: TYamlMark;
      AProblem: String; AProblemMark: TYamlMark);

    function state_machine: TYamlEvent;
    function parse_stream_start: TYamlEvent;
    function parse_document_start(AImplicit: Boolean): TYamlEvent;
    function parse_document_end: TYamlEvent;
    function parse_document_content: TYamlEvent;
    function parse_node(ABlock: Boolean; AIndentlessSequence: Boolean): TYamlEvent;
    function parse_block_sequence_entry(AFirst: Boolean): TYamlEvent;
    function parse_indentless_sequence_entry: TYamlEvent;
    function parse_block_mapping_key(AFirst: Boolean): TYamlEvent;
    function parse_block_mapping_value: TYamlEvent;
    function parse_flow_sequence_entry(AFirst: Boolean): TYamlEvent;
    function parse_flow_sequence_entry_mapping_key: TYamlEvent;
    function parse_flow_sequence_entry_mapping_value: TYamlEvent;
    function parse_flow_sequence_entry_mapping_end: TYamlEvent;
    function parse_flow_mapping_key(AFirst: Boolean): TYamlEvent;
    function parse_flow_mapping_value(AEmpty: Boolean): TYamlEvent;

    procedure process_directives(var AVersionDirective: TYamlVersionDirective);
    function process_empty_scalar(AMark: TYamlMark): TYamlEvent;

    procedure append_tag_directive(const AValue: TYamlTagDirective;
      AAllowDuplicates: Boolean; AMark: TYamlMark);

  public
    constructor Create;
    destructor Destroy; override;

    procedure SetInput(AStream: TStream);
    procedure SetEncoding(AEncoding: TYamlEncoding);

    function parse: TYamlEvent;

  end;

implementation

{ EYamlParserError }

constructor EYamlParserError.Create(AProblem: String; AMark: TYamlMark);
begin
  inherited Create(AProblem);
  FMark := AMark;
end;

constructor EYamlParserErrorContext.Create(AContext: String; AContextMark: TYamlMark;
  AProblem: String; AProblemMark: TYamlMark);
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

procedure TYamlParser.set_parser_error(AProblem: String; AMark: TYamlMark);
begin
  raise EYamlParserError.Create(AProblem, AMark);
end;

procedure TYamlParser.set_parser_error_context(AContext: String; AContextMark: TYamlMark;
  AProblem: String; AProblemMark: TYamlMark);
begin
  raise EYamlParserErrorContext.Create(AContext, AContextMark, AProblem, AProblemMark);
end;

function TYamlParser.state_machine: TYamlEvent;
begin
  case state of
    YAML_PARSE_STREAM_START_STATE:
      Exit(parse_stream_start);

    YAML_PARSE_IMPLICIT_DOCUMENT_START_STATE:
      Exit(parse_document_start(True));

    YAML_PARSE_DOCUMENT_START_STATE:
      Exit(parse_document_start(False));

    YAML_PARSE_DOCUMENT_CONTENT_STATE:
      Exit(parse_document_content);

    YAML_PARSE_DOCUMENT_END_STATE:
      Exit(parse_document_end);

    YAML_PARSE_BLOCK_NODE_STATE:
      Exit(parse_node(True, False));

    YAML_PARSE_BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE:
      Exit(parse_node(True, True));

    YAML_PARSE_FLOW_NODE_STATE:
      Exit(parse_node(False, False));

    YAML_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE:
      Exit(parse_block_sequence_entry(True));

    YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE:
      Exit(parse_block_sequence_entry(False));

    YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE:
      Exit(parse_indentless_sequence_entry);

    YAML_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE:
      Exit(parse_block_mapping_key(True));

    YAML_PARSE_BLOCK_MAPPING_KEY_STATE:
      Exit(parse_block_mapping_key(False));

    YAML_PARSE_BLOCK_MAPPING_VALUE_STATE:
      Exit(parse_block_mapping_value);

    YAML_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE:
      Exit(parse_flow_sequence_entry(True));

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE:
      Exit(parse_flow_sequence_entry(False));

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE:
      Exit(parse_flow_sequence_entry_mapping_key);

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE:
      Exit(parse_flow_sequence_entry_mapping_value);

    YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE:
      Exit(parse_flow_sequence_entry_mapping_end);

    YAML_PARSE_FLOW_MAPPING_FIRST_KEY_STATE:
      Exit(parse_flow_mapping_key(True));

    YAML_PARSE_FLOW_MAPPING_KEY_STATE:
      Exit(parse_flow_mapping_key(False));

    YAML_PARSE_FLOW_MAPPING_VALUE_STATE:
      Exit(parse_flow_mapping_value(False));

    YAML_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE:
      Exit(parse_flow_mapping_value(True));
    else
      assert(False);      //* Invalid state. */
  end;

  Exit(nil);
end;

function TYamlParser.parse_stream_start: TYamlEvent;
var
  token: TYamlToken;
  ssToken: TStreamStartToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if not (token is TStreamStartToken) then
    set_parser_error('did not find expected <stream-start>', token.start_mark);

  ssToken := TStreamStartToken(token);

  state := YAML_PARSE_IMPLICIT_DOCUMENT_START_STATE;
  Result := TStreamStartEvent.Create(ssToken.encoding, ssToken.start_mark, ssToken.start_mark);
  FScanner.SkipToken;
end;

function TYamlParser.parse_document_start(AImplicit: Boolean): TYamlEvent;
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
    process_directives(versionDirective);
    states.push(YAML_PARSE_DOCUMENT_END_STATE);
    state := YAML_PARSE_BLOCK_NODE_STATE;

    versionDirective.Initialize;
    Exit(TDocumentStartEvent.Create(versionDirective, nil, True,
      token.start_mark, token.end_mark));
  end

  // Parse an explicit document.

  else
  if not (token is TStreamEndToken) then begin
    startMark := token.start_mark;
    SetLength(tagDirectives, 0);
    process_directives(versionDirective);
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if not (token is TDocumentStartToken) then begin
      set_parser_error('did not find expected <document start>', token.start_mark);
    end;
    states.Push(YAML_PARSE_DOCUMENT_END_STATE);
    state := YAML_PARSE_DOCUMENT_CONTENT_STATE;
    endMark := token.end_mark;

    Result := TDocumentStartEvent.Create(versionDirective, tagDirectives, False,
      startMark, endMark);
    FScanner.SkipToken;
    Exit;
  end

  // Parse the stream end. */

  else begin
    state := YAML_PARSE_END_STATE;
    Result := TStreamEndEvent.Create(token.start_mark, token.end_mark);
    FScanner.SkipToken;
    Exit;
  end;
end;

function TYamlParser.parse_document_end: TYamlEvent;
var
  token: TYamlToken;
  start_mark: TYamlMark;
  end_mark: TYamlMark;
  implicit: Boolean;
begin
  implicit := True;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  start_mark := token.start_mark;
  end_mark := token.start_mark;

  if (token is TDocumentEndToken) then begin
    end_mark := token.end_mark;
    FScanner.SkipToken;
    implicit := False;
  end;

  SetLength(tagDirectives, 0);

  state := YAML_PARSE_DOCUMENT_START_STATE;
  Result := TDocumentEndEvent.Create(implicit, start_mark, end_mark);
end;

function TYamlParser.parse_document_content: TYamlEvent;
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
    Result := process_empty_scalar(token.start_mark);
  end
  else begin
    Result := parse_node(True, False);
  end;
end;

function TYamlParser.parse_node(ABlock: Boolean; AIndentlessSequence: Boolean): TYamlEvent;
var
  token: TYamlToken;
  anchor: String;
  has_tag: Boolean;
  tag: String;
  tag_handle: String;
  tag_suffix: String;
  start_mark: TYamlMark;
  end_mark: TYamlMark;
  tag_mark: TYamlMark;
  implicit: Boolean;
  tag_directive: TYamlTagDirective;
  plain_implicit: Boolean;
  quoted_implicit: Boolean;
begin
  has_tag := False;
  tag := '';

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TAliasToken) then begin
    state := states.Pop;
    Result := TAliasEvent.Create(TAliasToken(token).Value, token.start_mark, token.end_mark);
    FScanner.SkipToken;
    Exit;
  end

  else begin
    start_mark := token.start_mark;
    end_mark := token.start_mark;

    if (token is TAnchorToken) then begin
      anchor := TAnchorToken(token).Value;
      start_mark := token.start_mark;
      end_mark := token.end_mark;
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
      if (token is TTagToken) then begin
        has_tag := True;
        tag_handle := TTagToken(token).handle;
        tag_suffix := TTagToken(token).suffix;
        tag_mark := token.start_mark;
        end_mark := token.end_mark;
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end;
    end
    else
    if (token is TTagToken) then begin
      has_tag := True;
      tag_handle := TTagToken(token).handle;
      tag_suffix := TTagToken(token).suffix;
      start_mark := token.start_mark;
      tag_mark := token.start_mark;
      end_mark := token.end_mark;
      FScanner.SkipToken;
      token := FScanner.Peek;
      if not Assigned(token) then
        Exit(nil);
      if (token is TAnchorToken) then begin
        anchor := TAnchorToken(token).Value;
        end_mark := token.end_mark;
        FScanner.SkipToken;
        token := FScanner.Peek;
        if not Assigned(token) then
          Exit(nil);
      end;
    end;

    if has_tag then begin
      if (tag_handle = '') then begin
        tag := tag_suffix;
      end
      else begin
        for tag_directive in tagDirectives do begin
          if (tag_directive.Handle = tag_handle) then begin
            tag := tag_directive.Prefix + tag_suffix;
            break;
          end;
        end;
        if (tag = '') then
          set_parser_error_context('while parsing a node', start_mark,
            'found undefined tag handle', tag_mark);
      end;
    end;

    implicit := (not has_tag) or (tag = '');
    if AIndentlessSequence and (token is TBlockEntryToken) then begin
      end_mark := token.end_mark;
      state := YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE;
      Result := TSequenceStartEvent.Create(anchor, tag, implicit,
        ysqBlockSequence, start_mark, end_mark);
      Exit;
    end
    else begin
      if (token is TScalarToken) then begin
        plain_implicit := False;
        quoted_implicit := False;
        end_mark := token.end_mark;
        if ((TScalarToken(token).scalar_style = yssPlainScalar) and (not has_tag))
          or (has_tag and (tag = '!')) then begin
          plain_implicit := True;
        end
        else
        if (not has_tag) then begin
          quoted_implicit := True;
        end;
        state := states.Pop;
        Result := TScalarEvent.Create(anchor, tag,
          TScalarToken(token).Value,
          plain_implicit, quoted_implicit,
          TScalarToken(token).scalar_style, start_mark, end_mark);
        FScanner.SkipToken;
        Exit;
      end
      else
      if (token is TFlowSequenceStartToken) then begin
        end_mark := token.end_mark;
        state := YAML_PARSE_FLOW_SEQUENCE_FIRST_ENTRY_STATE;
        Result := TSequenceStartEvent.Create(anchor, tag, implicit,
          ysqFlowSequence, start_mark, end_mark);
        Exit;
      end
      else
      if (token is TFlowMappingStartToken) then begin
        end_mark := token.end_mark;
        state := YAML_PARSE_FLOW_MAPPING_FIRST_KEY_STATE;
        Result := TMappingStartEvent.Create(anchor, tag, implicit,
          ympFlowMapping, start_mark, end_mark);
        Exit;
      end
      else
      if (ABlock and (token is TBlockSequenceStartToken)) then begin
        end_mark := token.end_mark;
        state := YAML_PARSE_BLOCK_SEQUENCE_FIRST_ENTRY_STATE;
        Result := TSequenceStartEvent.Create(anchor, tag, implicit,
          ysqBlockSequence, start_mark, end_mark);
        Exit;
      end
      else
      if (ABlock and (token is TBlockMappingStartToken)) then begin
        end_mark := token.end_mark;
        state := YAML_PARSE_BLOCK_MAPPING_FIRST_KEY_STATE;
        Result := TMappingStartEvent.Create(anchor, tag, implicit,
          ympBlockMapping, start_mark, end_mark);
        Exit;
      end
      else
      if (Length(anchor) > 0) or (Length(tag) > 0) then begin
        state := states.Pop;
        Result := TScalarEvent.Create(anchor, tag, '',
          implicit, False, yssPlainScalar,
          start_mark, end_mark);
        Exit;
      end
      else begin
        if ABlock then
          set_parser_error_context(
            'while parsing a block node', start_mark,
            'did not find expected node content', token.start_mark)
        else
          set_parser_error_context(
            'while parsing a flow node', start_mark,
            'did not find expected node content', token.start_mark);
      end;
    end;
  end;
end;

function TYamlParser.parse_block_sequence_entry(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.start_mark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TBlockEntryToken) then begin
    mark := token.end_mark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TBlockEntryToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE);
      Exit(parse_node(True, False));
    end
    else begin
      state := YAML_PARSE_BLOCK_SEQUENCE_ENTRY_STATE;
      Exit(process_empty_scalar(mark));
    end;
  end

  else
  if (token is TBlockEndToken) then begin
    state := states.Pop;
    marks.Pop;
    Result := TSequenceEndEvent.Create(token.start_mark, token.end_mark);
    FScanner.SkipToken;
    Exit;
  end
  else begin
    set_parser_error_context(
      'while parsing a block collection', marks.Pop,
      'did not find expected "-" indicator', token.start_mark);
  end;
end;

function TYamlParser.parse_indentless_sequence_entry: TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TBlockEntryToken) then begin
    mark := token.end_mark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TBlockEntryToken)) and
      (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE);
      Exit(parse_node(True, False));
    end
    else begin
      state := YAML_PARSE_INDENTLESS_SEQUENCE_ENTRY_STATE;
      Exit(process_empty_scalar(mark));
    end;
  end

  else begin
    state := states.Pop;
    Result := TSequenceEndEvent.Create(token.start_mark, token.start_mark);
    Exit;
  end;
end;

function TYamlParser.parse_block_mapping_key(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.start_mark);
    FScanner.SkipToken;
  end;

  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TKeyToken) then begin
    mark := token.end_mark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_MAPPING_VALUE_STATE);
      Exit(parse_node(True, True));
    end
    else begin
      state := YAML_PARSE_BLOCK_MAPPING_VALUE_STATE;
      Exit(process_empty_scalar(mark));
    end;
  end

  else
  if (token is TBlockEndToken) then begin
    state := states.Pop;
    marks.Pop;
    Result := TMappingEndEvent.Create(token.start_mark, token.end_mark);
    FScanner.SkipToken;
    Exit;
    ;
  end

  else begin
    set_parser_error_context(
      'while parsing a block mapping', marks.Pop,
      'did not find expected key', token.start_mark);
  end;
end;

function TYamlParser.parse_block_mapping_value: TYamlEvent;
var
  token: TYamlToken;
  mark: TYamlMark;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (token is TValueToken) then begin
    mark := token.end_mark;
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TKeyToken)) and
      (not (token is TValueToken)) and
      (not (token is TBlockEndToken)) then begin
      states.Push(YAML_PARSE_BLOCK_MAPPING_KEY_STATE);
      Exit(parse_node(True, True));
    end
    else begin
      state := YAML_PARSE_BLOCK_MAPPING_KEY_STATE;
      Exit(process_empty_scalar(mark));
    end;
  end

  else begin
    state := YAML_PARSE_BLOCK_MAPPING_KEY_STATE;
    Exit(process_empty_scalar(token.start_mark));
  end;

end;

function TYamlParser.parse_flow_sequence_entry(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.start_mark);
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
        set_parser_error_context(
          'while parsing a flow sequence', marks.Pop,
          'did not find expected "," or "]"', token.start_mark);
      end;
    end;

    if (token is TKeyToken) then begin
      state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE;
      Result := TMappingStartEvent.Create('', '',
        True, ympFlowMapping,
        token.start_mark, token.end_mark);
      FScanner.SkipToken;
      Exit;
    end

    else
    if not (token is TFlowSequenceEndToken) then begin
      states.Push(YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE);
      Exit(parse_node(False, False));
    end;
  end;

  state := states.Pop;
  marks.Pop;
  Result := TSequenceEndEvent.Create(token.start_mark, token.end_mark);
  FScanner.SkipToken;
  Exit;
end;

function TYamlParser.parse_flow_sequence_entry_mapping_key: TYamlEvent;
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
    Exit(parse_node(False, False));
  end
  else begin
    mark := token.end_mark;
    FScanner.SkipToken;
    state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE;
    Exit(process_empty_scalar(mark));
  end;
end;

function TYamlParser.parse_flow_sequence_entry_mapping_value: TYamlEvent;
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
      Exit(parse_node(False, False));
    end;
  end;
  state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE;
  Exit(process_empty_scalar(token.start_mark));
end;

function TYamlParser.parse_flow_sequence_entry_mapping_end: TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  state := YAML_PARSE_FLOW_SEQUENCE_ENTRY_STATE;

  Exit(TMappingEndEvent.Create(token.start_mark, token.start_mark));
end;

function TYamlParser.parse_flow_mapping_key(AFirst: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  if (AFirst) then begin
    token := FScanner.Peek;
    marks.Push(token.start_mark);
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
        set_parser_error_context(
          'while parsing a flow mapping', marks.Pop,
          'did not find expected "," or "}"', token.start_mark);
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
        Exit(parse_node(False, False));
      end
      else begin
        state := YAML_PARSE_FLOW_MAPPING_VALUE_STATE;
        Exit(process_empty_scalar(token.start_mark));
      end;
    end
    else
    if not (token is TFlowMappingEndToken) then begin
      states.Push(YAML_PARSE_FLOW_MAPPING_EMPTY_VALUE_STATE);
      Exit(parse_node(False, False));
    end;
  end;

  state := states.Pop;
  marks.Pop;
  Result := TMappingEndEvent.Create(token.start_mark, token.end_mark);
  FScanner.SkipToken;
end;

function TYamlParser.parse_flow_mapping_value(AEmpty: Boolean): TYamlEvent;
var
  token: TYamlToken;
begin
  token := FScanner.Peek;
  if not Assigned(token) then
    Exit(nil);

  if (AEmpty) then begin
    state := YAML_PARSE_FLOW_MAPPING_KEY_STATE;
    Exit(process_empty_scalar(token.start_mark));
  end;

  if (token is TValueToken) then begin
    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit(nil);
    if (not (token is TFlowEntryToken))
      and (not (token is TFlowMappingEndToken)) then begin
      states.Push(YAML_PARSE_FLOW_MAPPING_KEY_STATE);
      Exit(parse_node(False, False));
    end;
  end;

  state := YAML_PARSE_FLOW_MAPPING_KEY_STATE;
  Exit(process_empty_scalar(token.start_mark));
end;

procedure TYamlParser.process_directives(var AVersionDirective: TYamlVersionDirective);
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
        set_parser_error(
          'found duplicate %YAML directive', token.start_mark);
      end;
      versionToken := TVersionDirectiveToken(token);
      if (versionToken.major <> 1)
        or (
        (versionToken.minor <> 1)
        and (versionToken.minor <> 2)
        ) then begin
        set_parser_error(
          'found incompatible YAML document', token.start_mark);
      end;
      AVersionDirective.Major := versionToken.major;
      AVersionDirective.Minor := versionToken.minor;
    end
    else
    if (token is TTagDirectiveToken) then begin
      tagDirective.Handle := TTagDirectiveToken(token).handle;
      tagDirective.Prefix := TTagDirectiveToken(token).prefix;

      append_tag_directive(tagDirective, False, token.start_mark);
    end;

    FScanner.SkipToken;
    token := FScanner.Peek;
    if not Assigned(token) then
      Exit;
  end;

  for tagDirective in defaultTagDirectives do begin
    append_tag_directive(tagDirective, True, token.start_mark);
  end;
end;

function TYamlParser.process_empty_scalar(AMark: TYamlMark): TYamlEvent;
begin
  Result := TScalarEvent.Create('', '', '',
    True, False, yssPlainScalar, AMark, AMark);
end;

procedure TYamlParser.append_tag_directive(const AValue: TYamlTagDirective;
  AAllowDuplicates: Boolean; AMark: TYamlMark);
var
  i: Integer;
begin
  for i := 0 to High(tagDirectives) do begin
    if AValue.Handle = tagDirectives[i].Handle then begin
      if AAllowDuplicates then
        Exit;
      set_parser_error('duplicate %TAG directive', AMark);
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

function TYamlParser.parse: TYamlEvent;
begin
  if FScanner.streamEndProduced or (FError) or (state = YAML_PARSE_END_STATE) then begin
    Exit(nil);
  end;

  try
    Exit(state_machine());
  except
    on Exception do begin
      FError := True;
      raise;
    end;
  end;
end;

end.
