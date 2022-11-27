unit Murmur3;

{$mode delphi}

interface

uses
  Classes,
  SysUtils;

function murmur3_32(const key: PByte; len: UInt32; seed: UInt32): UInt32;

implementation

function murmur_32_scramble(k: UInt32): UInt32;
begin
  k := k * $cc9e2d51;
  k := (k shl 15) or (k shr 17);
  Result := k * $1b873593;
end;

function murmur3_32(const key: PByte; len: UInt32; seed: UInt32): UInt32;
var
  h: UInt32;
  k: UInt32;
  i: UInt32;
  p: PByte;
begin
  h := seed;
  p := key;

  // Read in groups of 4.
  for i := 1 to len shr 2 do begin
    // Here is a source of differing results across endiannesses.
    // A swap here has no effects on hash properties though.
    k := PUInt32(p)^;
    p := p + sizeof(UInt32);
    h := h xor murmur_32_scramble(k);
    h := (h shl 13) or (h shr 19);
    h := h * 5 + $e6546b64;
  end;

  // Read the rest.
  k := 0;
  for i := (len and 3) downto 1 do begin
    k := k shl 8;
    k := k or p[i - 1];
  end;

  // A swap is *not* necessary here because the preceding loop already
  // places the low bytes in the low places according to whatever endianness
  // we use. Swaps only apply when the memory is copied in a chunk.
  h := h xor murmur_32_scramble(k);

  // Finalize.
  h := h xor len;
  h := h xor (h >> 16);
  h := h * $85ebca6b;
  h := h xor (h >> 13);
  h := h * $c2b2ae35;
  Result := h xor (h >> 16);
end;

end.

