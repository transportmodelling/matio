unit matio.writer.minutp;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/matio
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, matio, matio.writer;

Type
  TMinutpMatrixWriter = Class(TMatrixWriter)
  private
    Type
      TCellRange = record
      // A range of cells that is written with one key
        First,Last: Integer;
        ValueSize: Byte;
        BeneficialRepliRange,RepliCount: Integer;
        Repli: Boolean;
        Function CellCount: Integer; inline;
      end;
    Const
      Max13Bit = 8191;
      RepliKey = 7 shl 13;
      RecordHeaderSize = 5;
      MaxCellSize = 6; // A range of one cell: a key of two bytes and a value of four
    Var
      ScalingFactor: Real;
      IntValues: array of Integer;
      RecordBuffer: TBytes;
      RecordSize: Integer;
    Procedure WriteFileLabel(const Writer: TBinaryWriter; const FileLabel: String);
    Procedure WriteFileHeader(const FileLabel: String);
    Function GetValueSize(Item: Int32): Byte;
    Procedure WriteToFile(Value,NBytes: Integer);
    Procedure AddToRecord(const Value,NBytes: Integer); inline;
    Function FitsRange(const Range: TCellRange): Boolean; inline;
    Function KeepsReplication(const Range: TCellRange): Boolean; inline;
    Procedure ExtendRange(var Range: TCellRange); inline;
    Function NextRange(const First: Integer): TCellRange;
    Procedure WriteReplicatedValue(const Range: TCellRange);
    Procedure WriteRange(const Range: TCellRange);
    Procedure WriteMatrixRecord(const CurrentMatrix,CurrentRow: Integer);
    Function ScaledIntValue(const Value: Float64): Int32; inline;
  strict protected
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); overload; override;
  public
    Constructor Create(Const FileName,FileLabel: String;
                       Const Count,Size: Integer;
                       Const Precision: Byte = 0); overload;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TMinutpMatrixWriter.TCellRange.CellCount: Integer;
begin
  Result := Last-First+1;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMinutpMatrixWriter.Create(Const FileName,FileLabel: String;
                                       Const Count,Size: Integer;
                                       const Precision: Byte = 0);
begin
  inherited Create(FileName,Count,Size);
  // Set ScalingFactor
  ScalingFactor := 1;
  for var Cnt := 1 to Precision do ScalingFactor := ScalingFactor*10;
  WriteFileHeader(FileLabel);
  // Allocate IntValues and the buffer of a record
  SetLength(IntValues,Size);
  SetLength(RecordBuffer,RecordHeaderSize+MaxCellSize*Size);
end;

Procedure TMinutpMatrixWriter.WriteFileLabel(const Writer: TBinaryWriter; const FileLabel: String);
begin
  if Length(FileLabel) < 60 then
  begin
    Writer.Write(FileLabel.ToCharArray);
    for var Space := Length(FileLabel)+1 to 60 do Writer.Write(' ');
  end else Writer.Write(Copy(FileLabel,1,60).ToCharArray);
end;

Procedure TMinutpMatrixWriter.WriteFileHeader(const FileLabel: String);
begin
  var Writer := TBinaryWriter.Create(FileStream,TEncoding.ASCII);
  try
    WriteToFile(Size,2);
    WriteToFile(Count,2);
    WriteToFile(Size,2);
    WriteFileLabel(Writer,FileLabel);
    Writer.Write(' MATRIX'.ToCharArray);
    WriteToFile(45,1); // Format indicator
  finally
    Writer.Free;
  end;
end;

Function TMinutpMatrixWriter.GetValueSize(Item: Int32): Byte;
Const
  MaxByte=256-1;
  MaxWord=256*256-1;
  Max3Byte=256*256*256-1;
begin
  if Item < 0 then Result := 4 else
  if Item<=MaxByte then Result:=1 else
  if Item<=MaxWord then Result:=2 else
  if Item<=Max3Byte then Result:=3 else
  Result:=4;
end;

Procedure TMinutpMatrixWriter.WriteToFile(Value,NBytes: Integer);
begin
  FileStream.Write(Value,NBytes)
end;

