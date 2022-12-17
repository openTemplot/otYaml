unit otYamlScanner;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  otYaml,
  otYamlToken,
  otQueue,
  otStack,
  otYamlReader;

type

  { EYamlScannerError }

  EYamlScannerError = class(Exception)
  private
    FContext: String;
    FContextMark: TYamlMark;

  public
    constructor Create(AContext: String; AContextMark: TYamlMark;
      AProblem: String);
  end;


  { TYamlScanner }

  TYamlScanner = class
  private
    FReader: TYamlReader;

    FTokens: TOTQueue<TYamlToken>;

    FTokenAvailable: Boolean;
    FTokensParsed: Integer;

    FStreamStartProduced: Boolean;
    FStreamEndProduced: Boolean;

    (** May a simple key occur at the current position? *)
    FSimpleKeyAllowed: Boolean;

    (** The stack of simple keys. *)
    FSimpleKeys: TOTObjectStack<TYamlSimpleKey>;

    (** The number of unclosed '[' and '{' indicators. *)
    FFlowLevel: Integer;

    (** The indentation levels stack. *)
    FIndents: TOTStack<Integer>;

    (** The current indentation level. *)
    FIndent: Integer;


    procedure SetScannerError(const AContext: String;
      const AContextMark: TYamlMark; const AProblem: String);

    procedure FetchMoreTokens;
    procedure StaleSimpleKeys;
    procedure FetchNextToken;
    procedure ScanToNextToken;
    procedure UnrollIndent(AColumn: Integer);
    procedure RollIndent(AColumn: Integer; ANumber: Integer; ATokenType: TYamlTokenType;
      AMark: TYamlMark);

    procedure FetchStreamStart;
    procedure FetchStreamEnd;
    procedure FetchDirective;
    procedure FetchDocumentIndicator(ATokenType: TYamlTokenType);
    procedure FetchFlowCollectionStart(ATokenType: TYamlTokenType);
    procedure FetchFlowCollectionEnd(ATokenType: TYamlTokenType);
    procedure FetchFlowEntry;
    procedure FetchBlockEntry;
    procedure FetchKey;
    procedure FetchValue;
    procedure FetchAnchor(ATokenType: TYamlTokenType);
    procedure FetchTag;
    procedure FetchBlockScalar(AIsLiteral: Boolean);
    procedure FetchFlowScalar(AIsSingle: Boolean);
    procedure FetchPlainScalar;

    function ScanDirective: TYamlToken;
    function ScanAnchor(ATokenType: TYamlTokenType): TYamlToken;
    function ScanTag: TYamlToken;
    function ScanBlockScalar(AIsLiteral: Boolean): TYamlToken;
    function ScanFlowScalar(AIsSingle: Boolean): TYamlToken;
    function ScanPlainScalar: TYamlToken;

    function ScanDirectiveName(AStartMark: TYamlMark): String;
    procedure ScanVersionDirectiveValue(AStartMark: TYamlMark; out AMajor: Integer;
      out AMinor: Integer);
    function ScanVersionDirectiveNumber(AStartMark: TYamlMark): Integer;
    procedure ScanTagDirectiveValue(AStartMark: TYamlMark; out AHandle: String;
      out APrefix: String);
    function ScanTagHandle(AIsDirective: Boolean;
      AStartMark: TYamlMark): String;
    function ScanTagUri(AIsVerbatim: Boolean; AIsDirective: Boolean; AHead: String;
      AStartMark: TYamlMark): String;
    function ScanUriEscapes(AIsDirective: Boolean; AStartMark: TYamlMark): String;

    procedure ScanBlockScalarBreaks(var AIndent: Integer; var ABreaks: String;
      AStartMark: TYamlMark; var AEndMark: TYamlMark);

    procedure RemoveSimpleKey;
    procedure SaveSimpleKey;
    procedure IncreaseFlowLevel;
    procedure DecreaseFlowLevel;

  public

    constructor Create;
    destructor Destroy; override;

    procedure SetInput(AInput: TStream);
    procedure SetEncoding(AEncoding: TYamlEncoding);
    function Peek: TYamlToken;
    procedure SkipToken;

    property streamEndProduced: Boolean Read FStreamEndProduced;

  end;

implementation

uses
  otYamlChars;

{ EYamlScannerError }

constructor EYamlScannerError.Create(AContext: String;
  AContextMark: TYamlMark; AProblem: String);
begin
  inherited Create(AProblem);
  FContext := AContext;
  FContextMark := AContextMark;
end;


{ TYamlScanner }

procedure TYamlScanner.SetScannerError(const AContext: String;
  const AContextMark: TYamlMark; const AProblem: String);
begin
  raise EYamlScannerError.Create(AContext, AContextMark, AProblem);
end;

constructor TYamlScanner.Create;
begin
  inherited Create;

  FReader := TYamlReader.Create;

  FTokens := TOTQueue<TYamlToken>.Create;
  FSimpleKeys := TOTObjectStack<TYamlSimpleKey>.Create;

  FStreamStartProduced := False;
  FStreamEndProduced := False;

  FTokenAvailable := False;
  FTokensParsed := 0;
  FFlowLevel := 0;

  FIndents := TOTStack<Integer>.Create;
  FIndent := 0;


  FStreamStartProduced := False;
end;

destructor TYamlScanner.Destroy;
begin
  FReader.Free;
  FSimpleKeys.Free;
  FTokens.Free;
  FIndents.Free;
  inherited Destroy;
end;

procedure TYamlScanner.SetInput(AInput: TStream);
begin
  FReader.SetInput(AInput);
end;

procedure TYamlScanner.SetEncoding(AEncoding: TYamlEncoding);
begin
  FReader.SetEncoding(AEncoding);
end;

function TYamlScanner.Peek: TYamlToken;
begin
  if not FTokenAvailable then
    FetchMoreTokens;
  Result := FTokens.Peek;
end;

procedure TYamlScanner.SkipToken;
begin
  FTokenAvailable := False;
  Inc(FTokensParsed);
  if FTokens.Peek is TStreamEndToken then
    FStreamEndProduced := True;
  FTokens.Dequeue;
end;

procedure TYamlScanner.FetchMoreTokens;
var
  needMoreTokens: Boolean;
  simpleKey: TYamlSimpleKey;
begin
  while True do begin
    // Check if we really need to getch more tokens.
    needMoreTokens := False;
    if FTokens.Count = 0 then begin
      needMoreTokens := True;
    end
    else begin
      StaleSimpleKeys;

      for simpleKey in FSimpleKeys do begin
        if (simpleKey.FPossible and (simpleKey.FTokenNumber = FTokensParsed)) then begin
          needMoreTokens := True;
          break;
        end;
      end;
    end;

    if not needMoreTokens then
      break;

    FetchNextToken;
  end;

  FTokenAvailable := True;
end;

procedure TYamlScanner.StaleSimpleKeys;
var
  sk: TYamlSimpleKey;
begin
  for sk in FSimpleKeys do begin
      (*
       * The specification requires that a simple key
       *
       *  - is limited to a single line,
       *  - is shorter than 1024 characters.
       *)

    if sk.FPossible
      and ((sk.FMark.Line < FReader.mark.Line)
      or (sk.FMark.Index + 1024 < FReader.mark.Index)) then begin

      (* Check if the potential simple key to be removed is required. *)

      if (sk.FRequired) then begin
        SetScannerError(
          'while scanning a simple key', sk.FMark,
          'could not find expected ":"');
      end;

      sk.FPossible := False;
    end;
  end;
end;

