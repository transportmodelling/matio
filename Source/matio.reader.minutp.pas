unit matio.reader.minutp;

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
  SysUtils, Classes, matio, matio.row, matio.reader;

Type
  TMinutpMatrixReader = Class(TMatrixReader)
  private
    Type
      TMatrixRecordHeader = record
        Row,LastColumn: UInt16;
        Matrix: Byte;
      end;

      TMatrixCell = record
      // The next cell of the matrix row a data record fills
        Rows: TCustomMatrixRows;
        Matrix,Column: Integer;
        Constructor Create(const Rows: TCustomMatrixRows; const Matrix: Integer);
        Procedure SetValue(const Value: Float64); inline;
        Procedure Fill(const Value: Float64; const Count: Integer = 1);
      end;
    Const
      Max13Bit = 8191;
    Var
      EOF: Boolean;
      Next: TMatrixRecordHeader;
      ScalingFactor: Real;
    Function ReadFileLabel(const Reader: TBinaryReader): String;
    Procedure ReadFileHeader;
    Procedure ReadBytes(var Buffer; const Count: Integer); inline;
    Procedure ZeroizeColumns(const Rows: TCustomMatrixRows; const Matrix,FirstColumn: Integer);
    Procedure ReadRecordHeader(const CurrentRow,LastMatrix: Integer);
    Procedure ReadValueSequence(var Cell: TMatrixCell; const ValueSize: Byte; const NValues: Integer);
    Procedure ReadReplicatedValue(var Cell: TMatrixCell; const NValues: Integer);
    Procedure ReadValueGroup(var Cell: TMatrixCell);
    Procedure ReadValues(const Rows: TCustomMatrixRows);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Constructor Create(Const FileName: TFileName; Const Precision: Byte = 0); overload;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMinutpMatrixReader.TMatrixCell.Create(const Rows: TCustomMatrixRows; const Matrix: Integer);
begin
  Self.Rows := Rows;
  Self.Matrix := Matrix;
  Column := 0;
end;

Procedure TMinutpMatrixReader.TMatrixCell.SetValue(const Value: Float64);
begin
  Rows[Matrix,Column] := Value;
  Inc(Column);
end;

Procedure TMinutpMatrixReader.TMatrixCell.Fill(const Value: Float64; const Count: Integer = 1);
begin
  for var Cnt := 1 to Count do SetValue(Value);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMinutpMatrixReader.Create(Const FileName: TFileName; Const Precision: Byte = 0);
begin
  inherited Create(FileName);
  // Set ScalingFactor
  ScalingFactor := 1;
  for var Cnt := 1 to Precision do ScalingFactor := ScalingFactor/10;
  ReadFileHeader;
  // Read first header record
  EOF := (FileStream.read(Next.Row,2) = 0);
  if not EOF then
  begin
    FileStream.read(Next.Matrix,1);
    FileStream.read(Next.LastColumn,2);
  end;
end;

Function TMinutpMatrixReader.ReadFileLabel(const Reader: TBinaryReader): String;
begin
  Result := '';
  for var Cnt := 1 to 60 do Result := Result + Reader.ReadChar;
  Result := TrimRight(Result);
end;

Procedure TMinutpMatrixReader.ReadFileHeader;
begin
  var Reader := TBinaryReader.Create(FileStream,TEncoding.ASCII);
  try
    SetSize(Reader.ReadUInt16);
    SetCount(Reader.ReadUInt16);
    if Reader.ReadUInt16 <> Size then raise Exception.Create('square matrices expected');
    SetFileLabel(ReadFileLabel(Reader));
    for var Cnt := 1 to 7 do Reader.ReadChar;
    Reader.ReadByte;
  finally
    Reader.Free;
  end;
end;

Procedure TMinutpMatrixReader.ReadBytes(var Buffer; const Count: Integer);
begin
  if FileStream.Read(Buffer,Count) <> Count then raise Exception.Create('Error reading Minutp-file');
end;

Procedure TMinutpMatrixReader.ZeroizeColumns(const Rows: TCustomMatrixRows;
                                             const Matrix,FirstColumn: Integer);
begin
  for var Column := FirstColumn to Size-1 do Rows[Matrix,Column] := 0.0;
end;

Procedure TMinutpMatrixReader.ReadRecordHeader(const CurrentRow,LastMatrix: Integer);
// Reads the header of the next data record and checks the row and matrix order
begin
  EOF := (FileStream.read(Next.Row,2) = 0);
  if not EOF then
  begin
    ReadBytes(Next.Matrix,1);
    ReadBytes(Next.LastColumn,2);
    if (Next.Row <= CurrentRow)
    or ((Next.Row = CurrentRow+1) and (Next.Matrix-1 <= LastMatrix)) then
      raise Exception.Create('Error while reading mtp-file!');
  end;
end;

Procedure TMinutpMatrixReader.ReadValueSequence(var Cell: TMatrixCell; const ValueSize: Byte; const NValues: Integer);
// Reads Nvalues vars with size 1..4
Var
  NextValue: LongInt;
begin
  for var Cnt := 1 to NValues do
  begin
    NextValue := 0;
    ReadBytes(NextValue,ValueSize);
    Cell.SetValue(ScalingFactor*NextValue);
  end;
end;

Procedure TMinutpMatrixReader.ReadReplicatedValue(var Cell: TMatrixCell; const NValues: Integer);
// Reads Next byte=size, reads a var with this Size and fills with Nvalues vars
Var
  ValueSize: Byte;
  RepliData: LongInt;
begin
  ReadBytes(ValueSize,1);
  RepliData := 0;
  ReadBytes(RepliData,ValueSize);
  Cell.Fill(ScalingFactor*RepliData,NValues);
end;

Procedure TMinutpMatrixReader.ReadValueGroup(var Cell: TMatrixCell);
// Reads a key and the values it announces
Var
  Key: Word;
begin
  ReadBytes(Key,2);
  var ValueSize: Byte := Key shr 13;  // bit 1-3
  var NValues: Integer := Key and Max13Bit;  // bit 4-16
  case ValueSize of
    0: Cell.Fill(0.0,NValues);
    1..4: ReadValueSequence(Cell,ValueSize,NValues);
    7: ReadReplicatedValue(Cell,NValues);
    else raise Exception.Create('Error reading Minutp-file!');
  end;
end;

Procedure TMinutpMatrixReader.ReadValues(const Rows: TCustomMatrixRows);
// Reads the compressed values of the current data record into its matrix row
begin
  var Cell := TMatrixCell.Create(Rows,Next.Matrix-1);
  while Cell.Column < Next.LastColumn do ReadValueGroup(Cell);
end;

Procedure TMinutpMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  var LastMatrix := -1;
  // Read the data records of the current row
  while (not EOF) and (Next.Row = CurrentRow+1) do
  begin
    for var Matrix := LastMatrix+1 to Next.Matrix-2 do ZeroizeColumns(Rows,Matrix,0);
    LastMatrix := Next.Matrix-1;
    ReadValues(Rows);
    ZeroizeColumns(Rows,Next.Matrix-1,Next.LastColumn);
    ReadRecordHeader(CurrentRow,LastMatrix);
  end;
  // Zeroize the matrices without data records
  for var Matrix := LastMatrix+1 to Count-1 do ZeroizeColumns(Rows,Matrix,0);
end;

end.
