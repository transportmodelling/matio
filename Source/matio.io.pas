unit matio.io;

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
  SysUtils, KeyVal, matio, matio.row, matio.reader, matio.writer, matio.formats;

Type
  TCustomMatrixRowsReader = Class(TVirtualMatrixRows)
  // Combines row and reader functionality in a single class.
  // Each call to Read loads the next row into the object.
  strict protected
    Function GetFileLabel: String; virtual; abstract;
    Function GetMatrixLabels(Matrix: Integer): String; virtual; abstract;
  public
    Procedure Read; virtual; abstract;
  public
    Property FileLabel: String read GetFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels;
  end;

  TCustomFloat64MatrixRowsReader = Class(TCustomMatrixRowsReader)
  // Stores the current row of each matrix in a float64 array and reads the
  // file rows directly into those arrays. Reading past the last row zeroes
  // all values. The reader is not owned by this class.
  private
    FValues: array of TFloat64MatrixRow;
    CurrentRow: Integer;
    Reader: TMatrixReader;
  strict protected
    Procedure SetReader(const MatrixReader: TMatrixReader; const Count,Size: Integer);
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Function GetFileLabel: String; override;
    Function GetMatrixLabels(Matrix: Integer): String; override;
  public
    Procedure Read; override;
  end;

  TMatrixReaderRows = Class(TCustomFloat64MatrixRowsReader)
  // Obtains a reader reference in its constructor.
  // Suitable for multi threaded applications, where different instances
  // reference the same reader.
  // Count and Size default to the reader's Count and Size; pass them explicitly
  // for formats that discover their size while reading (e.g. text files).
  public
    Constructor Create(const MatrixReader: TMatrixReader); overload;
    Constructor Create(const MatrixReader: TMatrixReader; const Count,Size: Integer); overload;
  end;

  TMatrixRowsReader = Class(TCustomFloat64MatrixRowsReader)
  // Creates and owns its own reader.
  // Suitable for applications that process all rows on the same thread.
  public
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Count,Size: Integer); overload;
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Selection: array of Integer;
                       const Size: Integer); overload;
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Selection: array of String;
                       const Size: Integer); overload;
    Destructor Destroy; override;
  end;

  TMatrixRowsWriter = Class(TFloat64MatrixRows)
  private
    Writer: TMatrixWriter;
  public
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer);
    Procedure Write;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCustomFloat64MatrixRowsReader.SetReader(const MatrixReader: TMatrixReader; const Count,Size: Integer);
begin
  if MatrixReader <> nil then
  begin
    Reader := MatrixReader;
    Init(Count,Size);
    SetLength(FValues,Count,Size);
  end else
    raise Exception.Create('Reader unassigned');
end;

Function TCustomFloat64MatrixRowsReader.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues[Matrix,Column];
end;

Function TCustomFloat64MatrixRowsReader.GetFileLabel: String;
begin
  Result := Reader.FileLabel;
end;

Function TCustomFloat64MatrixRowsReader.GetMatrixLabels(Matrix: Integer): String;
begin
  Result := Reader.MatrixLabels[Matrix];
end;

Procedure TCustomFloat64MatrixRowsReader.Read;
begin
  if CurrentRow < Reader.Size then
    Reader.Read(FValues)
  else
    for var Matrix := 0 to Count-1 do
    for var Column := 0 to Size-1 do
    FValues[Matrix,Column] := 0.0;
  Inc(CurrentRow);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixReaderRows.Create(const MatrixReader: TMatrixReader);
begin
  inherited Create;
  if MatrixReader <> nil then
    SetReader(MatrixReader,MatrixReader.Count,MatrixReader.Size)
  else
    raise Exception.Create('Reader unassigned');
end;

Constructor TMatrixReaderRows.Create(const MatrixReader: TMatrixReader; const Count,Size: Integer);
begin
  inherited Create;
  SetReader(MatrixReader,Count,Size);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Count,Size: Integer);
begin
  inherited Create;
  var MatrixReader := MatrixFormats.CreateReader(Config);
  if MatrixReader <> nil then
    SetReader(MatrixReader,Count,Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of Integer;
                                     const Size: Integer);
begin
  inherited Create;
  var MatrixReader := MatrixFormats.CreateReader(Config,Selection);
  if MatrixReader <> nil then
    SetReader(MatrixReader,Length(Selection),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  var MatrixReader := MatrixFormats.CreateReader(Config,Selection);
  if MatrixReader <> nil then
    SetReader(MatrixReader,Length(Selection),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Destructor TMatrixRowsReader.Destroy;
begin
  Reader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRowsWriter.Create(const [ref] Config: TKeyValuePairs;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  Writer := MatrixFormats.CreateWriter(Config,FileLabel,MatrixLabels,Size);
  if Writer <> nil then
    Allocate(Length(MatrixLabels),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Procedure TMatrixRowsWriter.Write;
begin
  Writer.Write(Self);
end;

Destructor TMatrixRowsWriter.Destroy;
begin
  Writer.Free;
  inherited Destroy;
end;

end.
