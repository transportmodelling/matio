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
    Const
      Max13Bit = 8191;
    Var
      EOF: Boolean;
      Next: TMatrixRecordHeader;
      ScalingFactor: Real;
    Procedure ZeroizeColumns(const Rows: TCustomMatrixRows; const Matrix,FirstColumn: Integer);
    Procedure ReadRecordHeader(const CurrentRow,LastMatrix: Integer);
    Procedure ReadValues(const Rows: TCustomMatrixRows);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Constructor Create(Const FileName: TFileName; Const Precision: Byte = 0); overload;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMinutpMatrixReader.Create(Const FileName: TFileName; Const Precision: Byte = 0);
begin
  inherited Create(FileName);
  // Set ScalingFactor
  ScalingFactor := 1;
  for var Cnt := 1 to Precision do ScalingFactor := ScalingFactor/10;
  // Read file header
  var Reader := TBinaryReader.Create(FileStream,TEncoding.ASCII);
  try
    SetSize(Reader.ReadUInt16);
    SetCount(Reader.ReadUInt16);
    if Reader.ReadUInt16 <> Size then raise Exception.Create('square matrices expected');
    var ID := '';
    for var Cnt := 1 to 60 do ID := ID + Reader.ReadChar;
    SetFileLabel(TrimRight(ID));
    for var Cnt := 1 to 7 do Reader.ReadChar;
    Reader.ReadByte;
  finally
    Reader.Free;
  end;
  // Read first header record
  EOF := (FileStream.read(Next.Row,2) = 0);
  if not EOF then
  begin
    FileStream.read(Next.Matrix,1);
    FileStream.read(Next.LastColumn,2);
  end;
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
    if (FileStream.read(Next.Matrix,1) <> 1)
    or  (FileStream.read(Next.LastColumn,2) <> 2) then
      raise Exception.Create('Error reading Minutp-file');
    if (Next.Row <= CurrentRow)
    or ((Next.Row = CurrentRow+1) and (Next.Matrix-1 <= LastMatrix)) then
      raise Exception.Create('Error while reading mtp-file!');
  end;
end;

Procedure TMinutpMatrixReader.ReadValues(const Rows: TCustomMatrixRows);
// Reads the compressed values of the current data record into its matrix row
Var
  ValueSize: Byte;
  Key,NValues: Word;
  NextValue,RepliData: LongInt;
begin
  var Column := 0;
  var Matrix := Next.Matrix-1;
  while Column < Next.LastColumn do
  begin
    if FileStream.Read(Key,2) <> 2 then
      raise Exception.Create('Error reading Minutp-file');
    ValueSize:= (Key shr 13);  // bit 1-3
    Nvalues:= (Key and Max13Bit);  // bit 4-16
    case ValueSize of
        0: // Fill with Nvalues zeros
           for var Cnt := 1 to Nvalues do
           begin
             Rows[Matrix,Column] := 0.0;
             Inc(Column);
           end;
     1..4: // Read Nvalues vars with size 1..4
           for var Cnt := 1 to Nvalues do
           begin
             NextValue := 0;
             if FileStream.Read(NextValue,ValueSize) <> ValueSize then
               raise Exception.Create('Error reading Minutp-file');
             Rows[Matrix,Column] := ScalingFactor*NextValue;
             Inc(Column);
           end;
        7: // Read Next byte=size; Read var with this Size; fill with Nvalues vars
           begin
             if FileStream.read(ValueSize,1) <> 1 then
               raise Exception.Create('Error reading Minutp-file');
             RepliData:=0;
             if FileStream.Read(RepliData,ValueSize) <> ValueSize then
               raise Exception.Create('Error reading Minutp-file');
             for var Cnt := 1 to Nvalues do
             begin
               Rows[Matrix,Column] := ScalingFactor*RepliData;
               Inc(Column);
             end;
           end;
      else raise exception.create('Error reading Minutp-file!');
    end;
  end;
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
