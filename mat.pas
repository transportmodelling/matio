unit mat;

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
  matio, matio.formats, ArrayVal, PropSet;

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
  public
    Function MatrixLabelValues: TStringArrayValues;
    Procedure Read(const [ref] Properties: TPropertySet); virtual; abstract;
    Procedure Transpose(Matrix: Integer); overload;
    Procedure Transpose; overload;
    Procedure Save(const [ref] Properties: TPropertySet); virtual; abstract;
  public
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
    Property FileName: String read FFileName;
    Property FileLabel: String read FFileLabel write FFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels write SetMatrixLabels;
    Property Values[Matrix,Row,Column: Integer]: Float64 read GetValues write SetValues; default;
  end;

  TFloat64Matrices = Class(TCustomMatrices)
  private
    FRows: array of TFloat64MatrixRows;
    Function GetValues(Matrix,Row,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Row,Column: Integer; Value: Float64); override;
  public
    Constructor Create(Count,Size: Integer);
    Procedure Read(const [ref] Properties: TPropertySet); override;
    Function RowValues(Matrix,Row: Integer): TFloat64ArrayValues;
    Procedure Save(const [ref] Properties: TPropertySet); override;
    Destructor Destroy;
  end;

  TFloat32Matrices = Class(TCustomMatrices)
  private
    FRows: array of TFloat32MatrixRows;
    Function GetValues(Matrix,Row,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Row,Column: Integer; Value: Float64); override;
  public
    Constructor Create(Count,Size: Integer);
    Procedure Read(const [ref] Properties: TPropertySet); override;
    Function RowValues(Matrix,Row: Integer): TFloat32ArrayValues;
    Procedure Save(const [ref] Properties: TPropertySet); override;
    Destructor Destroy;
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

Function TCustomMatrices.MatrixLabelValues: TStringArrayValues;
begin
  Result := TStringArrayValues.Create(FMatrixLabels);
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

Procedure TFloat64Matrices.Read(const [ref] Properties: TPropertySet);
begin
  var Reader := MatrixFormats.CreateReader(Properties);
  try
    ResetLabels;
    FFileName := Reader.FileName;
    FFileLabel := Reader.FileLabel;
    if FCount <= Reader.Count then
      for var Matrix := 0 to FCount-1 do FMatrixLabels[Matrix] := Reader.MatrixLabels[Matrix]
    else
      for var Matrix := 0 to Reader.Count-1 do FMatrixLabels[Matrix] := Reader.MatrixLabels[Matrix];
    for var Row := 0 to FSize-1 do Reader.Read(FRows[Row])
  finally
    Reader.Free;
  end;
end;

Function TFloat64Matrices.RowValues(Matrix,Row: Integer): TFloat64ArrayValues;
begin
  Result := FRows[Row].RowValues(Matrix);
end;

Procedure TFloat64Matrices.Save(const [ref] Properties: TPropertySet);
begin
  var Writer := MatrixFormats.CreateWriter(Properties,FFileLabel,FMatrixLabels,FSize);
  try
    FFileName := Writer.FileName;
    for var Row := 0 to FSize-1 do Writer.Write(FRows[Row])
  finally
    Writer.Free;
  end;
end;

Destructor TFloat64Matrices.Destroy;
begin
  for var Row := low(FRows) to high(FRows) do FRows[Row].Free;
  inherited Destroy;
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

Procedure TFloat32Matrices.Read(const [ref] Properties: TPropertySet);
begin
  var Reader := MatrixFormats.CreateReader(Properties);
  try
    ResetLabels;
    FFileName := Reader.FileName;
    FFileLabel := Reader.FileLabel;
    if FCount <= Reader.Count then
      for var Matrix := 0 to FCount-1 do FMatrixLabels[Matrix] := Reader.MatrixLabels[Matrix]
    else
      for var Matrix := 0 to Reader.Count-1 do FMatrixLabels[Matrix] := Reader.MatrixLabels[Matrix];
    for var Row := 0 to FSize-1 do Reader.Read(FRows[Row])
  finally
    Reader.Free;
  end;
end;

Function TFloat32Matrices.RowValues(Matrix,Row: Integer): TFloat32ArrayValues;
begin
  Result := FRows[Row].RowValues(Matrix);
end;

Procedure TFloat32Matrices.Save(const [ref] Properties: TPropertySet);
begin
  var Writer := MatrixFormats.CreateWriter(Properties,FFileLabel,FMatrixLabels,FSize);
  try
    FFileName := Writer.FileName;
    for var Row := 0 to FSize-1 do Writer.Write(FRows[Row])
  finally
    Writer.Free;
  end;
end;

Destructor TFloat32Matrices.Destroy;
begin
  for var Row := low(FRows) to high(FRows) do FRows[Row].Free;
  inherited Destroy;
end;

end.
