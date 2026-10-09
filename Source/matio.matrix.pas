unit matio.matrix;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/matio
//
// Provides classes for memory stored matrices
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, matio, matio.row, matio.reader, matio.formats, matio.io, ArrVal, KeyVal;

Type
  TCustomMatrices = Class
  private
    FCount,FSize: Integer;
    FFileName,FFileLabel: String;
    FMatrixLabels: TArray<String>;
    Procedure ResetLabels;
    Function GetMatrixLabels(Matrix: Integer): String;
    Procedure SetMatrixLabels(Matrix: Integer; MatrixLabel: String);
    Function GetValues(Matrix,Row,Column: Integer): Float64; virtual; abstract;
    Procedure SetValues(Matrix,Row,Column: Integer; Value: Float64); virtual; abstract;
    Function GetRows(Row: Integer): TCustomMatrixRows; virtual; abstract;
    Procedure ReadRows(const Reader: TMatrixReader);
  public
    Function MatrixLabelValues: TStringArrayValues;
    // Pass Ordered=false to read all matrices of a format that does not define
    // a matrix order (e.g. OMX); the matrices are then stored in the order the
    // reader enumerates them
    Procedure Read(const [ref] Config: TKeyValuePairs; Ordered: Boolean = true); overload;
    Procedure Read(const [ref] Config: TKeyValuePairs;
                   const Selection: array of Integer); overload;
    Procedure Read(const [ref] Config: TKeyValuePairs;
                   const Selection: array of String); overload;
    Procedure Transpose(Matrix: Integer); overload;
    Procedure Transpose; overload;
    Procedure Save(const [ref] Config: TKeyValuePairs);
  public
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
    Property FileName: String read FFileName;
    Property FileLabel: String read FFileLabel write FFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels write SetMatrixLabels;
    Property Values[Matrix,Row,Column: Integer]: Float64 read GetValues write SetValues; default;
  end;

  TFloat32Matrices = Class(TCustomMatrices)
  // In memory float32 matrices
  private
    FRows: array of TFloat32MatrixRows;
    Function GetValues(Matrix,Row,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Row,Column: Integer; Value: Float64); override;
    Function GetRows(Row: Integer): TCustomMatrixRows; override;
  public
    Constructor Create(Count,Size: Integer);
    Function RowValues(Matrix,Row: Integer): TFloat32ArrayValues;
    Destructor Destroy; override;
  end;

  TFloat64Matrices = Class(TCustomMatrices)
  // In memory float64 matrices
  private
    FRows: array of TFloat64MatrixRows;
    Function GetValues(Matrix,Row,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Row,Column: Integer; Value: Float64); override;
    Function GetRows(Row: Integer): TCustomMatrixRows; override;
  public
    Constructor Create(Count,Size: Integer);
    Function RowValues(Matrix,Row: Integer): TFloat64ArrayValues;
    Destructor Destroy; override;
  end;

  TMemoryMatrixReader = Class
  // Keeps a reference to in-memory matrices and the index of the current row.
  // Each call to Read returns the index of the next row to process. Like the
  // file readers, the reader is not thread safe: when it is shared between
  // threads, the caller must synchronize the calls to Read.
  // The matrices are not owned by the reader.
  private
    FMatrices: TCustomMatrices;
    FCurrentRow: Integer;
  public
    Constructor Create(const Matrices: TCustomMatrices);
    // Returns the index of the next row and advances; the result is equal to
    // or greater than the size of the matrices past the last row
    Function Read: Integer;
  public
    Property Matrices: TCustomMatrices read FMatrices;
    Property CurrentRow: Integer read FCurrentRow;
  end;

  TCustomMemoryMatrixRowsReader = Class(TCustomMatrixRowsReader)
  // Rows object over a TMemoryMatrixReader: each call to Read obtains the next
  // row index from the reader and points the object at that row of the
  // matrices, so no values are copied and later changes to the matrices remain
  // visible. Reading past the last row yields zeroes; Row is then equal to or
  // greater than Size.
  private
    Reader: TMemoryMatrixReader;
    FRow: Integer;
    Rows: TCustomMatrixRows; // Current row of the matrices; nil past the last row
  strict protected
    Procedure SetReader(const MemoryReader: TMemoryMatrixReader);
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Function GetFileLabel: String; override;
    Function GetMatrixLabels(Matrix: Integer): String; override;
  public
    Procedure Read; override;
  public
    Property Row: Integer read FRow; // Index of the row obtained by the last Read
  end;

  TMemoryMatrixReaderRows = Class(TCustomMemoryMatrixRowsReader)
  // Obtains a reader reference in its constructor.
  // Suitable for multi threaded applications, where different instances
  // reference the same reader and each thread handles the rows it obtains.
  public
    Constructor Create(const MemoryReader: TMemoryMatrixReader);
  end;

  TMemoryMatrixRowsReader = Class(TCustomMemoryMatrixRowsReader)
  // Creates and owns its own reader over the given matrices.
  // Suitable for applications that process all rows on the same thread.
  public
    Constructor Create(const Matrices: TCustomMatrices);
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TCustomMatrices.ResetLabels;
begin
  FFileName := '';
  FFileLabel := '';
  for var Matrix := 0 to FCount-1 do FMatrixLabels[Matrix] := '';
