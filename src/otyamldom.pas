unit otYamlDOM;

{$MODE Delphi}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  otYaml,
  otYamlParser,
  otYamlEmitter,
  otYamlEvent;

type
  { Flags that apply to a IYamlDocument }
  TYamlDocumentFlag = (
    { The document start indicator (---) is implicit.
      It is not present in the input source, and should not be written to the
      target. }
    ydfImplicitStart,

    { The document end indicator (...) is implicit.
      It is not present in the input source, and should not be written to the
      target. }
    ydfImplicitEnd);
  TYamlDocumentFlags = set of TYamlDocumentFlag;

const
  (* Common YAML tags, as found in the YAML tag repository (https://yaml.org/type/) *)

  { Prefix of all common YAML tags }
  YAML_TAG_PREFIX = 'tag:yaml.org,2002:';

  (* Collection Types *)

  { Unordered set of key: value pairs without duplicates. }
  YAML_TAG_MAP = YAML_TAG_PREFIX + 'map';

  { Ordered sequence of key: value pairs without duplicates. }
  YAML_TAG_OAP = YAML_TAG_PREFIX + 'omap';

  { Ordered sequence of key: value pairs allowing duplicates. }
  YAML_TAG_PAIRS = YAML_TAG_PREFIX + 'pairs';

  { Unordered set of non-equal values. }
  YAML_TAG_SET = YAML_TAG_PREFIX + 'set';

  { Sequence of arbitrary values. }
  YAML_TAG_SEQ = YAML_TAG_PREFIX + 'seq';

  (* Scalar Types *)

  { A sequence of zero or more octets (8 bit values). }
  YAML_TAG_BINARY = YAML_TAG_PREFIX + 'binary';

  { Mathematical Booleans. }
  YAML_TAG_BOOL = YAML_TAG_PREFIX + 'bool';

  { Floating-point approximation to real numbers. }
  YAML_TAG_FLOAT = YAML_TAG_PREFIX + 'float';

  { Mathematical integers. }
  YAML_TAG_INT = YAML_TAG_PREFIX + 'int';

  { Specify one or more mappings to be merged with the current one. }
  YAML_TAG_MERGE = YAML_TAG_PREFIX + 'merge';

  { Devoid of value. }
  YAML_TAG_NULL = YAML_TAG_PREFIX + 'null';

  { A sequence of zero or more Unicode characters. }
  YAML_TAG_STR = YAML_TAG_PREFIX + 'str';

  { A point in time. }
  YAML_TAG_TIMESTAMP = YAML_TAG_PREFIX + 'timestamp';

  { Specify the default value of a mapping. }
  YAML_TAG_VALUE = YAML_TAG_PREFIX + 'value';

  { Keys for encoding YAML in YAML. }
  YAML_TAG_YAML = YAML_TAG_PREFIX + 'yaml';

type
  { Various settings to control YAML output. }
  TYamlOutputSettings = record
  public
    { Whether the output should be in "canonical" format as in the YAML
      specification.
      Defaults to False. }
    Canonical: Boolean;

    { The indentation increment. That is, the number of spaces to use for
      indentation.
      Defaults to 2. }
    Indent: Integer;

    { Preferred line with, or -1 for unlimited.
      Defaults to -1. }
    LineWidth: Integer;

    { Preferred line break.
      Defaults to Any. }
    LineBreak: TYamlBreak;
  public
    { Initializes to default values. }
    procedure Initialize; inline;
    class function Create: TYamlOutputSettings; static;
  end;

type
  TYamlNode = class;
  TMappingElements = TObjectDictionary<TYamlNode, TYamlNode>;

  { The base type for the YAML object model. Every possible type of YAML node
    can be represented with a TYamlNode record.

    Memory management is automatic. All values are owned by a IYamlDocument,
    which takes care of destroying these values when the document is
    destroyed. }

  { TYamlNode }

  TYamlNode = class
  private
  type
    TAnchors = TDictionary<String, TYamlNode>;
  private

    FAnchor: String;
    FTag: String;
    FHashCalculated: Boolean;
    FHash: UInt32;
    function GetAnchor: String; inline;
    function GetTag: String; inline;
    procedure SetAnchor(const AValue: String);
    procedure SetTag(const AValue: String);

  protected
    function GetMappingStyle: TYamlMappingStyle; virtual;
    procedure SetMappingStyle(const AStyle: TYamlMappingStyle); virtual;

    function GetScalarStyle: TYamlScalarStyle; virtual;
    procedure SetScalarStyle(const AStyle: TYamlScalarStyle); virtual;
    function GetScalarFlags: TYamlScalarFlags; virtual;
    procedure SetScalarFlags(const AFlags: TYamlScalarFlags); virtual;

    function GetSequenceStyle: TYamlSequenceStyle; virtual;
    procedure SetSequenceStyle(const AStyle: TYamlSequenceSTyle); virtual;

  public
    procedure Init(const AAnchors: TAnchors;
      const AAnchor, ATag: String);
    function Equals(const AOther: TYamlNode; const AStrict: Boolean): Boolean; virtual;

    property Anchor: String Read GetAnchor Write SetAnchor;
    property Tag: String Read GetTag Write SetTag;

    property MappingStyle: TYamlMappingStyle Read GetMappingStyle Write SetMappingStyle;

    property ScalarFlags: TYamlScalarFlags Read GetScalarFlags Write SetScalarFlags;
    property ScalarStyle: TYamlScalarStyle Read GetScalarStyle Write SetScalarStyle;

    property SequenceStyle: TYamlSequenceStyle Read GetSequenceStyle Write SetSequenceStyle;


  protected
    function GetCount: Integer; virtual;

  private
    class function ParseInternal(const AParser: TYamlParser;
      const AAnchors: TAnchors; var ANodeEvent: TYamlEvent): TYamlNode; static;
  protected
    function CalculateHashCode: UInt32; virtual; abstract;
    procedure Emit(const AEmitter: TYamlEmitter); virtual; abstract;

    function GetTarget: TYamlNode; virtual;

  public
    { Performs a strict equality test of two nodes. Unlike the overloaded '='
      operator, this also checks for equality of the Tag and Anchor properties. }
    function StrictEquals(const AOther: TYamlNode): Boolean; inline;

    { Get the hash code for this node. Will always be non-negative.
      Does *not* take Tag, Anchor and other metadata into account.  }
    function GetHashCode: UInt32; inline;

    { Converts the TYamlNode to another type if possible, or returns a default
      value if conversion is not possible.

      Parameters:
        ADefault: (optional) default value to return in case the TYamlNode
          cannot be converted.

      Returns:
        The converted value, or ADefault if the value cannot be converted.

      Only Scalar and Alias nodes can be converted.
      These methods never raise an exception. }
    function ToBoolean(const ADefault: Boolean = False): Boolean; virtual;
    function ToInteger(const ADefault: Integer = 0): Integer; inline; // Alias for ToInt32
    function ToInt32(const ADefault: Int32 = 0): Int32; virtual;
    function ToInt64(const ADefault: Int64 = 0): Int64; virtual;
    function ToDouble(const ADefault: Double = 0): Double; virtual;
    function ToString(const ADefault: String = ''): String; virtual;

    property Target: TYamlNode Read GetTarget;


  protected
    function GetNode(const AIndex: Integer): TYamlNode; virtual;

  public
    (*************************************************************************)
    (* The methods in this section only apply to Sequences and Mappings      *)
    (* (that is, if IsSequence or IsMapping returns True). Unless stated     *)
    (* otherwise, they raise an EInvalidOperation exception if this is not   *)
    (* a Sequence of Mapping.                                                *)
    (*************************************************************************)

    { Deletes an item from a sequence or mapping.

      Parameters:
        AIndex: index of the item to delete.

      Raises:
        EInvalidOperation if this is not a sequence or mapping.
        EArgumentOutOfRangeException if AIndex is out of bounds. }
    procedure Delete(const AIndex: Integer); virtual;

    { Clears the sequence or mapping.

      Raises:
        EInvalidOperation if this is not a sequence or mapping. }
    procedure Clear; inline;

    { Returns the number of items in the sequence or mapping.
      This property NEVER raises an exception. Instead, it returns 0 if this is
      not a sequence or mapping. }
    property Count: Integer Read GetCount;
  public
    (*************************************************************************)
    (* The methods in this section only apply to Sequences (that is, if      *)
    (* IsSequence returns True). Unless stated otherwise, they raise an      *)
    (* EInvalidOperation exception if this is not a Sequence.                *)
    (*************************************************************************)

    function Add(const AValue: Boolean): TYamlNode; overload; virtual;
    function Add(const AValue: Int32): TYamlNode; overload; virtual;
    function Add(const AValue: UInt32): TYamlNode; overload; virtual;
    function Add(const AValue: Int64): TYamlNode; overload; virtual;
    function Add(const AValue: UInt64): TYamlNode; overload; virtual;
    function Add(const AValue: Single): TYamlNode; overload; virtual;
    function Add(const AValue: Double): TYamlNode; overload; virtual;
    function Add(const AValue: String): TYamlNode; overload; virtual;

    function AddSequence: TYamlNode; virtual;
    function AddMapping: TYamlNode; virtual;
    function AddAlias(const AAnchor: TYamlNode): TYamlNode; virtual;

    { The nodes in this sequence.

      Unlike the other sequence-methods, this property NEVER raises an
      exception. Instead, it returns a Null value if this is not a Sequence or
      AIndex is out of range.

      This allows for chaining without having to check every intermediate step,
      as in Foo.Items[1].Items[3].Items[2].ToInteger. }
    property Nodes[const AIndex: Integer]: TYamlNode Read GetNode;

  public
    (*************************************************************************)
    (* The methods in this section only apply to Mappings                    *)
    (* Unless stated otherwise, they raise an                                *)
    (* EInvalidOperation exception if this is not a Mapping.                 *)
    (*************************************************************************)
    function AddOrSetValue(const AKey: String; const AValue: Boolean): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: Int32): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: UInt32): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: Int64): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: UInt64): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: Single): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: Double): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: String; const AValue: String): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Boolean): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Int32): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: UInt32): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Int64): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: UInt64): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Single): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Double): TYamlNode;
      overload; virtual;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: String): TYamlNode;
      overload; virtual;

    function AddOrSetMapping(const AKey: String): TYamlNode; overload; virtual;
    function AddOrSetMapping(const AKey: TYamlNode): TYamlNode; overload; virtual;

    function AddOrSetAlias(const AKey: String; const AAnchor: TYamlNode): TYamlNode;
      overload; virtual;
    function AddOrSetAlias(const AKey: TYamlNode; const AAnchor: TYamlNode): TYamlNode;
      overload; virtual;

    function AddOrSetSequence(const AKey: String): TYamlNode; overload; virtual;
    function AddOrSetSequence(const AKey: TYamlNode): TYamlNode; overload; virtual;

    function GetKeys: TMappingElements.TKeyCollection; virtual;
    function GetValue(const AKey: string): TYamlNode; virtual;
    function GetValueByNode(const AKey: TYamlNode): TYamlNode; virtual;

            { The values in the mapping, indexed by key.

          Unlike the other mapping-methods, this property NEVER raises an exception.
          Instead, it returns a Null value if this is not a mapping or if the
          mapping does not contain the given key.

          This allows for chaining without having to check every intermediate step,
          as in Foo.Value['bar'].Values['baz'].ToInteger. }
    property Values[const AKey: String]: TYamlNode Read GetValue;
    property ValuesByNode[const AKey: TYamlNode]: TYamlNode Read GetValueByNode;
    property Keys: TMappingElements.TKeyCollection Read GetKeys;


  end;

  TScalarNode = class(TYamlNode)
  private
    FValue: String;
    FFlags: TYamlScalarFlags;
    FStyle: TYamlScalarStyle;

    function GetScalarFlags: TYamlScalarFlags; override;
    procedure SetScalarFlags(const AFlags: TYamlScalarFlags); override;
    function GetScalarStyle: TYamlScalarStyle; override;
    procedure SetScalarStyle(const AStyle: TYamlScalarStyle); override;

  public
    constructor Create(const AValue: String); overload;
    constructor Create(const AValue: Boolean); overload;
    constructor Create(const AAnchors: TAnchors;
      const AEvent: TScalarEvent); overload;

    function CalculateHashCode: UInt32; override;
    function Equals(const AOther: TYamlNode; const AStrict: Boolean): Boolean; override;
    procedure Emit(const AEmitter: TYamlEmitter); override;

    function ToBoolean(const ADefault: Boolean): Boolean; override;
    function ToInt32(const ADefault: Int32): Int32; override;
    function ToInt64(const ADefault: Int64): Int64; override;
    function ToDouble(const ADefault: Double): Double; override;
    function ToString(const ADefault: String): String; override;

  end;

  TAliasNode = class(TYamlNode)
  private
    FTarget: TYamlNode;

  protected
    function GetTarget: TYamlNode; override;
  public
    constructor Create(const ATarget: TYamlNode);
    function CalculateHashCode: UInt32; override;
    function Equals(const AOther: TYamlNode; const AStrict: Boolean): Boolean; override;
    procedure Emit(const AEmitter: TYamlEmitter); override;

  end;

  TSequenceNode = class(TYamlNode)
  private
    FNodes: TObjectList<TYamlNode>;
    FImplicit: Boolean;
    FStyle: TYamlSequenceStyle;
  private
    procedure Add(const ANode: TYamlNode); overload;
  protected
    function GetCount: Integer; override;
    function GetSequenceStyle: TYamlSequenceStyle; override;
    procedure SetSequenceStyle(const AStyle: TYamlSequenceStyle); override;

  public
    constructor Create; overload;
    constructor Create(const AAnchors: TAnchors;
      var AEvent: TSequenceStartEvent); overload;
    destructor Destroy; override;
    function CalculateHashCode: UInt32; override;
    function Equals(const AOther: TYamlNode; const AStrict: Boolean): Boolean; override;
    procedure Emit(const AEmitter: TYamlEmitter); override;

    function GetNode(const AIndex: Integer): TYamlNode; override;
    procedure Delete(const AIndex: Integer); override;
    procedure Clear;

        { Adds a value to the end of the sequence.

      Parameters:
        AValue: the value to add.

      Returns:
        The newly added node with this value.

      Raises:
        EInvalidOperation if this is not a sequence. }
    function Add(const AValue: Boolean): TYamlNode; overload; override;
    function Add(const AValue: Int32): TYamlNode; overload; override;
    function Add(const AValue: UInt32): TYamlNode; overload; override;
    function Add(const AValue: Int64): TYamlNode; overload; override;
    function Add(const AValue: UInt64): TYamlNode; overload; override;
    function Add(const AValue: Single): TYamlNode; overload; override;
    function Add(const AValue: Double): TYamlNode; overload; override;
    function Add(const AValue: String): TYamlNode; overload; override;

    { Creates a Sequence and adds it to the end of this Sequence.

      Returns:
        The newly created Sequence.

      Raises:
        EInvalidOperation if this is not a sequence. }
    function AddSequence: TYamlNode; override;

    { Creates a Mapping and adds it to the end of this Sequence.

      Returns:
        The newly created Mapping.

      Raises:
        EInvalidOperation if this is not a sequence. }
    function AddMapping: TYamlNode; override;

    { Creates an Alias and adds it to the end of this Sequence.

      Parameters:
        AAnchor: the anchor that the alias refers to.

      Returns:
        The newly created Alias.

      Raises:
        EInvalidOperation if this is not a sequence or AAnchor is null.

      Note: AAnchor *must* belong to the same IYamlDocument as this node.
      Behavior is undefined (or leads to crashes) if this is not the case. }
    function AddAlias(const AAnchor: TYamlNode): TYamlNode; override;


  end;

