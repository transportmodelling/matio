unit matio.writer.gen4;

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
  SysUtils, Classes, ZLib, FP16, matio, matio.writer, matio.gen4;

Type
  T4GMatrixWriter = Class(TMatrixWriter)
  private
    FilePrecision: TFloatType;
    CompressionStream: TStream;
    BinaryWriter: TBinaryWriter;
    Procedure WriteChar(Value: Char);
    Procedure WriteByte(Value: Byte);
    Procedure WriteUInt16(Value: UInt16);
    Procedure WriteUInt32(Value: UInt32);
    Procedure WriteFloat16(Value: Float32);
    Procedure WriteFloat32(Value: Float32);
    Procedure WriteFloat64(Value: Float64);
  strict protected
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); override;
  public
    Constructor Create(const FileName,FileLabel: String;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const Precision: TFloatType = ftFloat32;
                       const Compression: T4GCompression = cpGzip); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor T4GMatrixWriter.Create(const FileName,FileLabel: String;
                                   const MatrixLabels: array of String;
                                   const Size: Integer;
                                   const Precision: TFloatType = ftFloat32;
                                   const Compression: T4GCompression = cpGzip);
begin
  inherited Create(FileName,Length(MatrixLabels),Size);
  FilePrecision := Precision;
  // Write file header
  BinaryWriter := TBinaryWriter.Create(FileStream,TEncoding.UTF8);
  try
    WriteChar('4');
    WriteChar('G');
    WriteByte(20);
    WriteByte(1);
    WriteByte(Ord(Precision));
    WriteByte(ord(Compression));
    WriteByte(Count);
    WriteUInt16(Size);
    WriteUInt32(0); // User bytes
    var Lbl := FileLabel;
    if Length(Lbl) > 255 then Lbl := Copy(Lbl,1,255);
    WriteByte(Length(Lbl));
    for var Chr := 1 to Length(Lbl) do WriteChar(Lbl[Chr]);
    // Write matrix headers
    for var Mtrx := 0 to Count-1 do
    begin
      WriteUInt16(0); // User bytes
      Lbl := MatrixLabels[Mtrx];
      if Length(Lbl) > 255 then Lbl := Copy(Lbl,1,255);
      WriteByte(Length(Lbl));
      for var Chr := 1 to Length(Lbl) do WriteChar(Lbl[Chr]);
    end;
  finally
    BinaryWriter.Free;
  end;
  // Set compression stream
  case Compression of
    cpNone: CompressionStream := FileStream; // No compression
    cpGZip: CompressionStream := TZCompressionStream.Create(FileStream,zcDefault,15+16);
  end;
  BinaryWriter := TBinaryWriter.Create(CompressionStream);
end;

Procedure T4GMatrixWriter.WriteChar(Value: Char);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.WriteByte(Value: Byte);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.WriteUInt16(Value: UInt16);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.WriteUInt32(Value: UInt32);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.WriteFloat16(Value: Float32);
Var
  FloatValue: Float16;
begin
  FloatValue := Value;
  BinaryWriter.Write(FloatValue.Bytes);
end;

Procedure T4GMatrixWriter.WriteFloat32(Value: Float32);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.WriteFloat64(Value: Float64);
begin
  BinaryWriter.Write(Value);
end;

Procedure T4GMatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
begin
  case FilePrecision of
    ftFloat16: for var Mtrx := 0 to Count-1 do
               for var Col := 0 to Rows.Size-1 do
               WriteFloat16(Rows[Mtrx,Col]);
    ftFloat32: for var Mtrx := 0 to Count-1 do
               for var Col := 0 to Rows.Size-1 do
               WriteFloat32(Rows[Mtrx,Col]);
    ftFloat64: for var Mtrx := 0 to Count-1 do
               for var Col := 0 to Rows.Size-1 do
               WriteFloat64(Rows[Mtrx,Col]);
  end;
end;

Destructor T4GMatrixWriter.Destroy;
begin
  BinaryWriter.Free;
  if CompressionStream <> FileStream then CompressionStream.Free;
  inherited Destroy;
end;

end.