procedure TYamlScanner.FetchNextToken;
begin
  //* Ensure that the buffer is initialized. */

  FReader.Cache(1);

  //* Check if we just started scanning.  Fetch STREAM-START then. */

  if (not FStreamStartProduced) then
    FetchStreamStart;

  //* Eat whitespaces and comments until we reach the next token. */

  ScanToNextToken;

  //* Remove obsolete potential simple keys. */

  StaleSimpleKeys;

  //* Check the indentation level against the current column. */

  UnrollIndent(FReader.mark.Column);

  //*
  // * Ensure that the buffer contains at least 4 characters.  4 is the length
  // * of the longest indicators ('--- ' and '... ').
  // */

  FReader.Cache(4);

  //* Is it the end of the stream? */

  if (IsZAt(FReader.buffer, 1)) then begin
    FetchStreamEnd;
    Exit;
  end;

  //* Is it a directive? */

  if (FReader.mark.Column = 0) and (FReader.buffer[1] = '%') then begin
    FetchDirective;
    Exit;
  end;

  //* Is it the document start indicator? */

  if (FReader.mark.Column = 0)
    and (FReader.buffer[1] = '-')
    and (FReader.buffer[2] = '-')
    and (FReader.buffer[3] = '-')
    and IsBlankZAt(FReader.buffer, 4) then begin
    FetchDocumentIndicator(
      ytkDocumentStart);
    Exit;
  end;

  //* Is it the document end indicator? */

  if (FReader.mark.Column = 0)
    and (FReader.buffer[1] = '.')
    and (FReader.buffer[2] = '.')
    and (FReader.buffer[3] = '.')
    and IsBlankZAt(FReader.buffer, 4) then begin
    FetchDocumentIndicator(
      ytkDocumentEnd);
    Exit;
  end;

  //* Is it the flow sequence start indicator? */

  if (FReader.buffer[1] = '[') then begin
    FetchFlowCollectionStart(
      ytkFlowSequenceStart);
    Exit;
  end;

  //* Is it the flow mapping start indicator? */

  if (FReader.buffer[1] = '{') then begin
    FetchFlowCollectionStart(
      ytkFlowMappingStart);
    Exit;
  end;

  //* Is it the flow sequence end indicator? */

  if (FReader.buffer[1] = ']') then begin
    FetchFlowCollectionEnd(
      ytkFlowSequenceEnd);
    Exit;
  end;

  //* Is it the flow mapping end indicator? */

  if (FReader.buffer[1] = '}') then begin
    FetchFlowCollectionEnd(
      ytkFlowMappingEnd);
    Exit;
  end;

  //* Is it the flow entry indicator? */

  if (FReader.buffer[1] = ',') then begin
    FetchFlowEntry;
    Exit;
  end;

  //* Is it the block entry indicator? */

  if (FReader.buffer[1] = '-') and IsBlankZAt(FReader.buffer, 2) then begin
    FetchBlockEntry;
    Exit;
  end;

  //* Is it the key indicator? */

  if (FReader.buffer[1] = '?')
    and ((FFlowLevel > 0) or IsBlankZAt(FReader.buffer, 2)) then begin
    FetchKey;
    Exit;
  end;

  //* Is it the value indicator? */

  if (FReader.buffer[1] = ':')
    and ((FFlowLevel > 0) or IsBlankZAt(FReader.buffer, 2)) then begin
    FetchValue;
    Exit;
  end;

  //* Is it an alias? */

  if (FReader.buffer[1] = '*') then begin
    FetchAnchor(ytkAlias);
    Exit;
  end;

  //* Is it an anchor? */

  if (FReader.buffer[1] = '&') then begin
    FetchAnchor(ytkAnchor);
    Exit;
  end;

  //* Is it a tag? */

  if (FReader.buffer[1] = '!') then begin
    FetchTag;
    Exit;
  end;

  //* Is it a literal scalar? */

  if (FReader.buffer[1] = '|') and (FFlowLevel = 0) then begin
    FetchBlockScalar(True);
    Exit;
  end;

  //* Is it a folded scalar? */

  if (FReader.buffer[1] = '>') and (FFlowLevel = 0) then begin
    FetchBlockScalar(False);
    Exit;
  end;

  //* Is it a single-quoted scalar? */

  if (FReader.buffer[1] = '''') then begin
    FetchFlowScalar(True);
    Exit;
  end;

  //* Is it a double-quoted scalar? */

  if (FReader.buffer[1] = '"') then begin
    FetchFlowScalar(False);
    Exit;
  end;

  //*
  // * Is it a plain scalar?
  // *
  // * A plain scalar may start with any non-blank characters except
  // *
  // *      '-', '?', ':', ',', '[', ']', '{', '}',
  // *      '#', '&', '*', '!', '|', '>', '\'', '\"',
  // *      '%', '@', '`'.
  // *
  // * In the block context (and, for the '-' indicator, in the flow context
  // * too), it may also start with the characters
  // *
  // *      '-', '?', ':'
  // *
  // * if it is followed by a non-space character.
  // *
  // * The last rule is more restrictive than the specification requires.
  // */

  if (not (IsBlankZAt(FReader.buffer, 1) or
    (FReader.buffer[1] in ['-', '?', ':', ',', '[', ']', '{', '}', '#',
    '&', '*', '!', '|', '>', '''', '"', '%', '@', '`'])))
    or ((FReader.buffer[1] = '-') and (not IsBlankAt(FReader.buffer, 2)))
    or ((FFlowLevel = 0) and (FReader.buffer[1] in ['?', ':'])
    and (not IsBlankZAt(FReader.buffer, 2))) then begin
    FetchPlainScalar;
    Exit;
  end;

  //*
  // * If we don't determine the token type so far, it is an error.
  // */

  SetScannerError(
    'while scanning for the next token', FReader.mark,
    'found character that cannot start any token');

end;

procedure TYamlScanner.ScanToNextToken;
begin
  //* Until the next token is not found. */

  while True do begin
    //* Allow the BOM mark to start a line. */

    FReader.Cache(1);

    if (FReader.mark.Column = 0) and IsBOMAt(FReader.buffer, 1) then
      FReader.Skip;

    ///*
    // * Eat whitespaces.
    // *
    // * Tabs are allowed:
    // *
    // *  - in the flow context;
    // *  - in the block context, but not at the beginning of the line or
    // *  after '-', '?', or ':' (complex value).
    // */

    FReader.Cache(1);

    while (FReader.buffer[1] = ' ') or
      (((FFlowLevel > 0) or (not FSimpleKeyAllowed)) and
        (FReader.buffer[1] = #$09)) do begin
      FReader.Skip;
      FReader.Cache(1);
    end;

    ///* Eat a comment until a line break. */

    if (FReader.buffer[1] = '#') then begin
      while (not IsBreakZAt(FReader.buffer, 1)) do begin
        FReader.Skip;
        FReader.Cache(1);
      end;
    end;

    ///* If it is a line break, eat it. */

    if (IsBreakAt(FReader.buffer, 1)) then begin
      FReader.Cache(2);
      FReader.SkipLine;

      ///* In the block context, a new line may start a simple key. */

      if (FFlowLevel = 0) then
        FSimpleKeyAllowed := True;
    end
    else begin
      ///* We have found a token. */

      break;
    end;
  end;
end;

procedure TYamlScanner.UnrollIndent(AColumn: Integer);
var
  token: TYamlToken;
begin
  //* In the flow context, do nothing. */

  if (FFlowLevel > 0) then
    Exit;

  //* Loop through the indentation levels in the stack. */

  while (FIndent > AColumn) do begin
    //* Create a token and append it to the queue. */

    token := TBlockEndToken.Create(FReader.mark, FReader.mark);
    FTokens.Enqueue(token);

    //* Pop the indentation level. */

    FIndent := FIndents.Pop;
  end;
end;

procedure TYamlScanner.RollIndent(AColumn: Integer; ANumber: Integer; ATokenType: TYamlTokenType;
  AMark: TYamlMark);
const
  MAX_INDENT = 2000000000;
var
  token: TYamlToken;
begin
  //* In the flow context, do nothing. */

  if (FFlowLevel > 0) then
    Exit;

  if (FIndent < AColumn) then begin
    ///*
    // * Push the current indentation level to the stack and set the new
    // * indentation level.
    // */

    FIndents.Push(FIndent);

    if (AColumn > MAX_INDENT) then
      raise Exception.Create('YAML Memory Error');

    FIndent := AColumn;

    //* Create a token and insert it into the queue. */
    if ATokenType = ytkBlockSequenceStart then
      token := TBlockSequenceStartToken.Create(FReader.mark, FReader.mark)
    else
    if ATokenType = ytkBlockMappingStart then
      token := TBlockMappingStartToken.Create(FReader.mark, FReader.mark)
    else
      raise Exception.Create('Unexpected token in RollIndent');

    if (ANumber = -1) then begin
      FTokens.Enqueue(token);
    end
    else begin
      FTokens.Insert(ANumber - FTokensParsed, token);
    end;
  end;

end;

procedure TYamlScanner.RemoveSimpleKey;
var
  simpleKey: TYamlSimpleKey;
begin
  simpleKey := FSimpleKeys.Peek;

  if (simpleKey.FPossible) then begin
    //* If the key is required, it is an error. */

    if (simpleKey.FRequired) then begin
      SetScannerError('while scanning a simple key', simpleKey.FMark,
        'could not find expected ":"');
    end;
  end;

  //* Remove the key from the stack. */
  simpleKey.FPossible := False;
end;

procedure TYamlScanner.SaveSimpleKey;
var
  required: Boolean;
  simpleKey: TYamlSimpleKey;
begin
  //*
  // * A simple key is required at the current position if the scanner is in
  // * the block context and the current column coincides with the indentation
  // * level.
  // */

  required := (FFlowLevel = 0) and (FIndent = FReader.mark.Column);

  ///*
  // * If the current position may start a simple key, save it.
  // */

  if (FSimpleKeyAllowed) then begin
    RemoveSimpleKey;
    simpleKey := FSimpleKeys.Peek;
    simpleKey.FPossible := True;
    simpleKey.FRequired := required;
    simpleKey.FTokenNumber := FTokensParsed + FTokens.Count;
    simpleKey.FMark := FReader.mark;
  end;
end;

procedure TYamlScanner.IncreaseFlowLevel;
const
  MAX_FLOW_LEVEL = 2000000000;
var
  simpleKey: TYamlSimpleKey;
begin
  simpleKey := TYamlSimpleKey.Create;

  //* Reset the simple key on the next level. */
  FSimpleKeys.Push(simpleKey);

  //* Increase the flow level. */
  if (FFlowLevel = MAX_FLOW_LEVEL) then begin
    raise Exception.Create('Memory error');
  end;

  Inc(FFlowLevel);
end;

procedure TYamlScanner.DecreaseFlowLevel;
var
  sk: TYamlSimpleKey;
begin
  if (FFlowLevel > 0) then begin
    Dec(FFlowLevel);
    sk := FSimpleKeys.Pop;
    sk.Free;
  end;
end;

procedure TYamlScanner.FetchStreamStart;
var
  token: TYamlToken;
  simpleKey: TYamlSimpleKey;
begin
  simpleKey := TYamlSimpleKey.Create;

  //* Set the initial indentation. */

  FIndent := -1;

  //* Initialize the simple key stack. */

  FSimpleKeys.Push(simpleKey);

  //* A simple key is allowed at the beginning of the stream. */

  FSimpleKeyAllowed := True;

  //* We have started. */

  FStreamStartProduced := True;

  //* Create the STREAM-START token and append it to the queue. */

  token := TStreamStartToken.Create(FReader.encoding, FReader.mark, FReader.mark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchStreamEnd;
var
  token: TYamlToken;
begin
  //* Force new line. */
  FReader.ForceNewLine;

  //* Reset the indentation level. */
  UnrollIndent(-1);

  //* Reset simple keys. */
  RemoveSimpleKey;

  FSimpleKeyAllowed := False;

  //* Create the STREAM-END token and append it to the queue. */
  token := TStreamEndToken.Create(FReader.mark, FReader.mark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchDirective;
var
  token: TYamlToken;
begin
  //* Reset the indentation level. */

  UnrollIndent(-1);

  //* Reset simple keys. */

  RemoveSimpleKey;

  FSimpleKeyAllowed := False;

  //* Create the YAML-DIRECTIVE or TAG-DIRECTIVE token. */

  token := ScanDirective;

  //* Append the token to the queue. */

  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchDocumentIndicator(ATokenType: TYamlTokenType);
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* Reset the indentation level. */

  UnrollIndent(-1);

  //* Reset simple keys. */

  RemoveSimpleKey;

  FSimpleKeyAllowed := False;

  //* Consume the token. */

  startMark := FReader.mark;

  FReader.Skip;
  FReader.Skip;
  FReader.Skip;

  endMark := FReader.mark;

  //* Create the DOCUMENT-START or DOCUMENT-END token. */

  if ATokenType = ytkDocumentStart then
    token := TDocumentStartToken.Create(startMark, endMark)
  else
  if ATokenType = ytkDocumentEnd then
    token := TDocumentEndToken.Create(startMark, endMark)
  else
    raise Exception.Create('unexpected token type');

  //* Append the token to the queue. */

  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchFlowCollectionStart(ATokenType: TYamlTokenType);
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* The indicators '[' and '{' may start a simple key. */
  SaveSimpleKey;

  //* Increase the flow level. */
  IncreaseFlowLevel;

  //* A simple key may follow the indicators '[' and '{'. */
  FSimpleKeyAllowed := True;

  //* Consume the token. */
  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the FLOW-SEQUENCE-START of FLOW-MAPPING-START token. */
  if ATokenType = ytkFlowSequenceStart then
    token := TFlowSequenceStartToken.Create(startMark, endMark)
  else
  if ATokenType = ytkFlowMappingStart then
    token := TFlowMappingStartToken.Create(startMark, endMark)
  else
    raise Exception.Create('unexpected token type');

  //* Append the token to the queue. */
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchFlowCollectionEnd(ATokenType: TYamlTokenType);
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* Reset any potential simple key on the current flow level. */
  RemoveSimpleKey;

  //* Decrease the flow level. */
  DecreaseFlowLevel;

  //* No simple keys after the indicators ']' and '}'. */
  FSimpleKeyAllowed := False;

  //* Consume the token. */
  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the FLOW-SEQUENCE-END of FLOW-MAPPING-END token. */
  if ATokenType = ytkFlowSequenceEnd then
    token := TFlowSequenceEndToken.Create(startMark, endMark)
  else
  if ATokenType = ytkFlowMappingEnd then
    token := TFlowMappingEndToken.Create(startMark, endMark)
  else
    raise Exception.Create('unexpected token type');

  //* Append the token to the queue. */
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchFlowEntry;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* Reset any potential simple keys on the current flow level. */
  RemoveSimpleKey;

  //* Simple keys are allowed after ','. */
  FSimpleKeyAllowed := True;

  //* Consume the token. */
  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the FLOW-ENTRY token and append it to the queue. */
  token := TFlowEntryToken.Create(startMark, endMark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchBlockEntry;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* Check if the scanner is in the block context. */

  if (FFlowLevel = 0) then begin
    //* Check if we are allowed to start a new entry. */
    if (not FSimpleKeyAllowed) then begin
      SetScannerError('', FReader.mark,
        'block sequence entries are not allowed in this context');
    end;

    //* Add the BLOCK-SEQUENCE-START token if needed. */
    RollIndent(FReader.mark.Column, -1,
      ytkBlockSequenceStart, FReader.mark);
  end
  else begin
      (*
       * It is an error for the '-' indicator to occur in the flow context,
       * but we let the Parser detect and report about it because the Parser
       * is able to point to the context.
       *)
  end;

  //* Reset any potential simple keys on the current flow level. */
  RemoveSimpleKey;

  //* Simple keys are allowed after '-'. */
  FSimpleKeyAllowed := True;

  //* Consume the token. */
  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the BLOCK-ENTRY token and append it to the queue. */
  token := TBlockEntryToken.Create(startMark, endMark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchKey;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
begin
  //* In the block context, additional checks are required. */

  if (FFlowLevel = 0) then begin
    //* Check if we are allowed to start a new key (not necessary simple). */
    if (not FSimpleKeyAllowed) then begin
      SetScannerError('', FReader.mark,
        'mapping keys are not allowed in this context');
    end;

    //* Add the BLOCK-MAPPING-START token if needed. */
    RollIndent(FReader.mark.Column, -1,
      ytkBlockMappingStart, FReader.mark);
  end;

  //* Reset any potential simple keys on the current flow level. */
  RemoveSimpleKey;

  //* Simple keys are allowed after '?' in the block context. */
  FSimpleKeyAllowed := (FFlowLevel = 0);

  //* Consume the token. */

  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the KEY token and append it to the queue. */
  token := TKeyToken.Create(startMark, endMark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchValue;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  token: TYamlToken;
  simpleKey: TYamlSimpleKey;
begin
  //* Have we found a simple key? */
  simpleKey := FSimpleKeys.Peek;
  if (simpleKey.FPossible) then begin
    //* Create the KEY token and insert it into the queue. */
    token := TKeyToken.Create(simpleKey.FMark, simpleKey.FMark);
    FTokens.Insert(simpleKey.FTokenNumber - FTokensParsed, token);

    //* In the block context, we may need to add the BLOCK-MAPPING-START token. */
    RollIndent(simpleKey.FMark.Column,
      simpleKey.FTokenNumber,
      ytkBlockMappingStart, simpleKey.FMark);

    //* Remove the simple key. */
    simpleKey.FPossible := False;

    //* A simple key cannot follow another simple key. */
    FSimpleKeyAllowed := False;
  end
  else begin
    //* The ':' indicator follows a complex key. */

    //* In the block context, extra checks are required. */
    if (FFlowLevel = 0) then begin
      //* Check if we are allowed to start a complex value. */
      if (not FSimpleKeyAllowed) then begin
        SetScannerError('', FReader.mark,
          'mapping values are not allowed in this context');
      end;

      //* Add the BLOCK-MAPPING-START token if needed. */
      RollIndent(FReader.mark.Column, -1,
        ytkBlockMappingStart, FReader.mark);
    end;

    //* Simple keys after ':' are allowed in the block context. */

    FSimpleKeyAllowed := (FFlowLevel = 0);
  end;

  //* Consume the token. */
  startMark := FReader.mark;
  FReader.Skip;
  endMark := FReader.mark;

  //* Create the VALUE token and append it to the queue. */

  token := TValueToken.Create(startMark, endMark);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchAnchor(ATokenType: TYamlTokenType);
var
  token: TYamlToken;
begin
  //* An anchor or an alias could be a simple key. */
  SaveSimpleKey;

  //* A simple key cannot follow an anchor or an alias. */
  FSimpleKeyAllowed := False;

  //* Create the ALIAS or ANCHOR token and append it to the queue. */
  token := ScanAnchor(ATokenType);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchTag;
var
  token: TYamlToken;
begin
  //* A tag could be a simple key. */
  SaveSimpleKey;

  //* A simple key cannot follow a tag. */
  FSimpleKeyAllowed := False;

  //* Create the TAG token and append it to the queue. */

  token := ScanTag;
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchBlockScalar(AIsLiteral: Boolean);
var
  token: TYamlToken;
begin
  //* Remove any potential simple keys. */
  RemoveSimpleKey;

  //* A simple key may follow a block scalar. */
  FSimpleKeyAllowed := True;

  //* Create the SCALAR token and append it to the queue. */
  token := ScanBlockScalar(AIsLiteral);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchFlowScalar(AIsSingle: Boolean);
var
  token: TYamlToken;
begin
  //* A plain scalar could be a simple key. */
  SaveSimpleKey;

  //* A simple key cannot follow a flow scalar. */
  FSimpleKeyAllowed := False;

  //* Create the SCALAR token and append it to the queue. */
  token := ScanFlowScalar(AIsSingle);
  FTokens.Enqueue(token);
end;

procedure TYamlScanner.FetchPlainScalar;
var
  token: TYamlToken;
begin
  //* A plain scalar could be a simple key. */
  SaveSimpleKey;

  //* A simple key cannot follow a flow scalar. */
  FSimpleKeyAllowed := False;

  //* Create the SCALAR token and append it to the queue. */
  token := ScanPlainScalar;
  FTokens.Enqueue(token);
end;

function TYamlScanner.ScanDirective: TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  major: Integer;
  minor: Integer;
  handle: String;
  prefix: String;
  Name: String;
begin
  //* Eat '%'. */
  startMark := FReader.mark;
  FReader.Skip;

  //* Scan the directive name. */

  Name := ScanDirectiveName(startMark);

  //* Is it a YAML directive? */

  if (Name = 'YAML') then begin
    //* Scan the VERSION directive value. */
    ScanVersionDirectiveValue(startMark, major, minor);
    endMark := FReader.mark;

    //* Create a VERSION-DIRECTIVE token. */
    Result := TVersionDirectiveToken.Create(major, minor, startMark, endMark);
  end

  //* Is it a TAG directive? */
  else
  if (Name = 'TAG') then begin
    //* Scan the TAG directive value. */

    ScanTagDirectiveValue(startMark, handle, prefix);
    endMark := FReader.mark;

    //* Create a TAG-DIRECTIVE token. */
    Result := TTagDirectiveToken.Create(handle, prefix, startMark, endMark);
  end

  //* Unknown directive. */
  else begin
    SetScannerError('while scanning a directive',
      startMark, 'found unknown directive name');
  end;

  //* Eat the rest of the line including any comments. */
  FReader.Cache(1);

  while (IsBlankAt(FReader.buffer, 1)) do begin
    FReader.Skip;
    FReader.Cache(1);
  end;

  if (FReader.buffer[1] = '#') then begin
    while (not IsBreakZAt(FReader.buffer, 1)) do begin
      FReader.Skip;
      FReader.Cache(1);
    end;
  end;

  //* Check if we are at the end of the line. */
  if (not IsBreakZAt(FReader.buffer, 1)) then begin
    SetScannerError('while scanning a directive',
      startMark, 'did not find expected comment or line break');
  end;

  //* Eat a line break. */
  if (IsBreakAt(FReader.buffer, 1)) then begin
    FReader.Cache(2);
    FReader.SkipLine;
  end;
end;

function TYamlScanner.ScanDirectiveName(AStartMark: TYamlMark): String;

begin
  Result := '';

  //* Consume the directive name. */
  FReader.Cache(1);

  while (IsAlphaAt(FReader.buffer, 1)) do begin
    Result := Result + FReader.Read;
    FReader.Cache(1);
  end;

  //* Check if the name is empty. */
  if (Result = '') then begin
    SetScannerError('while scanning a directive',
      AStartMark, 'could not find expected directive name');
  end;

  //* Check for an blank character after the name. */

  if (not IsBlankZAt(FReader.buffer, 1)) then begin
    SetScannerError('while scanning a directive',
      AStartMark, 'found unexpected non-alphabetical character');
  end;
end;

procedure TYamlScanner.ScanVersionDirectiveValue(AStartMark: TYamlMark;
  out AMajor: Integer; out AMinor: Integer);
begin
  //* Eat whitespaces. */
  FReader.Cache(1);

  while (IsBlankAt(FReader.buffer, 1)) do begin
    FReader.Skip;
    FReader.Cache(1);
  end;

  //* Consume the major version number. */
  AMajor := ScanVersionDirectiveNumber(AStartMark);

  //* Eat '.'. */
  if (FReader.buffer[1] <> '.') then begin
    SetScannerError('while scanning a %YAML directive',
      AStartMark, 'did not find expected digit or "." character');
  end;

  FReader.Skip;

  //* Consume the minor version number. */
  AMinor := ScanVersionDirectiveNumber(AStartMark);
end;

function TYamlScanner.ScanVersionDirectiveNumber(AStartMark: TYamlMark): Integer;
const
  MAX_NUMBER_LENGTH = 9;
var
  numberLength: Integer;
begin
  Result := 0;
  numberLength := 0;

  //* Repeat while the next character is digit. */
  FReader.Cache(1);

  while (IsDigitAt(FReader.buffer, 1)) do begin
    //* Check if the number is too long. */
    Inc(numberLength);

    if (numberLength > MAX_NUMBER_LENGTH) then begin
      SetScannerError('while scanning a %YAML directive',
        AStartMark, 'found extremely long version number');
    end;

    Result := Result * 10 + AsDigitAt(FReader.buffer, 1);
    FReader.Skip;
    FReader.Cache(1);
  end;

  //* Check if the number was present. */

  if (numberLength = 0) then begin
    SetScannerError('while scanning a %YAML directive',
      AStartMark, 'did not find expected version number');
  end;
end;

procedure TYamlScanner.ScanTagDirectiveValue(AStartMark: TYamlMark;
  out AHandle: String; out APrefix: String);
begin
  //* Eat whitespaces. */
  FReader.Cache(1);

  while (IsBlankAt(FReader.buffer, 1)) do begin
    FReader.Skip;
    FReader.Cache(1);
  end;

  //* Scan a AHandle. */
  AHandle := ScanTagHandle(True, AStartMark);

  //* Expect a whitespace. */
  FReader.Cache(1);

  if (not IsBlankAt(FReader.buffer, 1)) then begin
    SetScannerError('while scanning a %TAG directive',
      AStartMark, 'did not find expected whitespace');
  end;

  //* Eat whitespaces. */
  while (IsBlankAt(FReader.buffer, 1)) do begin
    FReader.Skip;
    FReader.Cache(1);
  end;

  //* Scan a APrefix. */
  APrefix := ScanTagUri(True, True, '', AStartMark);

  //* Expect a whitespace or line break. */
  FReader.Cache(1);

  if (not IsBlankZAt(FReader.buffer, 1)) then begin
    SetScannerError('while scanning a %TAG directive',
      AStartMark, 'did not find expected whitespace or line break');
  end;
end;

function TYamlScanner.ScanTagHandle(AIsDirective: Boolean;
  AStartMark: TYamlMark): String;
var
  errorContext: String;
begin
  if AIsDirective then
    errorContext := 'while scanning a tag directive'
  else
    errorContext := 'while scanning a tag';

  //* Check the initial '!' character. */
  FReader.Cache(1);

  if FReader.buffer[1] <> '!' then begin
    SetScannerError(errorContext, AStartMark, 'did not find expected "!"');
  end;

  //* Copy the '!' character. */
  Result := FReader.Read;

  //* Copy all subsequent alphabetical and numerical characters. */
  FReader.Cache(1);

  while (IsAlphaAt(FReader.buffer, 1)) do begin
    Result := Result + FReader.Read;
    FReader.Cache(1);
  end;

  //* Check if the trailing character is '!' and copy it. */

  if (FReader.buffer[1] = '!') then begin
    Result := Result + FReader.Read;
  end
  else begin
    ///*
    // * It's either the '!' tag or not really a tag handle.  If it's a %TAG
    // * AIsDirective, it's an error.  If it's a tag token, it must be a part of
    // * URI.
    // */

    if AIsDirective and (Result <> '!') then begin
      SetScannerError(errorContext,
        AStartMark, 'did not find expected "!"');
    end;
  end;
end;

function TYamlScanner.ScanTagUri(AIsVerbatim: Boolean; AIsDirective: Boolean;
  AHead: String; AStartMark: TYamlMark): String;
var
  errorContext: String;
begin
  if AIsDirective then
    errorContext := 'while scanning a tag directive'
  else
    errorContext := 'while scanning a tag';

  Result := '';
  ///*
  // * Copy the AHead if needed.
  // *
  // * Note that we don't copy the leading '!' character.
  // */
  if Length(AHead) > 1 then begin
    Result := Copy(AHead, 2, Length(AHead) - 1);
  end;

  //* Scan the tag. */
  FReader.Cache(1);

  ///*
  // * The set of characters that may appear in URI is as follows:
  // *
  // *      '0'-'9', 'A'-'Z', 'a'-'z', '_', '-', ';', '/', '?', ':', '@', '&',
  // *      '=', '+', '$', '.', '!', '~', '*', '\'', '(', ')', '%'.
  // *
  // * If we are inside a verbatim tag <...> (parameter AIsVerbatim is true)
  // * then also the following flow indicators are allowed:
  // *      ',', '[', ']'
  // */

  while IsAlphaAt(FReader.buffer, 1)
    or (FReader.buffer[1] in [';', '/', '?', ':', '@', '&', '=', '+', '$', '.',
      '%', '!', '~', '*', '''', '(', ')'])
    or (AIsVerbatim and (FReader.buffer[1] in [',', '[', ']'])) do begin
    //* Check if it is a URI-escape sequence. */
    if (FReader.buffer[1] = '%') then begin
      Result := Result + ScanUriEscapes(AIsDirective, AStartMark);
    end
    else begin
      Result := Result + FReader.Read;
    end;

    FReader.Cache(1);
  end;

  //* Check if the tag is non-empty. */
  if (Result = '') then begin
    SetScannerError(errorContext,
      AStartMark, 'did not find expected tag URI');
  end;

end;

function TYamlScanner.ScanUriEscapes(AIsDirective: Boolean; AStartMark: TYamlMark): String;
var
  Width: Integer;
  octet: Byte;
  errorContext: String;
begin
  if AIsDirective then
    errorContext := 'while parsing a %TAG directive'
  else
    errorContext := 'while parsing a tag';

  Result := '';
  Width := 0;

  //* Decode the required number of characters. */
  repeat
    octet := 0;

    //* Check for a URI-escaped octet. */

    FReader.Cache(3);

    if not ((FReader.buffer[1] = '%') and IsHexAt(FReader.buffer, 2) and
      IsHexAt(FReader.buffer, 3)) then begin
      SetScannerError(errorContext, AStartMark, 'did not find URI escaped octet');
    end;

    //* Get the octet. */

    octet := (AsHexAt(FReader.buffer, 2) shl 4) + AsHexAt(FReader.buffer, 3);

    //* If it is the leading octet, determine the length of the UTF-8 sequence. */

    if (Width = 0) then begin
      if (octet and $80) = $00 then
        Width := 1
      else
      if (octet and $E0) = $C0 then
        Width := 2
      else
      if (octet and $F0) = $E0 then
        Width := 3
      else
      if (octet and $F8) = $F0 then
        Width := 4
      else begin
        SetScannerError(errorContext, AStartMark, 'found an incorrect leading UTF-8 octet');
      end;
    end
    else begin
      //* Check if the trailing octet is correct. */

      if ((octet and $C0) <> $80) then begin
        SetScannerError(errorContext, AStartMark,
          'found an incorrect trailing UTF-8 octet');
      end;
    end;

    //* Copy the octet and move the pointers. */

    Result := Result + Char(octet);
    FReader.Skip;
    FReader.Skip;
    FReader.Skip;

    Dec(Width);
  until (Width = 0);
end;

function TYamlScanner.ScanAnchor(ATokenType: TYamlTokenType): TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  Value: String;
begin
  Value := '';

  //* Eat the indicator character. */
  startMark := FReader.mark;
  FReader.Skip;

  //* Consume the value. */
  FReader.Cache(1);

  while IsAlphaAt(FReader.buffer, 1) do begin
    Value := Value + FReader.Read;
    FReader.Cache(1);
  end;

  endMark := FReader.mark;

  ///*
  // * Check if length of the anchor is greater than 0 and it is followed by
  // * a whitespace character or one of the indicators:
  // *
  // *      '?', ':', ',', ']', '}', '%', '@', '`'.
  // */

  if (Value = '') or
    not (IsBlankZAt(FReader.buffer, 1) or (FReader.buffer[1] in
    ['?', ':', ',', ']', '}', '%', '@', '`'])) then begin

    if ATokenType = ytkAnchor then
      SetScannerError('while scanning an anchor', startMark,
        'did not find expected alphabetic or numeric character')
    else
      SetScannerError('while scanning an alias', startMark,
        'did not find expected alphabetic or numeric character');
  end;

  //* Create a token. */

  if (ATokenType = ytkAnchor) then begin
    Result := TAnchorToken.Create(Value, startMark, endMark);
  end
  else begin
    Result := TAliasToken.Create(Value, startMark, endMark);
  end;

end;

function TYamlScanner.ScanTag: TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  handle: String;
  suffix: String;
begin
  startMark := FReader.mark;

  //* Check if the tag is in the canonical form. */
  FReader.Cache(2);

  if (FReader.buffer[2] = '<') then begin
    //* Set the handle to '' */
    handle := '';

    //* Eat '!<' */
    FReader.Skip;
    FReader.Skip;

    //* Consume the tag value. */

    suffix := ScanTagUri(True, False, '', startMark);

    //* Check for '>' and eat it. */

    if (FReader.buffer[1] <> '>') then begin
      SetScannerError('while scanning a tag',
        startMark, 'did not find the expected ">"');
    end;

    FReader.Skip;
  end
  else begin
    //* The tag has either the '!suffix' or the '!handle!suffix' form. */

    //* First, try to scan a handle. */
    handle := ScanTagHandle(False, startMark);

    //* Check if it is, indeed, handle. */
    if (Length(handle) > 1) and (handle[1] = '!') and (handle[Length(handle)] = '!') then begin
      //* Scan the suffix now. */

      suffix := ScanTagUri(False, False, '', startMark);
    end
    else begin
      //* It wasn't a handle after all.  Scan the rest of the tag. */
      suffix := ScanTagUri(False, False, handle, startMark);

      //* Set the handle to '!'. */
      handle := '!';

      ///*
      // * A special case: the '!' tag.  Set the handle to '' and the
      // * suffix to '!'.
      // */

      if (suffix = '') then begin
        handle := '';
        suffix := '!';
      end;
    end;
  end;

  //* Check the character which ends the tag. */
  FReader.Cache(1);

  if (not IsBlankZAt(FReader.buffer, 1)) then begin
    if (FFlowLevel = 0) or (FReader.buffer[1] <> ',') then begin
      SetScannerError('while scanning a tag',
        startMark, 'did not find expected whitespace or line break');
    end;
  end;

  endMark := FReader.mark;

  //* Create a token. */
  Result := TTagToken.Create(handle, suffix, startMark, endMark);
end;

function TYamlScanner.ScanBlockScalar(AIsLiteral: Boolean): TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  leadingBreak: String;
  trailingBreaks: String;
  chomping: Integer;
  increment: Integer;
  indent: Integer;
  leadingBlank: Boolean;
  trailingBlank: Boolean;
  Value: String;
  style: TYamlScalarStyle;
begin
  chomping := 0;
  increment := 0;
  indent := 0;
  leadingBlank := False;
  trailingBlank := False;

  Value := '';
  leadingBreak := '';
  trailingBreaks := '';

  //* Eat the indicator '|' or '>'. */
  startMark := FReader.mark;
  FReader.Skip;

  //* Scan the additional block scalar indicators. */
  FReader.Cache(1);

  //* Check for a chomping indicator. */
  if (FReader.buffer[1] in ['+', '-']) then begin
    //* Set the chomping method and eat the indicator. */
    if FReader.buffer[1] = '+' then
      chomping := 1
    else
      chomping := -1;
    FReader.Skip;

    //* Check for an indentation indicator. */
    FReader.Cache(1);

    if (IsDigitAt(FReader.buffer, 1)) then begin
      //* Check that the indentation is greater than 0. */

      if (FReader.buffer[1] = '0') then begin
        SetScannerError('while scanning a block scalar',
          startMark, 'found an indentation indicator equal to 0');
      end;

      //* Get the indentation level and eat the indicator. */
      increment := AsDigitAt(FReader.Buffer, 1);
      FReader.Skip;
    end;
  end

  //* Do the same as above, but in the opposite order. */
  else
  if (IsDigitAt(FReader.buffer, 1)) then begin
    if (FReader.buffer[1] = '0') then begin
      SetScannerError('while scanning a block scalar',
        startMark, 'found an indentation indicator equal to 0');
    end;

    increment := AsDigitAt(FReader.buffer, 1);
    FReader.Skip;

    FReader.Cache(1);

    if (FReader.buffer[1] in ['+', '-']) then begin
      //* Set the chomping method and eat the indicator. */
      if FReader.buffer[1] = '+' then
        chomping := 1
      else
        chomping := -1;
      FReader.Skip;
    end;
  end;

  //* Eat whitespaces and comments to the end of the line. */
  FReader.Cache(1);

  while (IsBlankAt(FReader.buffer, 1)) do begin
    FReader.Skip;
    FReader.Cache(1);
  end;

  if (FReader.buffer[1] = '#') then begin
    while (not IsBreakZAt(FReader.buffer, 1)) do begin
      FReader.Skip;
      FReader.Cache(1);
    end;
  end;

  //* Check if we are at the end of the line. */
  if (not IsBreakZAt(FReader.buffer, 1)) then begin
    SetScannerError('while scanning a block scalar',
      startMark, 'did not find expected comment or line break');
  end;

  //* Eat a line break. */
  if (IsBreakAt(FReader.buffer, 1)) then begin
    FReader.Cache(2);
    FReader.SkipLine;
  end;

  endMark := FReader.mark;

  //* Set the indentation level if it was specified. */
  if (increment <> 0) then begin
    if FIndent >= 0 then
      indent := FIndent + increment
    else
      indent := increment;
  end;

  //* Scan the leading line breaks and determine the indentation level if needed. */
  ScanBlockScalarBreaks(indent, trailingBreaks, startMark, endMark);

  //* Scan the block scalar content. */
  FReader.Cache(1);

  while (FReader.mark.Column = indent) and not IsZAt(FReader.buffer, 1) do begin
    ///*
    // * We are at the beginning of a non-empty line.
    // */

    //* Is it a trailing whitespace? */
    trailingBlank := IsBlankAt(FReader.buffer, 1);

    //* Check if we need to fold the leading line break. */
    if (not AIsLiteral) and ((leadingBreak <> '') and (leadingBreak[1] = #$0A))
      and (not leadingBlank) and (not trailingBlank) then begin
      //* Do we need to join the lines by space? */

      if (trailingBreaks = '') then begin
        Value := Value + ' ';
      end;

      leadingBreak := '';
    end
    else begin
      Value := Value + leadingBreak;
      leadingBreak := '';
    end;

    //* Append the remaining line breaks. */

    Value := Value + trailingBreaks;
    trailingBreaks := '';

    //* Is it a leading whitespace? */
    leadingBlank := IsBlankAt(FReader.buffer, 1);

    //* Consume the current line. */

    while (not IsBreakZAt(FReader.buffer, 1)) do begin
      Value := Value + FReader.Read;
      FReader.Cache(1);
    end;

    //* Consume the line break. */
    FReader.Cache(2);
    leadingBreak := leadingBreak + FReader.ReadLine;

    //* Eat the following indentation spaces and line breaks. */
    ScanBlockScalarBreaks(indent, trailingBreaks, startMark, endMark);
  end;

  //* Chomp the tail. */
  if (chomping <> -1) then begin
    Value := Value + leadingBreak;
  end;
  if (chomping = 1) then begin
    Value := Value + trailingBreaks;
  end;

  //* Create a token. */
  if AIsLiteral then
    style := yssLiteralScalar
  else
    style := yssFoldedScalar;

  Result := TScalarToken.Create(Value, style, startMark, endMark);
end;

procedure TYamlScanner.ScanBlockScalarBreaks(var AIndent: Integer; var ABreaks: String;
  AStartMark: TYamlMark; var AEndMark: TYamlMark);
var
  maxIndent: Integer;
begin
  maxIndent := 0;

  AEndMark := FReader.mark;

  //* Eat the indentation spaces and line ABreaks. */
  while (True) do begin
    //* Eat the indentation spaces. */
    FReader.Cache(1);

    while ((AIndent = 0) or (FReader.mark.Column < AIndent))
      and IsSpaceAt(FReader.buffer, 1) do begin
      FReader.Skip;
      FReader.Cache(1);
    end;

    if (FReader.mark.Column > maxIndent) then
      maxIndent := FReader.mark.Column;

    //* Check for a tab character messing the indentation. */
    if ((AIndent = 0) or (FReader.mark.Column < AIndent))
      and IsTabAt(FReader.buffer, 1) then begin
      SetScannerError('while scanning a block scalar',
        AStartMark, 'found a tab character where an indentation space is expected');
    end;

    //* Have we found a non-empty line? */
    if (not IsBreakAt(FReader.buffer, 1)) then
      Break;

    //* Consume the line break. */
    FReader.Cache(2);
    ABreaks := ABreaks + FReader.ReadLine;
    AEndMark := FReader.mark;
  end;

  //* Determine the indentation level if needed. */
  if (AIndent = 0) then begin
    AIndent := maxIndent;
    if (AIndent < FIndent + 1) then
      AIndent := FIndent + 1;
    if (AIndent < 1) then
      AIndent := 1;
  end;
end;

function TYamlScanner.ScanFlowScalar(AIsSingle: Boolean): TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  Value: String;
  leadingBreak: String;
  trailingBreaks: String;
  whitespaces: String;
  leadingBlanks: Boolean;
  style: TYamlScalarStyle;
  codeLength: Integer;
  codePoint: UInt32;
  k: Integer;
begin
  Value := '';
  leadingBreak := '';
  trailingBreaks := '';
  whitespaces := '';

  //* Eat the left quote. */
  startMark := FReader.mark;
  FReader.Skip;

  //* Consume the content of the quoted scalar. */

  while (True) do begin
    //* Check that there are no document indicators at the beginning of the line. */
    FReader.Cache(4);

    if (FReader.mark.Column = 0) and
      (((FReader.buffer[1] = '-') and
      (FReader.buffer[2] = '-') and
      (FReader.buffer[3] = '-')) or
      ((FReader.buffer[1] = '.') and
      (FReader.buffer[2] = '.') and
      (FReader.buffer[3] = '.'))) and
      IsBlankZAt(FReader.buffer, 4) then begin
      SetScannerError('while scanning a quoted scalar',
        startMark, 'found unexpected document indicator');
    end;

    //* Check for EOF. */
    if (IsZAt(FReader.buffer, 1)) then begin
      SetScannerError('while scanning a quoted scalar',
        startMark, 'found unexpected end of stream');
    end;

    //* Consume non-blank characters. */
    FReader.Cache(2);
    leadingBlanks := False;

    while (not IsBlankZAt(FReader.buffer, 1)) do begin
      //* Check for an escaped AIsSingle quote. */

      if (AIsSingle and (FReader.buffer[1] = '''')
        and (FReader.buffer[2] = '''')) then begin
        Value := Value + '''';
        FReader.Skip;
        FReader.Skip;
      end

      //* Check for the right quote. */
      else
      if AIsSingle and (FReader.buffer[1] = '''') then begin
        Break;
      end
      else
      if (not AIsSingle) and (FReader.buffer[1] = '"') then begin
        Break;
      end

      //* Check for an escaped line break. */
      else
      if (not AIsSingle) and (FReader.buffer = '\\')
        and IsBreakAt(FReader.buffer, 2) then begin
        FReader.Cache(3);
        FReader.Skip;
        FReader.SkipLine;
        leadingBlanks := True;
        Break;
      end

      //* Check for an escape sequence. */
      else
      if (not AIsSingle) and (FReader.buffer[1] = '\') then begin
        codeLength := 0;

        //* Check the escape character. */
        case (FReader.buffer[2]) of
          '0':
            Value := Value + #$00;

          'a':
            Value := Value + #$07;

          'b':
            Value := Value + #$08;

          't',
          #$09:
            Value := Value + #$09;

          'n':
            Value := Value + #$0A;

          'v':
            Value := Value + #$0B;

          'f':
            Value := Value + #$0C;

          'r':
            Value := Value + #$0D;

          'e':
            Value := Value + #$1B;

          ' ':
            Value := Value + #$20;

          '"':
            Value := Value + '"';

          '/':
            Value := Value + '/';

          '\':
            Value := Value + '\';

          'N':  //* NEL (#x85) */
            Value := Value + #$C2 + #$85;

          '_':   //* #xA0 */
            Value := Value + #$C2 + #$A0;

          'L':   //* LS (#x2028) */
            Value := Value + #$E2 + #$80 + #$A8;

          'P':   //* PS (#x2029) */
            Value := Value + #$E2 + #$80 + #$A9;

          'x':
            codeLength := 2;

          'u':
            codeLength := 4;

          'U':
            codeLength := 8;
          else
            SetScannerError('while parsing a quoted scalar',
              startMark, 'found unknown escape character');
        end;

        FReader.Skip;
        FReader.Skip;

        //* Consume an arbitrary escape code. */
        if (codeLength > 0) then begin
          codePoint := 0;

          //* Scan the character value. */
          FReader.Cache(codeLength);

          for k := 1 to codeLength do begin
            if (not IsHexAt(FReader.buffer, k)) then begin
              SetScannerError('while parsing a quoted scalar',
                startMark, 'did not find expected hexdecimal number');
            end;
            codePoint := (codePoint shl 4) + AsHexAt(FReader.buffer, k);
          end;

          //* Check the value and write the character. */

          if (((codePoint >= $D800) and (codePoint <= $DFFF)) or (codePoint > $10FFFF))
          then begin
            SetScannerError('while parsing a quoted scalar',
              startMark, 'found invalid Unicode character escape code');
          end;

          if (codePoint <= $7F) then begin
            Value := Value + Char(codePoint);
          end
          else
          if (codePoint <= $07FF) then begin
            Value := Value + Char($C0 + (codePoint shr 6))
              + Char($80 + (codepoint and $3F));
          end
          else
          if (codePoint <= $FFFF) then begin
            Value := Value + Char($E0 + (codePoint shr 12))
              + Char($80 + ((codePoint shr 6) and $3F))
              + Char($80 + (codePoint and $3F));
          end
          else begin
            Value := Value + Char($F0 + (codePoint shr 18))
              + Char($80 + ((codePoint shr 12) and $3F))
              + Char($80 + ((codePoint shr 6) and $3F))
              + Char($80 + (codePoint and $3F));
          end;

          //* Advance the pointer. */
          for k := 1 to codeLength do begin
            FReader.Skip;
          end;
        end;
      end

      else begin
        //* It is a non-escaped non-blank character. */
        Value := Value + FReader.Read;
      end;

      FReader.Cache(2);
    end;

    //* Check if we are at the end of the scalar. */

    ///* Fix for crash unitialized value crash
    // * Credit for the bug and input is to OSS Fuzz
    // * Credit for the fix to Alex Gaynor
    // */
    FReader.Cache(1);
    if AIsSingle then begin
      if FReader.buffer[1] = '''' then
        Break;
    end
    else begin
      if FReader.buffer[1] = '"' then
        Break;
    end;

    //* Consume blank characters. */
    FReader.Cache(1);

    while IsBlankAt(FReader.buffer, 1) or IsBreakAt(FReader.buffer, 1) do begin
      if (IsBlankAt(FReader.buffer, 1)) then begin
        //* Consume a space or a tab character. */

        if (not leadingBlanks) then begin
          whitespaces := whitespaces + FReader.Read;
        end
        else begin
          FReader.Skip;
        end;
      end
      else begin
        FReader.Cache(2);

        //* Check if it is a first line break. */
        if (not leadingBlanks) then begin
          whitespaces := '';
          leadingBreak := leadingBreak + FReader.ReadLine;
          leadingBlanks := True;
        end
        else begin
          trailingBreaks := trailingBreaks + FReader.ReadLine;
        end;
      end;
      FReader.Cache(1);
    end;

    //* Join the whitespaces or fold line breaks. */

    if (leadingBlanks) then begin
      //* Do we need to fold line breaks? */
      if (leadingBreak <> '') and (leadingBreak[1] = #$0A) then begin
        if (trailingBreaks = '') then begin
          Value := Value + ' ';
        end
        else begin
          Value := Value + trailingBreaks;
          trailingBreaks := '';
        end;
        leadingBreak := '';
      end
      else begin
        Value := Value + leadingBreak;
        Value := Value + trailingBreaks;
        leadingBreak := '';
        trailingBreaks := '';
      end;
    end
    else begin
      Value := Value + whitespaces;
      whitespaces := '';
    end;
  end;

  //* Eat the right quote. */
  FReader.Skip;

  endMark := FReader.mark;

  //* Create a token. */
  if AIsSingle then
    style := yssSingleQuotedScalar
  else
    style := yssDoubleQuotedScalar;

  Result := TScalarToken.Create(Value, style, startMark, endMark);
end;

function TYamlScanner.ScanPlainScalar: TYamlToken;
var
  startMark: TYamlMark;
  endMark: TYamlMark;
  Value: String;
  leadingBreak: String;
  trailingBreaks: String;
  whitespaces: String;
  leadingBlanks: Boolean;
  indent: Integer;
begin
  Value := '';
  leadingBreak := '';
  trailingBreaks := '';
  whitespaces := '';
  leadingBlanks := False;
  indent := FIndent + 1;

  startMark := FReader.mark;
  endMark := FReader.mark;

  //* Consume the content of the plain scalar. */
  while (True) do begin
    //* Check for a document indicator. */
    FReader.Cache(4);

    if (FReader.mark.Column = 0) and
      (((FReader.buffer[1] = '-') and
      (FReader.buffer[2] = '-') and
      (FReader.buffer[3] = '-')) or
      ((FReader.buffer[1] = '.') and
      (FReader.buffer[2] = '.') and
      (FReader.buffer[3] = '.'))) and
      IsBlankZAt(FReader.buffer, 4) then
      Break;

    //* Check for a comment. */
    if (FReader.buffer[1] = '#') then
      Break;

    //* Consume non-blank characters. */
    while (not IsBlankZAt(FReader.buffer, 1)) do begin
      ///* Check for "x:" + one of ',?[]{}' in the flow context. TODO: Fix the test "spec-08-13".
      // * This is not completely according to the spec
      // * See http://yaml.org/spec/1.1/#id907281 9.1.3. Plain
      // */

      if (FFlowLevel > 0)
        and (FReader.buffer[1] = ':')
        and (FReader.buffer[2] in [',', '?', '[', ']', '{', '}']) then begin
        SetScannerError('while scanning a plain scalar',
          startMark, 'found unexpected ":"');
      end;

      //* Check for indicators that may end a plain scalar. */
      if ((FReader.buffer[1] = ':') and IsBlankZAt(FReader.buffer, 2))
        or ((FFlowLevel > 0) and
        (FReader.buffer[1] in [',', '[', ']', '{', '}'])) then
        Break;

      //* Check if we need to join whitespaces and breaks. */

      if leadingBlanks or (whitespaces <> '') then begin
        if (leadingBlanks) then begin
          //* Do we need to fold line breaks? */
          if (leadingBreak <> '') and (leadingBreak[1] = #$0A) then begin
            if (trailingBreaks = '') then begin
              Value := Value + ' ';
            end
            else begin
              Value := Value + trailingBreaks;
              trailingBreaks := '';
            end;
            leadingBreak := '';
          end
          else begin
            Value := Value + leadingBreak + trailingBreaks;
            leadingBreak := '';
            trailingBreaks := '';
          end;

          leadingBlanks := False;
        end
        else begin
          Value := Value + whitespaces;
          whitespaces := '';
        end;
      end;

      //* Copy the character. */
      Value := Value + FReader.Read;

      endMark := FReader.mark;

      FReader.Cache(2);
    end;

    //* Is it the end? */
    if not (IsBlankAt(FReader.buffer, 1) or IsBreakAt(FReader.buffer, 1)) then
      Break;

    //* Consume blank characters. */
    FReader.Cache(1);

    while IsBlankAt(FReader.buffer, 1) or IsBreakAt(FReader.buffer, 1) do begin
      if (IsBlankAt(FReader.buffer, 1)) then begin
        //* Check for tab characters that abuse indentation. */
        if (leadingBlanks and (FReader.mark.Column < indent)
          and IsTabAt(FReader.buffer, 1)) then begin
          SetScannerError('while scanning a plain scalar',
            startMark, 'found a tab character that violates indentation');
        end;

        //* Consume a space or a tab character. */
        if (not leadingBlanks) then begin
          whitespaces := whitespaces + FReader.Read;
        end
        else begin
          FReader.Skip;
        end;
      end
      else begin
        FReader.Cache(2);

        //* Check if it is a first line break. */
        if (not leadingBlanks) then begin
          whitespaces := '';
          leadingBreak := leadingBreak + FReader.ReadLine;
          leadingBlanks := True;
        end
        else begin
          trailingBreaks := trailingBreaks + FReader.ReadLine;
        end;
      end;
      FReader.Cache(1);
    end;

    //* Check indentation level. */
    if (FFlowLevel = 0) and (FReader.mark.Column < indent) then
      Break;
  end;

  //* Create a token. */
  Result := TScalarToken.Create(Value, yssPlainScalar, startMark, endMark);

  //* Note that we change the 'simple_key_allowed' flag. */
  if (leadingBlanks) then begin
    FSimpleKeyAllowed := True;
  end;
end;

end.