type
  TMappingNode = class(TYamlNode)
  private
    FElements: TMappingElements;
    FImplicit: Boolean;
    FStyle: TYamlMappingStyle;

    function GetMappingStyle: TYamlMappingStyle; override;
    procedure SetMappingStyle(const AStyle: TYamlMappingStyle); override;

  public
    constructor Create; overload;
    constructor Create(const AAnchors: TAnchors;
      var AEvent: TMappingStartEvent); overload;
    destructor Destroy; override;

    function CalculateHashCode: UInt32; override;
    function Equals(const AOther: TYamlNode; const AStrict: Boolean): Boolean; override;
    procedure Emit(const AEmitter: TYamlEmitter); override;

    procedure AddOrReplaceValue(const AKey, AValue: TYamlNode); overload;
    procedure AddOrReplaceValue(const AKey: String; const AValue: TYamlNode); overload;
    function GetValueByNode(const AKey: TYamlNode): TYamlNode; override;
    function GetValue(const AKey: String): TYamlNode; override;
    function GetKeys: TMappingElements.TKeyCollection; override;
    procedure Clear;

  public
        { Adds or replaces a value in the mapping.

          Parameters:
            AKey: the key of the value to add.
            AValue: the value to add.

          Returns:
            The newly created node for the given value.

          Raises:
            EInvalidOperation if this is not a mapping.

          If a value with the given key already exists in the mapping, then it
          is freed and replaced.

          The key can be a string of a IYamlValue. You only need to use an
          IYamlValue for non-string keys. To create one of those keys, call
          CreateSequenceKey, CreateMappingKey, CreateAliasKey or CreateScalarKey.}
    function AddOrSetValue(const AKey: String; const AValue: Boolean): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: Int32): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: UInt32): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: Int64): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: UInt64): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: Single): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: Double): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: String; const AValue: String): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Boolean): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Int32): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: UInt32): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Int64): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: UInt64): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Single): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: Double): TYamlNode;
      overload; override;
    function AddOrSetValue(const AKey: TYamlNode; const AValue: String): TYamlNode;
      overload; override;

        { Creates a sequence and adds or replaces it in this mapping.

          Parameters:
            AKey: the key of the sequence to add.

          Returns:
            The newly created sequence.

          Raises:
            EInvalidOperation if this is not a mapping.

          If a value with the given key already exists in the mapping, then it
          is freed and replaced.

          The key can be a string of a IYamlValue. You only need to use an
          IYamlValue for non-string keys. To create one of those keys, call
          CreateSequenceKey, CreateMappingKey, CreateAliasKey or CreateScalarKey.}
    function AddOrSetSequence(const AKey: String): TYamlNode; overload; override;
    function AddOrSetSequence(const AKey: TYamlNode): TYamlNode; overload; override;

        { Creates a mapping and adds or replaces it in this mapping.

          Parameters:
            AKey: the key of the mapping to add.

          Returns:
            The newly created mapping.

          Raises:
            EInvalidOperation if this is not a mapping.

          If a value with the given key already exists in the mapping, then it
          is freed and replaced.

          The key can be a string of a IYamlValue. You only need to use an
          IYamlValue for non-string keys. To create one of those keys, call
          CreateSequenceKey, CreateMappingKey, CreateAliasKey or CreateScalarKey.}
    function AddOrSetMapping(const AKey: String): TYamlNode; overload; override;
    function AddOrSetMapping(const AKey: TYamlNode): TYamlNode; overload; override;

        { Creates an Alias and adds or replaces it in this mapping.

          Parameters:
            AKey: the key of the alias to add.
            AAnchor: the anchor node that the alias refers to.

          Returns:
            The newly created Alias.

          Raises:
            EInvalidOperation if this is not a mapping or AAnchor is null.

          If a value with the given key already exists in the mapping, then it
          is freed and replaced.

          The key can be a string of a IYamlValue. You only need to use an
          IYamlValue for non-string keys. To create one of those keys, call
          CreateSequenceKey, CreateMappingKey, CreateAliasKey or CreateScalarKey.

          Note: AAnchor *must* belong to the same IYamlDocument as this node.
          Behavior is undefined (or leads to crashes) if this is not the case. }
    function AddOrSetAlias(const AKey: String; const AAnchor: TYamlNode): TYamlNode;
      overload; override;
    function AddOrSetAlias(const AKey: TYamlNode; const AAnchor: TYamlNode): TYamlNode;
      overload; override;

        { Checks if a key exists in the mapping.

          Parameters:
            AKey: the key to check.

          Returns:
            True if the mapping contains a value for the given key, or False
            otherwise.

          Raises:
            EInvalidOperation if this is not a mapping. }
    function Contains(const AKey: String): Boolean; overload; inline;
    function Contains(const AKey: TYamlNode): Boolean; overload; inline;

        { Removes a value from the mapping.

          Parameters:
            AKey: the key of the value to remove.

          Raises:
            EInvalidOperation if this is not a mapping.

          Does nothing if the mapping does not contain a value with the given key. }
    procedure Remove(const AKey: String); overload; inline;
    procedure Remove(const AKey: TYamlNode); overload; inline;

        { Tries to retrieve a value from the mapping.

          Parameters:
            AKey: the key of the value to retrieve.
            AValue: is set to the retrieved value, or to a Null value if the
              mapping does not contain AKey.

          Returns:
            True if the mapping contains a value with the given key, or False
            otherwise.

          Raises:
            EInvalidOperation if this is not a mapping. }
    function TryGetValue(const AKey: String; out AValue: TYamlNode): Boolean; overload; inline;
    function TryGetValue(const AKey: TYamlNode; out AValue: TYamlNode): Boolean;
      overload; inline;

        { The values in the mapping, indexed by key.

          Unlike the other mapping-methods, this property NEVER raises an exception.
          Instead, it returns a Null value if this is not a mapping or if the
          mapping does not contain the given key.

          This allows for chaining without having to check every intermediate step,
          as in Foo.Value['bar'].Values['baz'].ToInteger. }
    property Values[const AKey: String]: TYamlNode Read GetValue;
    property ValuesByNode[const AKey: TYamlNode]: TYamlNode Read GetValueByNode;

        { The elements (key/value pairs) in the mapping by index.

          Unlike the other mapping-methods, this property NEVER raises an exception.
          Instead, it returns a NULL element if this is not a mapping or if AIndex
          is out of range.

          NOTE: Do not cache the returned value; it is only valid until the
          mapping is deleted or modified. }
    //    property Elements[const AIndex: Integer]: TYamlElement Read GetElement;
  end;

