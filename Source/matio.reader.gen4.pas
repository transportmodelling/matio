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
    BinaryReader: TBinaryReader;
    Function ReadFloat16: Float32;
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
  BinaryReader := TBinaryReader.Create(DecompressionStream);
end;

Function T4GMatrixReader.ReadFloat16: Float32;
Var
  FloatValue: Float16;
begin
  FloatValue.Bytes := BinaryReader.ReadUInt16;
  Result := FloatValue;
end;

Procedure T4GMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  if CurrentRow < Size then
    case FilePrecision of
      ftFloat16: for var Mtrx := 0 to Count-1 do
                 for var Col := 0 to Size-1 do
                 Rows[Mtrx,Col] := ReadFloat16;
      ftFloat32: for var Mtrx := 0 to Count-1 do
                 for var Col := 0 to Size-1 do
                 Rows[Mtrx,Col] := BinaryReader.ReadSingle;
      ftFloat64: for var Mtrx := 0 to Count-1 do
                 for var Col := 0 to Size-1 do
                 Rows[Mtrx,Col] := BinaryReader.ReadDouble;
    end
  else
    for var Mtrx := 0 to Count-1 do
    for var Col := 0 to Rows.Size-1 do
    Rows[Mtrx,Col] := 0.0;
end;

Destructor T4GMatrixReader.Destroy;
begin
  BinaryReader.Free;
  if DecompressionStream <> FileStream then DecompressionStream.Free;
  inherited Destroy;
end;

end.
