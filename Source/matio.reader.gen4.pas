unit matio.reader.gen4;

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
  Classes, SysUtils, ZLib, FP16, matio, matio.row, matio.reader, matio.gen4;

Type
  T4GMatrixReader = Class(TMatrixReader)
  private
    FilePrecision: TFloatType;
    DecompressionStream: TStream;
    Float16Row: TArray<Float16>;
    Float32Row: TArray<Float32>;
    Float64Row: TArray<Float64>;
    Procedure AllocateRow;
    Procedure ReadFloat16Rows(const Rows: TCustomMatrixRows);
    Procedure ReadFloat32Rows(const Rows: TCustomMatrixRows);
    Procedure ReadFloat64Rows(const Rows: TCustomMatrixRows);
    Procedure VerifyEndOfData;
    Procedure ClearRows(const Rows: TCustomMatrixRows);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Constructor Create(const FileName: String); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor T4GMatrixReader.Create(const FileName: String);
Var
  FileCompression: T4GCompression;
begin
  inherited Create(FileName);
  // Read header
  var HeaderReader := TBinaryReader.Create(FileStream,TEncoding.UTF8);
  try
    if (HeaderReader.ReadChar = '4') and (HeaderReader.ReadChar = 'G')
    and (HeaderReader.ReadByte = 20) and (HeaderReader.ReadByte = 1) then
    begin
      // Read file header
      FilePrecision := TFloatType(HeaderReader.ReadByte);
      FileCompression := T4GCompression(HeaderReader.ReadByte);
      SetCount(HeaderReader.ReadByte);
      SetSize(HeaderReader.ReadUInt16);
      HeaderReader.ReadUInt32; // Skip user bytes
      var NChar := HeaderReader.ReadByte;
      var Lbl := '';
      for var Chr := 1 to NChar do Lbl := Lbl + HeaderReader.ReadChar;
      SetFileLabel(Lbl);
      // Read matrix headers
      for var Mtrx := 0 to Count-1 do
      begin
        HeaderReader.ReadUInt16; // Skip user bytes
        NChar := HeaderReader.ReadByte;
        Lbl := '';
        for var Chr := 1 to NChar do Lbl := Lbl + HeaderReader.ReadChar;
        SetMatrixLabels(Mtrx,Lbl);
      end;
    end else raise Exception.Create('Invalid 4G file header (' + FileName+ ')');
  finally
    HeaderReader.Free;
  end;
  // Set decompression stream
  case FileCompression of
    cpNone: DecompressionStream := FileStream; // No compression
    cpGZip: DecompressionStream := TZDecompressionStream.Create(FileStream,15+16); // GZip compression
  end;
  AllocateRow;
end;

Procedure T4GMatrixReader.AllocateRow;
// A matrix row is read from the decompression stream into the buffer of the file
// precision with a single call, as the decompressor inflates once per call.
begin
  case FilePrecision of
    ftFloat16: SetLength(Float16Row,Size);
    ftFloat32: SetLength(Float32Row,Size);
    ftFloat64: SetLength(Float64Row,Size);
  end;
end;

Procedure T4GMatrixReader.ReadFloat16Rows(const Rows: TCustomMatrixRows);
begin
  for var Mtrx := 0 to Count-1 do
  begin
    DecompressionStream.ReadBuffer(Float16Row[0],Size*SizeOf(Float16));
    for var Col := 0 to Size-1 do Rows[Mtrx,Col] := Float32(Float16Row[Col]);
  end;
end;

Procedure T4GMatrixReader.ReadFloat32Rows(const Rows: TCustomMatrixRows);
begin
  for var Mtrx := 0 to Count-1 do
  begin
    DecompressionStream.ReadBuffer(Float32Row[0],Size*SizeOf(Float32));
    for var Col := 0 to Size-1 do Rows[Mtrx,Col] := Float32Row[Col];
  end;
end;

Procedure T4GMatrixReader.ReadFloat64Rows(const Rows: TCustomMatrixRows);
begin
  for var Mtrx := 0 to Count-1 do
  begin
    DecompressionStream.ReadBuffer(Float64Row[0],Size*SizeOf(Float64));
    for var Col := 0 to Size-1 do Rows[Mtrx,Col] := Float64Row[Col];
  end;
end;

Procedure T4GMatrixReader.VerifyEndOfData;
// The rows are followed by a checksum over the uncompressed data. Reading past the
// last row hands that checksum to the decompressor, which raises when it disagrees
// with the data that was read, and yields a byte when the file holds more data than
// its header declares.
Var
  Trailing: Byte;
begin
  if DecompressionStream <> FileStream then
  if DecompressionStream.Read(Trailing,1) > 0 then
  raise Exception.Create('data beyond the last row');
end;

Procedure T4GMatrixReader.ClearRows(const Rows: TCustomMatrixRows);
begin
  for var Mtrx := 0 to Count-1 do
  for var Col := 0 to Rows.Size-1 do
  Rows[Mtrx,Col] := 0.0;
end;

Procedure T4GMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  if CurrentRow < Size then
  begin
    case FilePrecision of
      ftFloat16: ReadFloat16Rows(Rows);
      ftFloat32: ReadFloat32Rows(Rows);
      ftFloat64: ReadFloat64Rows(Rows);
    end;
    if CurrentRow = Size-1 then VerifyEndOfData;
  end else ClearRows(Rows);
end;

Destructor T4GMatrixReader.Destroy;
begin
  if DecompressionStream <> FileStream then DecompressionStream.Free;
  inherited Destroy;
end;

end.