type
  { Represents a YAML document.

    A document is a collection of TYamlNode's. These nodes are available through
    the Root property.

    You can load a document directly from a file or other source. If the file or
    source contains multiple documents, then only the first document is loaded.
    In that case, consider using IYamlStream instead, which can load one or
    more documents.

    This interface is implemented in the TYamlDocument class. }
  IYamlDocument = interface
    ['{9873838F-1546-4C2C-A91F-15451D0F98CC}']
    {$REGION 'Internal Declarations'}
    function GetRoot: TYamlNode;
    function GetFlags: TYamlDocumentFlags;
    procedure SetFlags(const AValue: TYamlDocumentFlags);
    function GetVersion: TYamlVersionDirective;
    procedure SetVersion(const AVersion: TYamlVersionDirective);
    function GetTagDirectives: TYamlTagDirectives;
    procedure SetTagDirectives(const AValue: TYamlTagDirectives);
    {$ENDREGION 'Internal Declarations'}

    { Saves the document to a file.

      Parameters:
        AFilename: the name of the file to save to.
        ASettings: (optional) output settings }
    procedure Save(const AFilename: String); overload;
    procedure Save(const AFilename: String; const ASettings: TYamlOutputSettings); overload;

    { Saves the document to a stream.

      Parameters:
        AStream: the stream to save to.
        ASettings: (optional) output settings }
    procedure Save(const AStream: TStream); overload;
    procedure Save(const AStream: TStream; const ASettings: TYamlOutputSettings); overload;

    procedure Emit(AEmitter: TYamlEmitter);

    { Converts the document to a string in YAML format.

      Parameters:
        ASettings: (optional) output settings

      Returns:
        The document in YAML format. }
    function ToYaml: TBytes; overload;
    function ToYaml(const ASettings: TYamlOutputSettings): TBytes; overload;

    { The root value of the document. }
    property Root: TYamlNode Read GetRoot;

    { Document flags }
    property Flags: TYamlDocumentFlags Read GetFlags Write SetFlags;

    { YAML version used for document.
      Defaults to 0.0 (not specified). }
    property Version: TYamlVersionDirective Read GetVersion Write SetVersion;

    { Tag directives used in this document, or nil for none. }
    property TagDirectives: TYamlTagDirectives Read GetTagDirectives Write SetTagDirectives;
  end;

type
  { Represents a YAML stream.

    A stream is a collection of IYamlDocument's. The stream source may contain
    0 or more documents, available through the Documents property and the
    enumerator.

    This interface is implemented in the TYamlStream class. }
  IYamlStream = interface
    ['{ADFB8B48-B69C-402E-B54B-23A68087D158}']
    {$REGION 'Internal Declarations'}
    function GetDocumentCount: Integer;
    function GetDocument(const AIndex: Integer): IYamlDocument;
    {$ENDREGION 'Internal Declarations'}

    { Creates a new document with an empty mapping as root, and adds it to the
      stream.

      Returns:
        The new document. }
    function AddMapping: IYamlDocument;

    { Creates a new document with an empty sequence as root, and adds it to the
      stream.

      Returns:
        The new document. }
    function AddSequence: IYamlDocument;

    { Creats a new document with a single scalar value, and adds it to the
      stream.

      Parameters:
        AValue: the scalar value

      Returns:
        The new document. }
    function AddScalar(const AValue: String): IYamlDocument;

    { Saves the stream to a file.

      Parameters:
        AFilename: the name of the file to save to.
        ASettings: (optional) output settings }
    procedure Save(const AFilename: String); overload;
    procedure Save(const AFilename: String; const ASettings: TYamlOutputSettings); overload;

    { Saves the yaml stream to a TStream.

      Parameters:
        AStream: the stream to save to.
        ASettings: (optional) output settings }
    procedure Save(const AStream: TStream); overload;
    procedure Save(const AStream: TStream; const ASettings: TYamlOutputSettings); overload;



    { Converts the document to a string in YAML format.

      Parameters:
        ASettings: (optional) output settings

      Returns:
        The document in YAML format. }
    function ToYaml: TBytes; overload;
    function ToYaml(const ASettings: TYamlOutputSettings): TBytes; overload;

    { The number of documents in the stream }
    property DocumentCount: Integer Read GetDocumentCount;

    { The documents in the stream }
    property Documents[const AIndex: Integer]: IYamlDocument Read GetDocument; default;
  end;

