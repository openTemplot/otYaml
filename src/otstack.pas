unit otStack;

{$mode Delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Generics.Collections;

type
  TOTStack<T> = class(TStack<T>)
  protected
    function GetItem(Index: SizeInt): T;
  public
    property Items[Index: SizeInt]: T Read GetItem; default;
  end;

  TOTObjectStack<T: class> = class(TObjectStack<T>)
  protected
    function GetItem(Index: SizeInt): T;
  public
    property Items[Index: SizeInt]: T Read GetItem; default;
  end;

implementation

function TOTStack<T>.GetItem(Index: SizeInt): T;
begin
  Result := FItems[Index];
end;

function TOTObjectStack<T>.GetItem(Index: SizeInt): T;
begin
  Result := FItems[Index];
end;

end.
