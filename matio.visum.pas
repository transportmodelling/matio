unit matio.visum;

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
  SysUtils, Classes, zlib, matio;

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
Var
  Id: ANSIString;
begin
  inherited Create(FileName);
  SetCount(1); // Visum binary matrix file only contains a single matrix
  // Read header
  Reader := TBinaryReader.Create(FileStream);
  // Read Id-length
  var IdLength := Reader.ReadInt16;
  if IdLength = 3 then
  begin
    // Read Id
    Id := '';
    for var Chr := 1 to IdLength do Id := Id + ANSIChar(Reader.ReadByte);
    Compression := Id[3];
    // Skip header
    var HeaderLength := Reader.ReadInt16;
    for var Chr := 1 to HeaderLength do Reader.ReadByte;
    // Read parameters
    Reader.ReadInt32;
    Reader.ReadInt32;
    Reader.ReadInt32;
    Factor := Reader.ReadSingle;
    SetSize(Reader.ReadInt32);
    DataType := Reader.ReadInt16;
    Reader.ReadBoolean;
    // Skip row & column labels
    if Compression = 'I' then
    begin
      NColumns := Size;
      // Skip zone numbers
      for var Zone := 1 to Size do Reader.ReadInt32;
    end else
    if Compression in ['K','L'] then
    begin
      NColumns := Reader.ReadInt32;
      if NColumns <= Size then
      begin
        // Skip row numbers
        for var Row := 1 to Size do Reader.ReadInt32;
        // Skip column numbers
        for var Column := 1 to NColumns do Reader.ReadInt32;
        // Skip row labels
        for var Row := 1 to Size do
        begin
          var n_chars := Reader.ReadInt32;
          for var Ch := 1 to n_chars do Reader.ReadInt16; // utf16 characters
        end;
        // Skip column labels
        for var Column := 1 to NColumns do
        begin
          var n_chars := Reader.ReadInt32;
          for var Ch := 1 to n_chars do Reader.ReadInt16; // utf16 characters
        end;
      end else
        raise Exception.Create('Too many columns in matrix')
    end else
      raise Exception.Create('Unknown compression method');
    // Read allnull-flag
    AllNull := Reader.ReadBoolean;
    Reader.ReadDouble; // Diagonal sum
  end else
    raise Exception.Create('Invalid header');
end;

Procedure TVisumMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  BytesStream: TBytesStream;
  DecompressionStream: TZDecompressionStream;
  DecompressionReader: TBinaryReader;
begin
  if not AllNull then
  begin
    BytesStream := nil;
    DecompressionStream := nil;
    DecompressionReader := nil;
    try
      // Read compressed data
      var len_chun := Reader.ReadInt32;
      BytesStream := TBytesStream.Create;
      BytesStream.Size := len_chun;
      Reader.Read(BytesStream.Bytes,0,len_chun);
      // Decompress data
      BytesStream.Position := 0;
      DecompressionStream := TZDecompressionStream.Create(BytesStream);
      DecompressionReader := TBinaryReader.Create(DecompressionStream);
      for var Column := 0 to Size-1 do
      if Column < NColumns then
        case DataType of
          2: Rows[0,Column] := Factor*DecompressionReader.ReadInt16;
          3: Rows[0,Column] := Factor*DecompressionReader.ReadInt32;
          4: Rows[0,Column] := Factor*DecompressionReader.ReadSingle;
          5: Rows[0,Column] := Factor*DecompressionReader.ReadDouble;
        end
      else
        Rows[0,Column] := 0.0;
      // Read row & column sums
      if Compression in ['I','K'] then
      begin
        Reader.ReadDouble; // Row sums
        Reader.ReadDouble;  // column sums
      end;
    finally
      DecompressionStream.Free;
      DecompressionReader.Free;
      BytesStream.Free;
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