type
  { A YAML document. Implements the IYamlDocument interface. }
  TYamlDocument = class(TInterfacedObject, IYamlDocument)
  {$REGION 'Internal Declarations'}
  private
    FRoot: TYamlNode;
    FVersion: TYamlVersionDirective;
    FFlags: TYamlDocumentFlags;
    FTagDirectives: TYamlTagDirectives;
  private
    class function ParseInternal(const AParser: TYamlParser;
      const ADocumentEvent: TDocumentStartEvent): IYamlDocument; static;
  private
    constructor Create(const ARoot: TYamlNode); overload;
    constructor Create(const ARoot: TYamlNode;
      const AEvent: TDocumentStartEvent); overload;
    procedure Emit(AEmitter: TYamlEmitter);
  protected
    { IYamlDocument }
    function GetRoot: TYamlNode;
    function GetFlags: TYamlDocumentFlags;
    procedure SetFlags(const AValue: TYamlDocumentFlags);
    function GetVersion: TYamlVersionDirective;
    procedure SetVersion(const AVersion: TYamlVersionDirective);
    function GetTagDirectives: TYamlTagDirectives;
    procedure SetTagDirectives(const AValue: TYamlTagDirectives);
    procedure Save(const AFilename: String); overload;
    procedure Save(const AFilename: String; const ASettings: TYamlOutputSettings); overload;
    procedure Save(const AStream: TStream); overload;
    procedure Save(const AStream: TStream; const ASettings: TYamlOutputSettings); overload;
    function ToYaml: TBytes; overload;
    function ToYaml(const ASettings: TYamlOutputSettings): TBytes; overload;
  public
    constructor Create; overload; deprecated 'Use CreateMapping, CreateSequence, Parse or Load';
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a new document with an empty mapping as root.

      Returns:
        The new document.

      Use the Root property to start adding nodes to the mapping. }
    class function CreateMapping: IYamlDocument; static;

    { Creates a new document with an empty sequence as root.

      Returns:
        The new document.

      Use the Root property to start adding nodes to the sequence. }
    class function CreateSequence: IYamlDocument; static;

    { Creats a new document with a single scalar value as root.

      Parameters:
        AValue: the scalar value

      Returns:
        The new document. }
    class function CreateScalar(const AValue: String): IYamlDocument; static;

    destructor Destroy; override;

    { Parses a YAML string into a YAML document.

      Parameters:
        AYaml: the YAML formatted string to parse.

      Returns:
        The document or nil in case AYaml is empty.

      Raises:
        EYamlParserError if AYaml is invalid

      If the source string contains more than one document, then only the
      first document is loaded. To load all the documents in a multi-document
      source, use TYamlStream.Parse instead. }
    class function Parse(const AYaml: String): IYamlDocument; overload; static;

    { Loads a YAML document from a file.

      Parameters:
        AFilename: the name of the file to load.

      Returns:
        The document or nil in case the file is empty.

      Raises:
        EYamlParserError if the file does not contain valid YAML. }
    class function Load(const AFilename: String): IYamlDocument; overload; static;

    { Loads a YAML document from a stream.

      Parameters:
        AStream: the stream to load.

      Returns:
        The document or nil in case the stream is empty.

      Raises:
        EYamlParserError if the stream does not contain valid YAML. }
    class function Load(const AStream: TStream): IYamlDocument; overload; static;
  end;

type
  { A YAML stream. Implements the IYamlStream interface. }
  TYamlStream = class(TInterfacedObject, IYamlStream)
  {$REGION 'Internal Declarations'}
  private
    FDocuments: TArray<IYamlDocument>;
  private
    class function ParseInternal(const AParser: TYamlParser): IYamlStream; static;
  private
    constructor Create(const ADocuments: TArray<IYamlDocument>); overload;
  protected
    { IYamlStream }
    function GetDocumentCount: Integer;
    function GetDocument(const AIndex: Integer): IYamlDocument;
    function AddMapping: IYamlDocument;
    function AddSequence: IYamlDocument;
    function AddScalar(const AValue: String): IYamlDocument;
    function ToYaml: TBytes; overload;
    function ToYaml(const ASettings: TYamlOutputSettings): TBytes; overload;
    procedure Save(const AFilename: String); overload;
    procedure Save(const AFilename: String; const ASettings: TYamlOutputSettings); overload;
    procedure Save(const AStream: TStream); overload;
    procedure Save(const AStream: TStream; const ASettings: TYamlOutputSettings); overload;
  {$ENDREGION 'Internal Declarations'}
  public
    { Create a new empty stream }
    constructor Create; overload;

    { Parses a YAML string into a YAML stream.

      Parameters:
        AYaml: the YAML formatted string to parse.

      Returns:
        The stream or nil in case AYaml is empty.

      Raises:
        EYamlParserError if AYaml is invalid }
    class function Parse(const AYaml: String): IYamlStream; overload; static;

    { Loads a YAML stream from a file.

      Parameters:
        AFilename: the name of the file to load.

      Returns:
        The stream or nil in case the file is empty.

      Raises:
        EYamlParserError if the file does not contain valid YAML. }
    class function Load(const AFilename: String): IYamlStream; overload; static;

    { Loads a YAML stream from a stream.

      Parameters:
        AStream: the stream to load.

      Returns:
        The stream or nil in case the stream is empty.

      Raises:
        EYamlParserError if the stream does not contain valid YAML. }
    class function Load(const AStream: TStream): IYamlStream; overload; static;
  end;

//const
//  _YAML_NULL_ELEMENT: TYamlElement = (FKey: (FBits: 0); FValue: (FBits: 0));

implementation

uses
  Murmur3;

const
  Murmur3_Seed: UInt32 = $54321ABC;

var
  { A TFormatSettings record configured for US number settings.
    It uses a period (.) as a decimal separator and comma (,) as thousands
    separator.
    Can be used to convert strings to floating-point values in cases where the
    strings are always formatted to use periods as decimal separators
    (regardless of locale). }
  USFormatSettings: TFormatSettings;


(*
procedure SetupEmitter(const ASettings: TYamlOutputSettings;
  out AEmitter: TYamlEmitter; out AStream: TStream);
begin
  AEmitter := TYamlEmitter.Create;

  AEmitter.SetOutput(AStream);
  AEmitter.SetCanonical(ASettings.Canonical);
  AEmitter.SetIndent(ASettings.Indent);
  AEmitter.SetWidth(ASettings.LineWidth);
  AEmitter.SetBreak(ASettings.LineBreak);
end;
*)

{ TYamlOutputSettings }

class function TYamlOutputSettings.Create: TYamlOutputSettings;
begin
  Result.Initialize;
end;

procedure TYamlOutputSettings.Initialize;
begin
  Canonical := False;
  Indent := 2;
  LineWidth := -1;
  LineBreak := ybrkAnyBreak;
end;

{ TYamlNode }

function TSequenceNode.AddAlias(const AAnchor: TYamlNode): TYamlNode;
begin
  Result := TAliasNode.Create(AAnchor);
  Add(Result);
end;

function TSequenceNode.Add(const AValue: Int64): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  Add(Result);
end;

function TSequenceNode.Add(const AValue: UInt32): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  Add(Result);
end;

function TSequenceNode.Add(const AValue: Int32): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  Add(Result);
end;

function TSequenceNode.Add(const AValue: Boolean): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  Add(Result);
end;

function TSequenceNode.Add(const AValue: UInt64): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  Add(Result);
end;

function TSequenceNode.Add(const AValue: String): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  Add(Result);
end;

function TSequenceNode.Add(const AValue: Double): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  Add(Result);
end;

function TSequenceNode.Add(const AValue: Single): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  Add(Result);
end;

function TSequenceNode.AddMapping: TYamlNode;
begin
  Result := TMappingNode.Create;
  Add(Result);
end;

function TMappingNode.AddOrSetAlias(const AKey: String;
  const AAnchor: TYamlNode): TYamlNode;
begin
  Result := TAliasNode.Create(AAnchor);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetAlias(const AKey: TYamlNode; const AAnchor: TYamlNode): TYamlNode;
begin
  Result := TAliasNode.Create(AAnchor);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetMapping(const AKey: String): TYamlNode;
begin
  Result := TMappingNode.Create;
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetMapping(const AKey: TYamlNode): TYamlNode;
begin
  Result := TMappingNode.Create;
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetSequence(const AKey: String): TYamlNode;
begin
  Result := TSequenceNode.Create;
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetSequence(const AKey: TYamlNode): TYamlNode;
begin
  Result := TSequenceNode.Create;
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey, AValue: String): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: Double): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: Int64): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: UInt32): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: Int32): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: Boolean): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: Single): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: String; const AValue: UInt64): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: String): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Double): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Int64): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: UInt32): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Int32): TYamlNode;
begin
  Result := TScalarNode.Create(IntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Boolean): TYamlNode;