end;

Function TCustomMatrices.GetMatrixLabels(Matrix: Integer): String;
begin
  Result := FMatrixLabels[Matrix];
end;

Procedure TCustomMatrices.SetMatrixLabels(Matrix: Integer; MatrixLabel: String);
begin
  FMatrixLabels[Matrix] := MatrixLabel;
end;

Procedure TCustomMatrices.ReadRows(const Reader: TMatrixReader);
begin
  ResetLabels;
  FFileName := Reader.FileName;
  FFileLabel := Reader.FileLabel;
  var NLabels := FCount;
  if Reader.Count < NLabels then NLabels := Reader.Count;
  for var Matrix := 0 to NLabels-1 do FMatrixLabels[Matrix] := Reader.MatrixLabels[Matrix];
  for var Row := 0 to FSize-1 do Reader.Read(GetRows(Row));
end;

Function TCustomMatrices.MatrixLabelValues: TStringArrayValues;
begin
  Result := TStringArrayValues.Create(FMatrixLabels);
end;

Procedure TCustomMatrices.Read(const [ref] Config: TKeyValuePairs; Ordered: Boolean = true);
begin
  var Reader := MatrixFormats.CreateReader(Config,Ordered);
  try
    ReadRows(Reader);
  finally
    Reader.Free;
  end;
end;

Procedure TCustomMatrices.Read(const [ref] Config: TKeyValuePairs;
                               const Selection: array of Integer);
begin
  var Reader := MatrixFormats.CreateReader(Config,Selection);
  try
    ReadRows(Reader);
  finally
    Reader.Free;
  end;
end;

Procedure TCustomMatrices.Read(const [ref] Config: TKeyValuePairs;
                               const Selection: array of String);
begin
  var Reader := MatrixFormats.CreateReader(Config,Selection);
  try
    ReadRows(Reader);
  finally
    Reader.Free;
  end;
end;

Procedure TCustomMatrices.Transpose(Matrix: Integer);
begin
  for var Row := 0 to FSize-1 do
  for var Column := Row+1 to FSize-1 do
  begin
    var UpperValue := GetValues(Matrix,Row,Column);
    var LowerValue := GetValues(Matrix,Column,Row);
    SetValues(Matrix,Row,Column,LowerValue);
    SetValues(Matrix,Column,Row,UpperValue);
  end;
end;

Procedure TCustomMatrices.Transpose;
begin
  for var Matrix := 0 to FCount-1 do Transpose(Matrix);
end;

Procedure TCustomMatrices.Save(const [ref] Config: TKeyValuePairs);
begin
  var Writer := MatrixFormats.CreateWriter(Config,FFileLabel,FMatrixLabels,FSize);
  try
    FFileName := Writer.FileName;
    for var Row := 0 to FSize-1 do Writer.Write(GetRows(Row))
  finally
    Writer.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TFloat32Matrices.Create(Count,Size: Integer);
