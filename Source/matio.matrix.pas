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
  matio, matio.row, matio.reader, matio.formats, ArrVal, KeyVal;

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

end.