begin
  Result := TScalarNode.Create(AValue);
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Single): TYamlNode;
begin
  Result := TScalarNode.Create(FloatToStr(AValue, USFormatSettings));
  AddOrReplaceValue(AKey, Result);
end;

function TMappingNode.AddOrSetValue(const AKey: TYamlNode; const AValue: UInt64): TYamlNode;
begin
  Result := TScalarNode.Create(UIntToStr(AValue));
  AddOrReplaceValue(AKey, Result);
end;

function TSequenceNode.AddSequence: TYamlNode;
begin
  Result := TSequenceNode.Create;
  Add(Result);
end;

procedure TYamlNode.Clear;
begin
  raise EInvalidOperation.Create('Clear can only be used for YAML Sequences and Mappings');
end;

constructor TAliasNode.Create(const ATarget: TYamlNode);
begin
  inherited Create;

  FTarget := ATarget;
end;

constructor TMappingNode.Create(const AAnchors: TAnchors;
  var AEvent: TMappingStartEvent);
begin
  inherited Create;

  { Take ownership of anchor and tag }
  Init(AAnchors, AEvent.anchor, AEvent.tag);

  FElements := TObjectDictionary<TYamlNode, TYamlNode>.Create([doOwnsKeys, doOwnsValues]);
  FImplicit := AEvent.implicit;
  FStyle := AEvent.mappingStyle;
end;

constructor TMappingNode.Create;
begin
  inherited Create;

  FElements := TObjectDictionary<TYamlNode, TYamlNode>.Create([doOwnsKeys, doOwnsValues]);
  FImplicit := False;
  FStyle := ympAnyStyle;
end;

constructor TScalarNode.Create(const AAnchors: TAnchors;
  const AEvent: TScalarEvent);
begin
  inherited Create;
  Init(AAnchors, AEvent.anchor, AEvent.tag);
  FValue := AEvent.value;

  FFlags := [];
  if (AEvent.plainImplicit) then
    Include(FFlags, ysfPlainImplicit);
  if (AEvent.quotedImplicit) then
    Include(FFlags, ysfQuotedImplicit);
  FStyle := AEvent.scalarStyle;
end;

constructor TScalarNode.Create(const AValue: Boolean);
begin
  inherited Create;

  if (AValue) then
    FValue := 'true'
  else
    FValue := 'false';
  FFlags := [ysfPlainImplicit];
  FStyle := yssAnyStyle;
end;

constructor TScalarNode.Create(const AValue: String);
begin
  inherited Create;

  Init(nil, '', '');
  FValue := AValue;
  FFlags := [ysfPlainImplicit];
  FStyle := yssAnyStyle;
end;

constructor TSequenceNode.Create;
begin
  inherited Create;

  FNodes := TObjectList<TYamlNode>.Create(True);
  FImplicit := False;
  FStyle := ysqAnyStyle;
end;

constructor TSequenceNode.Create(const AAnchors: TAnchors;
  var AEvent: TSequenceStartEvent);
begin
  inherited Create;

  Init(AAnchors, AEvent.anchor, AEvent.tag);

  FNodes := TObjectList<TYamlNode>.Create(True);
  FImplicit := AEvent.implicit;
  FStyle := AEvent.sequenceStyle;
end;

destructor TSequenceNode.Destroy;
begin
  FNodes.Free;
  inherited;
end;

procedure TYamlNode.Delete(const AIndex: Integer);
begin
  raise EInvalidOperation.Create('Delete can only be used for YAML Sequences and Mappings');
end;

function TYamlNode.GetAnchor: String;
begin
  Result := FAnchor;
end;

function TYamlNode.GetCount: Integer;
begin
  Result := 0;
end;

function TYamlNode.GetHashCode: UInt32;
begin
  if not FHashCalculated then begin
    FHash := CalculateHashCode;
    FHashCalculated := True;
  end;
  Result := FHash;
end;

function TMappingNode.GetMappingStyle: TYamlMappingStyle;
begin
  Result := FStyle;
end;

function TSequenceNode.GetCount: Integer;
begin
  Result := FNodes.Count;
end;

function TSequenceNode.GetSequenceStyle: TYamlSequenceStyle;
begin
  Result := FStyle;
end;

procedure TSequenceNode.SetSequenceStyle(const AStyle: TYamlSequenceStyle);
begin
  FStyle := AStyle;
end;

function TYamlNode.GetTag: String;
begin
  Result := FTag;
end;

function TAliasNode.GetTarget: TYamlNode;
begin
  Result := FTarget;
end;

class function TYamlNode.ParseInternal(const AParser: TYamlParser;
  const AAnchors: TAnchors; var ANodeEvent: TYamlEvent): TYamlNode;
var
  Event: TYamlEvent;
  Key, Value, Anchor: TYamlNode;
  Mapping: TMappingNode;
  Sequence: TSequenceNode;
  AnchorName: String;
  mark: TYamlMark;
begin
  if ANodeEvent is TScalarEvent then begin
      Result := TScalarNode.Create(AAnchors, TScalarEvent(ANodeEvent));
  end
  else if ANodeEvent is TSequenceStartEvent then begin
      Sequence := TSequenceNode.Create(AAnchors, TSequenceStartEvent(ANodeEvent));
      try
        while True do begin
          Event := AParser.parse;
          try
            if (Event is TSequenceEndEvent) then
              Break;

            Value := TYamlNode.ParseInternal(AParser, AAnchors, Event);
          finally
            Event.Free;
          end;
          Sequence.Add(Value);
        end;
      except
        Sequence.Free;
        raise;
      end;
      Result := Sequence;
    end
  else if ANodeEvent is TMappingStartEvent then begin
      Mapping := TMappingNode.Create(AAnchors, TMappingStartEvent(ANodeEvent));
      try
        while True do begin
          Event := AParser.parse;
          try
            if (Event is TMappingEndEvent) then
              Break;

            Key := TYamlNode.ParseInternal(AParser, AAnchors, Event);
          finally
            Event.Free;
          end;

          Event := AParser.parse;
          try
            Value := TYamlNode.ParseInternal(AParser, AAnchors, Event);
          finally
            Event.Free;;
          end;

          Mapping.AddOrReplaceValue(Key, Value);
        end
      except
        Mapping.Free;
        raise;
      end;
      Result := Mapping;
    end
  else if ANodeEvent is TAliasEvent then begin
      AnchorName := TAliasEvent(ANodeEvent).anchor;
      if (not AAnchors.TryGetValue(AnchorName, Anchor)) then begin
        raise EYamlParserError.Create(
          Format('Referencing alias (%s) to unknown anchor in YAML stream',
          [AnchorName]), mark);
      end;
      Result := TAliasNode.Create(Anchor);
    end
    else
      raise EYamlParserError.Create(
        'Expected Scalar, Sequence, Map or Alias event in YAML source', mark);
end;

procedure TYamlNode.SetAnchor(const AValue: String);
begin
  FAnchor := AValue;
end;

function TYamlNode.GetMappingStyle: TYamlMappingStyle;
begin
  raise EInvalidOperation.Create('MappingStyle can only be used for YAML Mappings');
end;

procedure TYamlNode.SetMappingStyle(const AStyle: TYamlMappingStyle);
begin
  raise EInvalidOperation.Create('MappingStyle can only be used for YAML Mappings');
end;

function TYamlNode.GetScalarStyle: TYamlScalarStyle;
begin
  raise EInvalidOperation.Create('ScalarStyle can only be used for YAML Scalar');
end;

procedure TYamlNode.SetScalarStyle(const AStyle: TYamlScalarStyle);
begin
  raise EInvalidOperation.Create('ScalarStyle can only be used for YAML Scalar');
end;

function TYamlNode.GetScalarFlags: TYamlScalarFlags;
begin
  raise EInvalidOperation.Create('ScalarFlags can only be used for YAML Scalar');
end;

procedure TYamlNode.SetScalarFlags(const AFlags: TYamlScalarFlags);
begin
  raise EInvalidOperation.Create('ScalarFlags can only be used for YAML Scalar');
end;

function TYamlNode.GetSequenceStyle: TYamlSequenceStyle;
begin
  raise EInvalidOperation.Create('SequenceStyle can only be used for YAML Sequence');
end;

procedure TYamlNode.SetSequenceStyle(const AStyle: TYamlSequenceSTyle);
begin
  raise EInvalidOperation.Create('SequenceStyle can only be used for YAML Sequence');
end;


procedure TMappingNode.SetMappingStyle(const AStyle: TYamlMappingStyle);
begin
  FStyle := AStyle;
end;

function TScalarNode.GetScalarFlags: TYamlScalarFlags;
begin
  Result := FFlags;
end;

procedure TScalarNode.SetScalarFlags(const AFlags: TYamlScalarFlags);
begin
  FFlags := AFlags;
