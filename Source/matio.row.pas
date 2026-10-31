unit matio.row;

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
  SysUtils, ArrHlp, ArrVal, matio;

Type
  TGetterMatrixRow = Class(TVirtualMatrixRow)
  private
    FValues: TMatrixRowGetter;
  strict protected
    Function GetValues(Column: Integer): Float64; override; final;
  public
    Constructor Create(const Size: Integer; const Values: TMatrixRowGetter);
  end;

  TGetterMatrixRows = Class(TVirtualMatrixRows)
  private
    FValues: TMatrixGetter;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override; final;
  public
    Constructor Create(const Count,Size: Integer; const Values: TMatrixGetter);
  end;

  TCustomMatrixRows = Class(TVirtualMatrixRows)
  // Base class for matrix rows with read and write access. Descendents must implement
  // the in memory storage for matrix values.
  private
    Procedure SetTargetValues(Matrix,Column: Integer; Value: Float64);
    Procedure DoSetValues(Matrix,Column: Integer; Value: Float64); inline;
  strict protected
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); virtual; abstract;
  public
    Procedure Clear;
    Procedure Initialize(Value: Float64 = 0.0);
  public
    Property Values[Matrix,Column: Integer]: Float64 read DoGetValues write DoSetValues; default;
  end;

  TSetterMatrixRows = Class(TCustomMatrixRows)
  // Write-only matrix rows that pass each assigned value to a setter-method,
  // the mirror image of TGetterMatrixRows. Bounds checking and target-matrix
  // remapping apply before the setter is invoked, so the setter only receives
  // values for cells within the Count/Size bounds.
  private
    FSetter: TMatrixSetter;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override; final;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); override; final;
  public
    Constructor Create(const Count,Size: Integer; const Setter: TMatrixSetter);
  end;

  TCustomFloatMatrixRows = Class(TCustomMatrixRows)
  // Base class for matrix rows that hold their values in memory. Descendents
  // allocate the values for the float type they store.
  strict protected
    Procedure AllocateValues(Count,Size: Integer); virtual; abstract;
  public
    Constructor Create(Count,Size: Integer); overload;
    Procedure Allocate(Count,Size: Integer);
  end;

  TFloat32MatrixRows = Class(TCustomFloatMatrixRows)
  private
    FValues: array of TFloat32MatrixRow;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); override;
    Procedure AllocateValues(Count,Size: Integer); override;
  public
    Function RowValues(Matrix: Integer): TFloat32ArrayValues;
  end;

  TFloat64MatrixRows = Class(TCustomFloatMatrixRows)
  private
    FValues: array of TFloat64MatrixRow;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); override;
    Procedure AllocateValues(Count,Size: Integer); override;
  public
    Function RowValues(Matrix: Integer): TFloat64ArrayValues;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TGetterMatrixRow.Create(const Size: Integer; const Values: TMatrixRowGetter);
begin
  inherited Create;
  Init(Size);
  FValues := Values;
end;

Function TGetterMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := FValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TGetterMatrixRows.Create(const Count,Size: Integer; const Values: TMatrixGetter);
begin
  inherited Create;
  Init(Count,Size);
  FValues := Values;
end;

Function TGetterMatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues(Matrix,Column);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TCustomMatrixRows.SetTargetValues(Matrix,Column: Integer; Value: Float64);
// Maps the matrix onto its index in the target matrices
begin
  if Matrix < TargetMatrices.Length then
  begin
    Matrix := TargetMatrices[Matrix];
    if (Matrix >= 0) and (Matrix < Count) and (Column < Size) then SetValues(Matrix,Column,Value);
  end;
end;

Procedure TCustomMatrixRows.DoSetValues(Matrix,Column: Integer; Value: Float64);
begin
  if TargetMatrices.Length = 0 then
  begin
    if (Matrix < Count) and (Column < Size) then SetValues(Matrix,Column,Value);
  end else
    SetTargetValues(Matrix,Column,Value);
end;

Procedure TCustomMatrixRows.Clear;
begin
  Init(0,Size);
end;

Procedure TCustomMatrixRows.Initialize(Value: Float64 = 0.0);
begin
  for var Matrix := 0 to Count-1 do
  for var Column := 0 to Size-1 do
  SetValues(Matrix,Column,Value);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TSetterMatrixRows.Create(const Count,Size: Integer; const Setter: TMatrixSetter);
begin
  inherited Create;
  Init(Count,Size);
  FSetter := Setter;
end;

Function TSetterMatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  raise Exception.Create('Cannot read from write-only matrix rows');
end;

Procedure TSetterMatrixRows.SetValues(Matrix,Column: Integer; Value: Float64);
begin
  FSetter(Matrix,Column,Value);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TCustomFloatMatrixRows.Create(Count,Size: Integer);
begin
  inherited Create;
  Allocate(Count,Size);
end;

Procedure TCustomFloatMatrixRows.Allocate(Count,Size: Integer);
begin
  Init(Count,Size);
  AllocateValues(Count,Size);
end;

////////////////////////////////////////////////////////////////////////////////

Function TFloat32MatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues[Matrix,Column];
end;

Procedure TFloat32MatrixRows.SetValues(Matrix,Column: Integer; Value: Float64);
begin
  FValues[Matrix,Column] := Value
end;

Procedure TFloat32MatrixRows.AllocateValues(Count,Size: Integer);
begin
  SetLength(FValues,Count,Size);
end;

Function TFloat32MatrixRows.RowValues(Matrix: Integer): TFloat32ArrayValues;
begin
  Result := TFloat32ArrayValues.Create(FValues[Matrix])
end;

////////////////////////////////////////////////////////////////////////////////

Function TFloat64MatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues[Matrix,Column];
end;

Procedure TFloat64MatrixRows.SetValues(Matrix,Column: Integer; Value: Float64);
begin
  FValues[Matrix,Column] := Value
end;

Procedure TFloat64MatrixRows.AllocateValues(Count,Size: Integer);
begin
  SetLength(FValues,Count,Size);
end;

Function TFloat64MatrixRows.RowValues(Matrix: Integer): TFloat64ArrayValues;
begin
  Result := TFloat64ArrayValues.Create(FValues[Matrix])
end;

end.