Procedure TMinutpMatrixWriter.AddToRecord(const Value,NBytes: Integer);
// Adds a little endian value. A sparse matrix holds many short ranges, so the
// bytes are split here instead of copied with a call per value.
begin
  for var Index := 0 to NBytes-1 do RecordBuffer[RecordSize+Index] := Byte(Value shr (8*Index));
  Inc(RecordSize,NBytes);
end;

Function TMinutpMatrixWriter.FitsRange(const Range: TCellRange): Boolean;
// The next cell has the same value size and the range stays a valid range
begin
  Result := (Range.Last < Size-1) and (Range.CellCount < Max13Bit) and
            (GetValueSize(IntValues[Range.Last+1]) = Range.ValueSize);
end;

Function TMinutpMatrixWriter.KeepsReplication(const Range: TCellRange): Boolean;
// The next cell neither breaks a long repli sequence nor prevents one
begin
  Result := ((not Range.Repli) or (IntValues[Range.First] = IntValues[Range.Last+1])
             or ((Range.Last-Range.First) < Range.BeneficialRepliRange)) and
            (Range.Repli or (Range.RepliCount < Range.BeneficialRepliRange));
end;

Procedure TMinutpMatrixWriter.ExtendRange(var Range: TCellRange);
begin
  Inc(Range.Last);
  if IntValues[Range.Last] = IntValues[Range.Last-1] then Inc(Range.RepliCount) else Range.RepliCount := 0;
  Range.Repli := Range.Repli and (IntValues[Range.First] = IntValues[Range.Last]);
end;

Function TMinutpMatrixWriter.NextRange(const First: Integer): TCellRange;
// Determines the range with the same value size that starts at the first cell
begin
  Result.First := First;
  Result.Last := First;
  Result.ValueSize := GetValueSize(IntValues[First]);
  Result.BeneficialRepliRange := 5 div Result.ValueSize; // Beneficial if 5+ValueSize < (Last-First+1)*ValueSize
  Result.Repli := true;
  Result.RepliCount := 0;
  while FitsRange(Result) and KeepsReplication(Result) do ExtendRange(Result);
  if (not Result.Repli) and (Result.RepliCount >= Result.BeneficialRepliRange) then
  Result.Last := Result.Last-Result.RepliCount-1;
end;

Procedure TMinutpMatrixWriter.WriteReplicatedValue(const Range: TCellRange);
begin
  if IntValues[Range.First] = 0 then
    AddToRecord(Range.CellCount,2)
  else
  begin
    AddToRecord(RepliKey+Range.CellCount,2);
    AddToRecord(Range.ValueSize,1);
    AddToRecord(IntValues[Range.First],Range.ValueSize);
  end;
end;

Procedure TMinutpMatrixWriter.WriteRange(const Range: TCellRange);
begin
  if Range.Repli and (Range.Last > Range.First) then
    WriteReplicatedValue(Range)
  else
  begin
    AddToRecord((Range.ValueSize shl 13)+Range.CellCount,2);
    for var Column := Range.First to Range.Last do AddToRecord(IntValues[Column],Range.ValueSize);
  end;
end;

Procedure TMinutpMatrixWriter.WriteMatrixRecord(const CurrentMatrix,CurrentRow: Integer);
begin
  // Add matrix record header
  RecordSize := 0;
  AddToRecord(CurrentRow+1,2);
  AddToRecord(CurrentMatrix+1,1);
  AddToRecord(Size,2);
  // Add cells
  var Last := -1;
  while Last < Size-1 do
  begin
    var Range := NextRange(Last+1);
    WriteRange(Range);
    Last := Range.Last;
  end;
  FileStream.Write(RecordBuffer[0],RecordSize);
end;

Function TMinutpMatrixWriter.ScaledIntValue(const Value: Float64): Int32;
begin
  var ScaledValue := ScalingFactor*Value;
  if ScaledValue < 0 then
    if ScaledValue >= -MaxInt-1 then Result := Round(ScaledValue) else Result := -MaxInt-1
  else
    if ScaledValue <= MaxInt then Result := Round(ScaledValue) else Result := MaxInt;
end;

Procedure TMinutpMatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
begin
  for var Matrix := 0 to Count-1 do
  begin
    for var Column := 0 to Size-1 do IntValues[Column] := ScaledIntValue(Rows[Matrix,Column]);
    WriteMatrixRecord(Matrix,CurrentRow);
  end;
end;

end.
