unit matio.reader.visum;

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
  SysUtils, Classes, ZLib, matio, matio.row, matio.reader;

Type
  TVisumMatrixReader = Class(TMatrixReader)
  // Source code based on: https://github.com/MaxBo/matrixconverters/
  private
    AllNull: Boolean;
    NColumns: Integer;
    DataType: Int16;
    Factor: Float32;
    Compression: ANSIChar;
    Reader: TBinaryReader;
    Procedure ReadIdentification;
    Procedure ReadParameters;
    Procedure SkipIntegers(const NIntegers: Integer);
    Procedure SkipLabels(const NLabels: Integer);
    Procedure SkipCompressedLabels;
    Procedure SkipRowAndColumnLabels;
    Function ReadCompressedData: TBytesStream;
    Function ReadValue(const ValueReader: TBinaryReader): Float64;
    Procedure ReadColumns(const Stream: TStream; const Rows: TCustomMatrixRows);
    Procedure ReadRow(const Rows: TCustomMatrixRows);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Constructor Create(const FileName: String);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TVisumMatrixReader.Create(const FileName: String);
begin
  inherited Create(FileName);
  SetCount(1); // Visum binary matrix file only contains a single matrix
  // Read header
  Reader := TBinaryReader.Create(FileStream);
  if Reader.ReadInt16 = 3 then // Id-length
  begin
    ReadIdentification;
    ReadParameters;
    SkipRowAndColumnLabels;
    // Read allnull-flag
    AllNull := Reader.ReadBoolean;
    Reader.ReadDouble; // Diagonal sum
  end else
    raise Exception.Create('Invalid header');
end;

Procedure TVisumMatrixReader.ReadIdentification;
begin
  // Read Id, of which the last character is the compression method
  Reader.ReadByte;
  Reader.ReadByte;
  Compression := ANSIChar(Reader.ReadByte);
  // Skip header
  var HeaderLength := Reader.ReadInt16;
  for var Chr := 1 to HeaderLength do Reader.ReadByte;
end;

Procedure TVisumMatrixReader.ReadParameters;
begin
  SkipIntegers(3);
  Factor := Reader.ReadSingle;
  SetSize(Reader.ReadInt32);
  DataType := Reader.ReadInt16;
  Reader.ReadBoolean;
end;

Procedure TVisumMatrixReader.SkipIntegers(const NIntegers: Integer);
begin
  for var Int := 1 to NIntegers do Reader.ReadInt32;
end;

Procedure TVisumMatrixReader.SkipLabels(const NLabels: Integer);
begin
  for var Lbl := 1 to NLabels do
  begin
    var n_chars := Reader.ReadInt32;
    for var Ch := 1 to n_chars do Reader.ReadInt16; // utf16 characters
  end;
end;

Procedure TVisumMatrixReader.SkipCompressedLabels;
begin
  NColumns := Reader.ReadInt32;
  if NColumns <= Size then
  begin
    SkipIntegers(Size); // Row numbers
    SkipIntegers(NColumns); // Column numbers
    SkipLabels(Size); // Row labels
    SkipLabels(NColumns); // Column labels
  end else
    raise Exception.Create('Too many columns in matrix')
end;

Procedure TVisumMatrixReader.SkipRowAndColumnLabels;
begin
  if Compression = 'I' then
  begin
    NColumns := Size;
    SkipIntegers(Size); // Zone numbers
  end else
  if Compression in ['K','L'] then
    SkipCompressedLabels
  else
    raise Exception.Create('Unknown compression method');
end;

Function TVisumMatrixReader.ReadCompressedData: TBytesStream;
begin
  var len_chun := Reader.ReadInt32;
  Result := TBytesStream.Create;
  try
    Result.Size := len_chun;
    Reader.Read(Result.Bytes,0,len_chun);
    Result.Position := 0;
  except
    Result.Free;
    raise;
  end;
end;

Function TVisumMatrixReader.ReadValue(const ValueReader: TBinaryReader): Float64;
begin
  Result := 0.0;
  case DataType of
    2: Result := Factor*ValueReader.ReadInt16;
    3: Result := Factor*ValueReader.ReadInt32;
    4: Result := Factor*ValueReader.ReadSingle;
    5: Result := Factor*ValueReader.ReadDouble;
  end;
end;

Procedure TVisumMatrixReader.ReadColumns(const Stream: TStream; const Rows: TCustomMatrixRows);
begin
  var ValueReader := TBinaryReader.Create(Stream);
  try
    for var Column := 0 to Size-1 do
    if Column < NColumns then
      Rows[0,Column] := ReadValue(ValueReader)
    else
      Rows[0,Column] := 0.0;
  finally
    ValueReader.Free;
  end;
end;

Procedure TVisumMatrixReader.ReadRow(const Rows: TCustomMatrixRows);
begin
  var BytesStream := ReadCompressedData;
  try
    var DecompressionStream := TZDecompressionStream.Create(BytesStream);
    try
      ReadColumns(DecompressionStream,Rows);
    finally
      DecompressionStream.Free;
    end;
  finally
    BytesStream.Free;
  end;
end;

Procedure TVisumMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  if not AllNull then
  begin
    ReadRow(Rows);
    // Read row & column sums
    if Compression in ['I','K'] then
    begin
      Reader.ReadDouble; // Row sums
      Reader.ReadDouble;  // column sums
    end;
  end else
    for var Column := 0 to Size-1 do Rows[0,Column] := 0.0;
end;

Destructor TVisumMatrixReader.Destroy;
begin
  Reader.Free;
  inherited Destroy;
end;

end.