begin
  inherited Create;
  FCount := Count;
  FSize := Size;
  SetLength(FMatrixLabels,Count);
  SetLength(FRows,FSize);
  for var Row := 0 to FSize-1 do FRows[Row] := TFloat32MatrixRows.Create(Count,Size);
end;

Function TFloat32Matrices.GetValues(Matrix,Row,Column: Integer): Float64;
begin
  Result := FRows[Row][Matrix,Column];
end;

Procedure TFloat32Matrices.SetValues(Matrix,Row,Column: Integer; Value: Float64);
begin
  FRows[Row][Matrix,Column] := Value;
end;

Function TFloat32Matrices.GetRows(Row: Integer): TCustomMatrixRows;
begin
  Result := FRows[Row];
end;

Function TFloat32Matrices.RowValues(Matrix,Row: Integer): TFloat32ArrayValues;
begin
  Result := FRows[Row].RowValues(Matrix);
end;

Destructor TFloat32Matrices.Destroy;
begin
  for var Row := low(FRows) to high(FRows) do FRows[Row].Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TFloat64Matrices.Create(Count,Size: Integer);
begin
  inherited Create;
  FCount := Count;
  FSize := Size;
  SetLength(FMatrixLabels,Count);
  SetLength(FRows,FSize);
  for var Row := 0 to FSize-1 do FRows[Row] := TFloat64MatrixRows.Create(Count,Size);
end;

Function TFloat64Matrices.GetValues(Matrix,Row,Column: Integer): Float64;
begin
  Result := FRows[Row][Matrix,Column];
end;

Procedure TFloat64Matrices.SetValues(Matrix,Row,Column: Integer; Value: Float64);
begin
  FRows[Row][Matrix,Column] := Value;
end;

Function TFloat64Matrices.GetRows(Row: Integer): TCustomMatrixRows;
begin
  Result := FRows[Row];
end;

Function TFloat64Matrices.RowValues(Matrix,Row: Integer): TFloat64ArrayValues;
begin
  Result := FRows[Row].RowValues(Matrix);
end;

Destructor TFloat64Matrices.Destroy;
begin
  for var Row := low(FRows) to high(FRows) do FRows[Row].Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMemoryMatrixReader.Create(const Matrices: TCustomMatrices);
begin
  inherited Create;
  if Matrices <> nil then
    FMatrices := Matrices
  else
    raise Exception.Create('Matrices unassigned');
end;

Function TMemoryMatrixReader.Read: Integer;
begin
  Result := FCurrentRow;
  Inc(FCurrentRow);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TCustomMemoryMatrixRowsReader.SetReader(const MemoryReader: TMemoryMatrixReader);
begin
  if MemoryReader <> nil then
  begin
    Reader := MemoryReader;
    Init(Reader.Matrices.Count,Reader.Matrices.Size);
  end else
    raise Exception.Create('Reader unassigned');
end;

Function TCustomMemoryMatrixRowsReader.GetValues(Matrix,Column: Integer): Float64;
begin
  if Rows <> nil then Result := Rows[Matrix,Column] else Result := 0.0;
end;

Function TCustomMemoryMatrixRowsReader.GetFileLabel: String;
begin
  Result := Reader.Matrices.FileLabel;
end;

Function TCustomMemoryMatrixRowsReader.GetMatrixLabels(Matrix: Integer): String;
begin
  Result := Reader.Matrices.MatrixLabels[Matrix];
end;

Procedure TCustomMemoryMatrixRowsReader.Read;
begin
  FRow := Reader.Read;
  if FRow < Reader.Matrices.Size then
    Rows := Reader.Matrices.GetRows(FRow)
  else
    Rows := nil;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMemoryMatrixReaderRows.Create(const MemoryReader: TMemoryMatrixReader);
begin
  inherited Create;
  SetReader(MemoryReader);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMemoryMatrixRowsReader.Create(const Matrices: TCustomMatrices);
begin
  inherited Create;
  SetReader(TMemoryMatrixReader.Create(Matrices));
end;

Destructor TMemoryMatrixRowsReader.Destroy;
begin
  Reader.Free;
  inherited Destroy;
end;

end.
