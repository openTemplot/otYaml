unit otQueue;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections;

type
  TOTQueue<T: class> = class(TObjectQueue<T>)
  protected
    function GetTail: T;
    function GetItem(AIndex: SizeInt): T;
  public
    property Tail: T Read GetTail;

    procedure Insert(AIndex: SizeInt; AValue: T);

    property Items[AIndex: SizeInt]: T Read GetItem; default;
  end;


implementation

function TOTQueue<T>.GetTail: T;
begin
  if Count = 0 then
    Exit(nil);
  Result := FItems[FLength - 1];
end;

function TOTQueue<T>.GetItem(AIndex: SizeInt): T;
begin
  Result := FItems[FLow+AIndex];
end;

procedure TOTQueue<T>.Insert(AIndex: SizeInt; AValue: T);
var
  actualIndex: SizeInt;
  p1, p2: PByte;
begin
  actualIndex := FLow + AIndex;
  if actualIndex <> PrepareAddingItem then begin
    p1 := @FItems[actualIndex];
    p2 := @FItems[actualIndex+1];
    System.Move(p1^, p2^, ((FLength - actualIndex) - 1) * SizeOf(T));
    FillChar(FItems[actualIndex], SizeOf(T), 0);
  end;

  FItems[actualIndex] := AValue;
  Notify(AValue, cnAdded);

end;

end.