end;

function TScalarNode.GetScalarStyle: TYamlScalarStyle;
begin
  Result := FStyle;
end;

procedure TScalarNode.SetScalarStyle(const AStyle: TYamlScalarStyle);
begin
  FStyle := AStyle;
end;

procedure TYamlNode.SetTag(const AValue: String);
begin
  FTag := AValue;
end;

function TYamlNode.StrictEquals(const AOther: TYamlNode): Boolean;
begin
  Result := Equals(AOther, True);
end;

function TYamlNode.ToBoolean(const ADefault: Boolean): Boolean;
begin
  Result := ADefault;
end;

function TYamlNode.ToDouble(const ADefault: Double): Double;
begin
  Result := ADefault;
end;

function TYamlNode.ToInt32(const ADefault: Int32): Int32;
begin
  Result := ADefault;
end;

function TYamlNode.ToInt64(const ADefault: Int64): Int64;
begin
  Result := ADefault;
end;

function TYamlNode.ToInteger(const ADefault: Integer): Integer;
begin
  Result := ToInt32(ADefault);
end;

function TYamlNode.ToString(const ADefault: String): String;
begin
  Result := ADefault;
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: Boolean): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: Int32): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: UInt32): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: Int64): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: UInt64): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: Single): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: Double): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: String; const AValue: String): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Boolean): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Int32): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: UInt32): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Int64): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: UInt64): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Single): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: Double): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetValue(const AKey: TYamlNode; const AValue: String): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetValue can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetMapping(const AKey: String): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetMapping can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetMapping(const AKey: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetMapping can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetAlias(const AKey: String; const AAnchor: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetAlias can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetAlias(const AKey: TYamlNode; const AAnchor: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetAlias can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetSequence(const AKey: String): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetSequence can only be used for YAML Mappings');
end;

function TYamlNode.AddOrSetSequence(const AKey: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('AddOrSetSequence can only be used for YAML Mappings');
end;

function TYamlNode.Add(const AValue: Boolean): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: Int32): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: UInt32): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: Int64): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: UInt64): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: Single): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: Double): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;

function TYamlNode.Add(const AValue: String): TYamlNode;
begin
  raise EInvalidOperation.Create('Add can only be used for YAML Sequence');
end;


function TYamlNode.AddSequence: TYamlNode;
begin
  raise EInvalidOperation.Create('AddSequence can only be used for YAML Sequence');
end;

function TYamlNode.AddMapping: TYamlNode;
begin
  raise EInvalidOperation.Create('AddMapping can only be used for YAML Sequence');
end;

