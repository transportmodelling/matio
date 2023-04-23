unit matio.gen4;

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
  System.Classes,System.SysUtils,System.Types,System.ZLib,ArrayBld,PropSet,
  matio,matio.gen4.float16;

Type
  T4GCompression = (cpNone,cpGZip);

  T4GMatrixReader = Class(TMatrixReader)
  private
    FilePrecision: TFloatType;
    DecompressionStream: TStream;
    BinaryReader: TBinaryReader;
    Function ReadFloat16: Float32;
  strict protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Class Function Format: String; override;
    Class Function HasFormat(const Header: TBytes): Boolean; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet); overload; override;
    Constructor Create(const FileName: String); overload;
    Destructor Destroy; override;
  end;

  T4GMatrixWriter = Class(TMatrixWriter)
  private
    Const
      PrecisionProperty = 'prec';
      CompressionProperty = 'compress';
      CompressionOptions: array[T4GCompression] of String = ('none','gzip');
    Var
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
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; override;
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

Class Function T4GMatrixReader.Format: String;
begin
  Result := '4g';
end;

Class Function T4GMatrixReader.HasFormat(const Header: TBytes): Boolean;
begin
  if Length(Header) >= 4 then
    if TEncoding.ASCII.GetString(Copy(Header,0,2)) = '4G' then
      if (Header[2] = 20) and (Header[3] = 1) then
        Result := true
      else
        Result := false
    else
      Result := false
  else
    Result := false;
end;

Constructor T4GMatrixReader.Create(const [ref] Properties: TPropertySet);
begin
  if SameText(Properties[FormatProperty],Format) then
    Create(Properties.ToPath(FileProperty))
  else
    raise Exception.Create('Invalid format-property');
end;

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

////////////////////////////////////////////////////////////////////////////////

Class Function T4GMatrixWriter.Format: String;
begin
  Result := '4g';
end;

Class Procedure T4GMatrixWriter.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,PrecisionLabels[ftFloat32]);
  Properties.Append(CompressionProperty,CompressionOptions[cpGZip]);
end;

Class Function T4GMatrixWriter.PropertyPickList(const PropertyName: string;
                                                out PickList: TStringDynArray): Boolean;
begin
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,PrecisionProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(PrecisionLabels);
  end else
  if SameText(PropertyName,CompressionProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(CompressionOptions);
  end else
    Result := false;
end;

Constructor T4GMatrixWriter.Create(const [ref] Properties: TPropertySet;
                                   const FileLabel: string;
                                   const MatrixLabels: array of String;
                                   const Size: Integer);
Var
  Precision: TFloatType;
  Compression: T4GCompression;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    // Set precision
    var ValidPrecision := false;
    var PrecisionPropertyValue := ExtendedProperties[PrecisionProperty];
    for var Prec := low(PrecisionLabels) to high(PrecisionLabels) do
    if SameText(PrecisionLabels[Prec],PrecisionPropertyValue) then
    begin
      Precision := Prec;
      ValidPrecision := true;
      Break;
    end;
    if not ValidPrecision then raise Exception.Create('Invalid precision');
    // Set compression
    var ValidCompression := false;
    var CompressionProprtyValue := ExtendedProperties[CompressionProperty];
    for var Compress := low(CompressionOptions) to high(CompressionOptions) do
    if SameText(CompressionOptions[Compress],CompressionProprtyValue) then
    begin
      Compression := Compress;
      ValidCompression := true;
      Break;
    end;
    if not ValidCompression then raise Exception.Create('Invalid compression');
    // Create writer
    Create(ExtendedProperties.ToPath(FileProperty),FileLabel,MatrixLabels,Size,Precision,Compression);
  end else
    raise Exception.Create('Invalid format-property');
end;

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

Procedure T4GMatrixWriter.Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
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