function TYamlNode.AddAlias(const AAnchor: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('AddAlias can only be used for YAML Sequence');
end;

function TYamlNode.GetValue(const AKey: string): TYamlNode;
begin
  raise EInvalidOperation.Create('GetValue can only be used for YAML Mappings');
end;

function TYamlNode.GetValueByNode(const AKey: TYamlNode): TYamlNode;
begin
  raise EInvalidOperation.Create('GetValueByNode can only be used for YAML Mappings');
end;

function TYamlNode.GetKeys: TMappingElements.TKeyCollection;
begin
  raise EInvalidOperation.Create('GetKeys can only be used for YAML Mappings');
end;

function TYamlNode.GetTarget: TYamlNode;
begin
  raise EInvalidOperation.Create('GetTarget can only be used for YAML Alias');
end;

function TYamlNode.GetNode(const AIndex: Integer): TYamlNode;
begin
 raise EInvalidOperation.Create('GetNode can only be used for YAML Sequence');
end;

procedure TYamlNode.Init(const AAnchors: TAnchors;
  const AAnchor, ATag: String);
begin
  { Take ownership }
  FAnchor := AAnchor;
  FTag := ATag;
  FHash := 0;
  FHashCalculated := False;

  if (AAnchor <> '') then begin
    Assert(AAnchors <> nil);
    AAnchors.AddOrSetValue(AAnchor, Self);
  end;
end;

function TYamlNode.Equals(const AOther: TYamlNode; const AStrict: Boolean
  ): Boolean;
begin
  Result := (FAnchor = AOther.FAnchor) and (FTag = AOther.FTag);
end;

{ TYamlNode.TScalar }

function TScalarNode.CalculateHashCode: UInt32;
begin
  Result := murmur3_32(PByte(PChar(FValue)), Length(FValue), Murmur3_Seed);
end;

procedure TScalarNode.Emit(const AEmitter: TYamlEmitter);
var
  PlainImplicit: Boolean;
begin
  if (FAnchor <> '') and AEmitter.HasAnchor(FAnchor) then begin
    AEmitter.AliasEvent(FAnchor);
  end
  else begin
    if FTag = '' then
      PlainImplicit := (ysfPlainImplicit in FFlags)
    else
      PlainImplicit := false;

    AEmitter.ScalarEvent(FAnchor, FTag, FValue, PlainImplicit, ysfQuotedImplicit in FFlags, FStyle);
  end;
end;

function TScalarNode.Equals(const AOther: TYamlNode;
  const AStrict: Boolean): Boolean;
begin
  if not (AOther is TScalarNode) then
    Exit(False);

  if (FValue <> TScalarNode(AOther).FValue) then
    Exit(False);

  if (AStrict) then
    Exit(inherited Equals(AOther, AStrict));

  Exit(True);
end;

function TScalarNode.ToBoolean(const ADefault: Boolean): Boolean;
begin
  if (Length(FValue) = 4) then begin
    if ((FValue[1] = 'T') or (FValue[1] = 't')) and
      ((FValue[2] = 'R') or (FValue[2] = 'r')) and
      ((FValue[3] = 'U') or (FValue[3] = 'u')) and
      ((FValue[4] = 'E') or (FValue[4] = 'e'))
    then
      Result := True
    else
      Result := ADefault;
  end
  else
  if (Length(FValue) = 5) then begin
    if ((FValue[1] = 'F') or (FValue[1] = 'f')) and
      ((FValue[2] = 'A') or (FValue[2] = 'a')) and
      ((FValue[3] = 'L') or (FValue[3] = 'l')) and
      ((FValue[4] = 'S') or (FValue[4] = 's')) and
      ((FValue[5] = 'E') or (FValue[5] = 'e'))
    then
      Result := False
    else
      Result := ADefault;
  end
  else
    Result := ADefault;
end;

function TScalarNode.ToDouble(const ADefault: Double): Double;
begin
  Result := StrToFloatDef(FValue, ADefault, USFormatSettings);
end;

function TScalarNode.ToInt32(const ADefault: Int32): Int32;
begin
  Result := StrToIntDef(FValue, ADefault);
end;

function TScalarNode.ToInt64(const ADefault: Int64): Int64;
begin
  Result := StrToInt64Def(FValue, ADefault);
end;

function TScalarNode.ToString(const ADefault: String): String;
begin
  Result := FValue;
end;

{ TYamlNode.TSequence }

procedure TSequenceNode.Add(const ANode: TYamlNode);
begin
  FHashCalculated := False;
  FNodes.Add(ANode);
end;

function TSequenceNode.CalculateHashCode: UInt32;
var
  HashCodes: TArray<UInt32>;
  I: Integer;
begin
  SetLength(HashCodes, FNodes.Count);
  for I := 0 to FNodes.Count - 1 do
    HashCodes[I] := FNodes[I].GetHashCode;
  Result := murmur3_32(@HashCodes[0], FNodes.Count * SizeOf(UInt32), Murmur3_Seed);
end;

procedure TSequenceNode.Clear;
begin
  FNodes.Clear;
  FHashCalculated := False;
end;

procedure TSequenceNode.Delete(const AIndex: Integer);
begin
  FNodes.Delete(AIndex);
end;

procedure TSequenceNode.Emit(const AEmitter: TYamlEmitter);
var
  I: Integer;
begin
  if (FAnchor <> '') and AEmitter.HasAnchor(FAnchor) then begin
    AEmitter.AliasEvent(FAnchor);
  end
  else begin
    AEmitter.SequenceStartEvent(FAnchor, FTag, FImplicit, FStyle);

    for I := 0 to FNodes.Count - 1 do begin
      FNodes[I].Emit(AEmitter);
    end;

    AEmitter.SequenceEndEvent;
  end;
end;

function TSequenceNode.Equals(const AOther: TYamlNode;
  const AStrict: Boolean): Boolean;
var
  I: Integer;
begin
  if not (AOther is TSequenceNode) then
    Exit(False);

  if (FNodes.Count <> TSequenceNode(AOther).FNodes.Count) then
    Exit(False);

  if (AStrict) then begin
    if (not inherited Equals(AOther, AStrict)) then
      Exit(False);
  end;

  for I := 0 to FNodes.Count - 1 do begin
    if (not FNodes[I].Equals(TSequenceNode(AOther).FNodes[I], AStrict)) then
      Exit(False);
  end;

  Result := True;
end;

function TSequenceNode.GetNode(const AIndex: Integer): TYamlNode;
begin
  Result := FNodes[AIndex];
end;

{ TAliasNode }

function TAliasNode.CalculateHashCode: UInt32;
begin
  Result := UInt32(UIntPtr(FTarget) and $FFFFFFFF);
end;

procedure TAliasNode.Emit(const AEmitter: TYamlEmitter);
begin
  if AEmitter.HasAnchor(FTarget.FAnchor) then begin
     AEmitter.AliasEvent(FTarget.FAnchor);
  end
  else begin
    // the anchor doesn't exist yet, so emit the target in its place
    FTarget.Emit(AEmitter);
  end;
end;

function TAliasNode.Equals(const AOther: TYamlNode;
  const AStrict: Boolean): Boolean;
begin
  if not (AOther is TAliasNode) then
    Exit(False);

  Result := FTarget.FAnchor = TAliasNode(AOther).FTarget.FAnchor;

  if (Result and AStrict) then
    Result := inherited Equals(AOther, AStrict);
end;

{ TYamlNode.TMapping }

procedure TMappingNode.AddOrReplaceValue(const AKey, AValue: TYamlNode);
begin
  FElements.AddOrSetValue(AKey, AValue);
  FHashCalculated := False;
end;

procedure TMappingNode.AddOrReplaceValue(const AKey: String;
  const AValue: TYamlNode);
begin
  FElements.AddOrSetValue(TScalarNode.Create(AKey), AValue);
  FHashCalculated := False;
end;

function TMappingNode.CalculateHashCode: UInt32;
var
  HashCodes: TArray<UInt32>;
  I: Integer;
  v: TYamlNode;
begin
  SetLength(HashCodes, FElements.Count);
  i := 0;
  for v in FElements.Values do begin
    HashCodes[I] := v.GetHashCode;
    Inc(I);
  end;
  Result := murmur3_32(@HashCodes[0], Length(HashCodes) * SizeOf(UInt32), Murmur3_Seed);
end;

procedure TMappingNode.Clear;
var
  I: Integer;
begin
  FElements.Clear;
  FHashCalculated := False;
end;

function TMappingNode.Contains(const AKey: String): Boolean;
var
  scalar: TScalarNode;
begin
  scalar := TScalarNode.Create(AKey);
  try
    Result := FElements.ContainsKey(scalar);

  finally
    scalar.Free;
  end;
end;

function TMappingNode.Contains(const AKey: TYamlNode): Boolean;
begin
  Result := FElements.ContainsKey(AKey);
end;

procedure TMappingNode.Emit(const AEmitter: TYamlEmitter);
var
  k: TYamlNode;
  v: TYamlNode;
begin
  if (FAnchor <> '') and AEmitter.HasAnchor(FAnchor) then begin
    AEmitter.AliasEvent(FAnchor);
  end
  else begin
    AEmitter.MappingStartEvent(FAnchor, FTag, FImplicit, FStyle);

    for k in FElements.Keys do begin
      v := FElements[k];
      k.Emit(AEmitter);
      v.Emit(AEmitter);
    end;

    AEmitter.MappingEndEvent;
  end;
end;

function TMappingNode.Equals(const AOther: TYamlNode;
  const AStrict: Boolean): Boolean;
var
  k: TYamlNode;
begin
  if not (AOther is TMappingNode) then
    Exit(False);

  if (FElements.Count <> TMappingNode(AOther).FElements.Count) then
    Exit(False);

  if (AStrict) then begin
    if (not inherited Equals(AOther, AStrict)) then
      Exit(False);
  end;

  for k in FElements.keys do begin
    if not TMappingNode(AOther).FElements.ContainsKey(k) then
      Exit(False);

    if not FElements[k].Equals(TMappingNode(AOther).FElements[k], AStrict) then
      Exit(False);
  end;

  Result := True;
end;

destructor TMappingNode.Destroy;
begin
  FElements.Free;
  inherited;
end;

function TMappingNode.GetValueByNode(const AKey: TYamlNode): TYamlNode;
begin
  if FElements.ContainsKey(AKey) then
    Result := FElements[AKey]
  else
    Result := nil;
end;

function TMappingNode.GetValue(const AKey: String): TYamlNode;
var
  key: TScalarNode;
begin
  key := TScalarNode.Create(AKey);
  try
    Exit(GetValueByNode(key));
  finally
    key.Free;
  end;
end;

function TMappingNode.GetKeys: TMappingElements.TKeyCollection;
begin
  Result := FElements.Keys;
end;

procedure TMappingNode.Remove(const AKey: String);
var
  key: TScalarNode;
begin
  key := TScalarNode.Create(AKey);
  try
    Remove(key);
  finally
    key.Free;
  end;
end;

procedure TMappingNode.Remove(const AKey: TYamlNode);
begin
  FElements.Remove(AKey);
end;

function TMappingNode.TryGetValue(const AKey: String; out AValue: TYamlNode): Boolean;
var
  key: TScalarNode;
begin
  key := TScalarNode.Create(AKey);
  try
    Result := TryGetValue(key, AValue);
  finally
    key.Free;
  end;
end;

function TMappingNode.TryGetValue(const AKey: TYamlNode;
  out AValue: TYamlNode): Boolean;
begin
  Result := FElements.TryGetValue(AKey, AValue);
end;

{ TYamlDocument }

constructor TYamlDocument.Create;
begin
  raise EInvalidOperation.Create(
    'To create a new YAML document, use CreateMapping or CreateSequence.' + sLineBreak +
    'To load a YAML document, use Parse or Load.');
end;

constructor TYamlDocument.Create(const ARoot: TYamlNode);
begin
  inherited Create;
  FRoot := ARoot;
  FVersion.Initialize();
end;

constructor TYamlDocument.Create(const ARoot: TYamlNode;
  const AEvent: TDocumentStartEvent);
var
  i, count: Integer;
begin
  inherited Create;
  FRoot := ARoot;
  FVersion.Initialize();

  if (AEvent.versionDirective.Major > 0) then
    FVersion := AEvent.versionDirective;

  if Assigned(AEvent.tagDirectives) then begin
    Count := Length(AEvent.tagDirectives);
    SetLength(FTagDirectives, Count);
    for i := 0 to Count - 1 do begin
      FTagDirectives[i].Handle := AEvent.tagDirectives[i].Handle;
      FTagDirectives[i].Prefix := AEvent.tagDirectives[i].Prefix;
    end;
  end;
end;

class function TYamlDocument.CreateMapping: IYamlDocument;
begin
  Result := TYamlDocument.Create(TMappingNode.Create);
end;

class function TYamlDocument.CreateScalar(const AValue: String): IYamlDocument;
begin
  Result := TYamlDocument.Create(TScalarNode.Create(AValue));
end;

class function TYamlDocument.CreateSequence: IYamlDocument;
begin
  Result := TYamlDocument.Create(TSequenceNode.Create);
end;

destructor TYamlDocument.Destroy;
begin
  FRoot.Free;
  inherited;
end;

procedure TYamlDocument.Emit(AEmitter: TYamlEmitter);
begin
  if not Assigned(FRoot) then
    Exit;

  AEmitter.DocumentStartEvent(FVersion, FTagDirectives, (ydfImplicitStart in FFlags));

  FRoot.Emit(AEmitter);

  AEmitter.DocumentEndEvent(ydfImplicitEnd in FFlags);
end;

function TYamlDocument.GetFlags: TYamlDocumentFlags;
begin
  Result := FFlags;
end;

function TYamlDocument.GetRoot: TYamlNode;
begin
  Result := FRoot;
end;

function TYamlDocument.GetTagDirectives: TYamlTagDirectives;
begin
  Result := FTagDirectives;
end;

function TYamlDocument.GetVersion: TYamlVersionDirective;
begin
  Result := FVersion;
end;

class function TYamlDocument.Load(const AStream: TStream): IYamlDocument;
var
  Yaml: String;
  Size: Integer;
begin
  Size := AStream.Size - AStream.Position;
  if (Size = 0) then
    Exit(nil);

  SetLength(Yaml, Size);
  AStream.ReadBuffer(Yaml[Low(String)], Size);
  Result := Parse(Yaml);
end;

class function TYamlDocument.Load(const AFilename: String): IYamlDocument;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFilename, fmOpenRead or fmShareDenyWrite);
  try
    Result := Load(Stream);
  finally
    Stream.Free;
  end;
end;

class function TYamlDocument.Parse(const AYaml: String): IYamlDocument;
var
  parser: TYamlParser;
  event: TYamlEvent;
  inputStream: TStringStream;
  mark: TYamlMark;
begin
  if (AYaml = '') then
    Exit(nil);

  mark.Initialize;

  inputStream := TStringStream.Create(AYaml);
  try
    parser := TYamlParser.Create;
    try
      parser.SetInput(inputStream);

      { LibYaml always raises a STREAM_START event first, even when the source
        contains a single document. }
      event := parser.parse;
      if not (Event is TStreamStartEvent) then begin
        event.Free;
        raise EYamlParserError.Create('Expected stream start event in YAML source', mark);
      end;
      FreeAndNil(event);

      { This should be followed by a DOCUMENT_START event. }
      event := parser.Parse;
      if not (event is TDocumentStartEvent) then begin
        event.Free;
        raise EYamlParserError.Create('Expected document start event in YAML source', mark);
      end;

      Result := ParseInternal(parser, TDocumentStartEvent(event));
    finally
      parser.Free;
      event.Free;
    end;
  finally
    inputStream.Free;
  end;
end;

class function TYamlDocument.ParseInternal(const AParser: TYamlParser;
  const ADocumentEvent: TDocumentStartEvent): IYamlDocument;
var
  root: TYamlNode;
  anchors: TYamlNode.TAnchors;
  flags: TYamlDocumentFlags;
  event: TYamlEvent;
  mark: TYamlMark;
begin
  mark.Initialize;
  flags := [];
  if ADocumentEvent.implicit then
    Include(flags, ydfImplicitStart);

  root := nil;
  anchors := TYamlNode.TAnchors.Create;
  try
    while True do begin
      event := AParser.Parse;
      try
        if (event is TDocumentEndEvent) then begin
          if TDocumentEndEvent(event).implicit then
            Include(flags, ydfImplicitEnd);
          Break;
        end;

        if Assigned(root) then
          raise EYamlParserError.Create('YAML Document contains multiple root nodes', mark);

        root := TYamlNode.ParseInternal(AParser, anchors, event);
      finally
        event.Free;
      end;
    end;
  finally
    anchors.Free;
  end;

  Result := TYamlDocument.Create(root, ADocumentEvent);
  Result.Flags := flags;
end;

procedure TYamlDocument.Save(const AFilename: String);
begin
  Save(AFilename, TYamlOutputSettings.Create);
end;

procedure TYamlDocument.Save(const AFilename: String;
  const ASettings: TYamlOutputSettings);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFilename, fmCreate);
  try
    Save(Stream, ASettings);
  finally
    Stream.Free;
  end;
end;

procedure TYamlDocument.Save(const AStream: TStream);
begin
  Save(AStream, TYamlOutputSettings.Create);
end;

procedure TYamlDocument.Save(const AStream: TStream;
  const ASettings: TYamlOutputSettings);
var
  Yaml: TBytes;
begin
  if (AStream = nil) then
    Exit;

  Yaml := ToYaml(ASettings);
  if (Length(Yaml) = 0) then
    Exit;

  AStream.WriteBuffer(Yaml[0], Length(Yaml));
end;

procedure TYamlDocument.SetFlags(const AValue: TYamlDocumentFlags);
begin
  FFlags := AValue;
end;

procedure TYamlDocument.SetTagDirectives(const AValue: TYamlTagDirectives);
begin
  FTagDirectives := AValue;
end;

procedure TYamlDocument.SetVersion(const AVersion: TYamlVersionDirective);
begin
  FVersion := AVersion;
end;

function TYamlDocument.ToYaml(const ASettings: TYamlOutputSettings): TBytes;
var
  emitter: TYamlEmitter;
  stream: TBytesStream;
begin
  stream := nil;
  emitter := TYamlEmitter.Create;
  try
    stream := TBytesStream.Create;
    emitter.SetOutput(Stream);
    emitter.StreamStartEvent;

    Emit(emitter);

    emitter.StreamEndEvent;

    Result := Copy(stream.Bytes, 0, stream.Position);
  finally
    emitter.Free;
    stream.Free;
  end;
end;

function TYamlDocument.ToYaml: TBytes;
begin
  Result := ToYaml(TYamlOutputSettings.Create);
end;

{ TYamlStream }

constructor TYamlStream.Create(const ADocuments: TArray<IYamlDocument>);
begin
  inherited Create;
  FDocuments := ADocuments;
end;

function TYamlStream.AddMapping: IYamlDocument;
begin
  Result := TYamlDocument.CreateMapping;
  FDocuments := FDocuments + [Result];
end;

function TYamlStream.AddScalar(const AValue: String): IYamlDocument;
begin
  Result := TYamlDocument.CreateScalar(AValue);
  FDocuments := FDocuments + [Result];
end;

function TYamlStream.AddSequence: IYamlDocument;
begin
  Result := TYamlDocument.CreateSequence;
  FDocuments := FDocuments + [Result];
end;

constructor TYamlStream.Create;
begin
  inherited;
end;

function TYamlStream.GetDocument(const AIndex: Integer): IYamlDocument;
begin
  if (AIndex < 0) or (AIndex >= Length(FDocuments)) then
    Result := nil
  else
    Result := FDocuments[AIndex];
end;

function TYamlStream.GetDocumentCount: Integer;
begin
  Result := Length(FDocuments);
end;

procedure TYamlStream.Save(const AFilename: String);
begin
  Save(AFilename, TYamlOutputSettings.Create);
end;

procedure TYamlStream.Save(const AFilename: String;
  const ASettings: TYamlOutputSettings);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFilename, fmCreate);
  try
    Save(Stream, ASettings);
  finally
    Stream.Free;
  end;
end;

procedure TYamlStream.Save(const AStream: TStream);
begin
  Save(AStream, TYamlOutputSettings.Create);
end;

procedure TYamlStream.Save(const AStream: TStream;
  const ASettings: TYamlOutputSettings);
var
  Yaml: TBytes;
begin
  if (AStream = nil) then
    Exit;

  Yaml := ToYaml(ASettings);
  if (Length(Yaml) = 0) then
    Exit;

  AStream.WriteBuffer(Yaml[0], Length(Yaml));
end;

class function TYamlStream.Load(const AStream: TStream): IYamlStream;
var
  Yaml: String;
  Size: Integer;
begin
  Size := AStream.Size - AStream.Position;
  if (Size = 0) then
    Exit(nil);

  SetLength(Yaml, Size);
  AStream.ReadBuffer(Yaml[Low(String)], Size);
  Result := Parse(Yaml);
end;

class function TYamlStream.Load(const AFilename: String): IYamlStream;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFilename, fmOpenRead or fmShareDenyWrite);
  try
    Result := Load(Stream);
  finally
    Stream.Free;
  end;
end;

class function TYamlStream.Parse(const AYaml: String): IYamlStream;
var
  parser: TYamlParser;
  stream: TStringStream;
begin
  if (AYaml = '') then
    Exit(nil);

  stream := nil;
  parser := TYamlParser.Create;
  try
    stream := TStringStream.Create(AYaml);
    parser.SetInput(stream);
    Result := ParseInternal(parser);
  finally
    parser.Free;
    stream.Free;
  end;
end;

class function TYamlStream.ParseInternal(
  const AParser: TYamlParser): IYamlStream;
var
  document: IYamlDocument;
  documents: TArray<IYamlDocument>;
  event: TYamlEvent;
  mark: TYamlMark;
begin
  mark.Initialize;
  event := AParser.parse;
  if not (event is TStreamStartEvent) then
    raise EYamlParserError.Create('Expected stream start event in YAML source', mark);

  SetLength(documents, 0);
  while (True) do begin
    event := AParser.parse;
    try
      if (event is TStreamEndEvent) then
        Break
      else
      if (event is TDocumentStartEvent) then begin
        document := TYamlDocument.ParseInternal(AParser, TDocumentStartEvent(event));
        SetLength(documents, Length(documents)+1);

        documents[High(documents)] := document;
      end
      else
        raise EYamlParserError.Create('Unexpected event in YAML source', mark);
    finally
      event.Free;
    end;
  end;

  if Length(documents) = 0 then
    Exit(nil);

  Result := TYamlStream.Create(documents);
end;

function TYamlStream.ToYaml(const ASettings: TYamlOutputSettings): TBytes;
var
  emitter: TYamlEmitter;
  stream: TBytesStream;
  i: Integer;
begin
  if (FDocuments = nil) then
    Exit(nil);

  stream := nil;
  emitter := TYamlEmitter.Create;
  try
    stream := TBytesStream.Create;
    emitter.SetOutput(stream);

    emitter.StreamStartEvent;

    for i := 0 to High(FDocuments) do
      FDocuments[I].Emit(emitter);

    emitter.StreamEndEvent;

    Result := Copy(stream.Bytes, 0, stream.Position);
  finally
    emitter.Free;
    stream.Free;
  end;
end;

function TYamlStream.ToYaml: TBytes;
begin
  Result := ToYaml(TYamlOutputSettings.Create);
end;

initialization
  USFormatSettings := DefaultFormatSettings;
  USFormatSettings.DecimalSeparator := '.';
  USFormatSettings.ThousandSeparator := ',';

end.

