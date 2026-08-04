unit matio;

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
  Classes, SysUtils, System.IOUtils, System.Types;

Type
  TFloatType = (ftFloat16,ftFloat32,ftFloat64);

  TFloat32MatrixRow = TArray<Float32>;
  TFloat64MatrixRow = TArray<Float64>;
  TMatrixRow = TFloat64MatrixRow;

  TMatrixGetter = TFunc<Integer,Integer,Float64>; // Returns the value at (Matrix,Column)
  TMatrixSetter = TProc<Integer,Integer,Float64>; // Receives the value at (Matrix,Column)
  TMatrixRowGetter = TFunc<Integer,Float64>;      // Returns the value at (Column) for a single matrix row

  TVirtualMatrixRow = Class
  // TVirtualMatrixRow is the abstract base class for all matrix row objects
  private
    FSize: Integer;
  strict protected
    Procedure Init(Size: Integer);
    Function GetValues(Column: Integer): Float64; virtual; abstract;
  public
    Function Total: Float64; overload;
  public
    Property Size: Integer read FSize;
    Property Values[Column: Integer]: Float64 read GetValues; default;
  end;

  TVirtualMatrixRows = Class
  // TVirtualMatrixRows is the abstract base class for all matrix rows objects
  private
    FCount,FSize: Integer;
    FTargetMatrices: TArray<Integer>;
    RoundToZeroThreshold: Float64;
  strict protected
    Procedure Init(Count,Size: Integer);
    Function GetValues(Matrix,Column: Integer): Float64; virtual; abstract;
    Function DoGetValues(Matrix,Column: Integer): Float64; inline;
  strict protected
    Property TargetMatrices: TArray<Integer> read FTargetMatrices;
  public
    Procedure GetRow(Matrix: Integer; var Row: TFloat32MatrixRow); overload;
    Procedure GetRow(Matrix: Integer; var Row: TFloat64MatrixRow); overload;
    Function Total: Float64; overload;
    Function Total(Matrix: Integer): Float64; overload;
  public
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
    Property Values[Matrix,Column: Integer]: Float64 read DoGetValues; default;
  end;

  TMatrixFiler = Class
  // TMatrixFiler is the abstract base class for all matrix reader and writer objects.
  strict protected
    Const
      BufferSize: Integer = 4096;
    Var
      FFileName: String;
      FCount,FSize,CurrentRow: Integer;
      FileStream: TBufferedFileStream;
    Class Function CheckedRowSize<T>(const Rows: TArray<TArray<T>>): Integer;
    Procedure SetCount(Count: Integer); virtual;
    Procedure SetSize(Size: Integer);
    Procedure SetRowsTargetMatrices(const Rows: TVirtualMatrixRows; const TargetMatrices: TArray<Integer>);
    Procedure SetRowsRoundToZeroThreshold(const Rows: TVirtualMatrixRows; const Threshold: Float64);
  public
    Destructor Destroy; override;
  public
    Property FileName: String read FFileName;
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
  end;

Const
  PrecisionLabels: array[TFloatType] of String = ('float16','float32','float64');

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TVirtualMatrixRow.Init(Size: Integer);
begin
  FSize := Size;
end;

Function TVirtualMatrixRow.Total: Float64;
begin
  Result := 0.0;
  for var Column := 0 to FSize-1 do Result := Result + GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TVirtualMatrixRows.Init(Count,Size: Integer);
begin
  FCount := Count;
  FSize := Size;
end;

Function TVirtualMatrixRows.DoGetValues(Matrix,Column: Integer): Float64;
begin
  if (Matrix < FCount) and (Column < FSize) then
  begin
    Result := GetValues(Matrix,Column);
    if Abs(Result) < RoundToZeroThreshold then Result := 0.0
  end else
    Result := 0.0;
end;

Procedure TVirtualMatrixRows.GetRow(Matrix: Integer; var Row: TFloat32MatrixRow);
begin
  if FSize < Length(Row) then
  begin
    for var Column := 0 to FSize-1 do Row[Column] := DoGetValues(Matrix,Column);
    for var Column := FSize to Length(Row)-1 do Row[Column] := 0.0;
  end else
    for var Column := 0 to Length(Row)-1 do Row[Column] := DoGetValues(Matrix,Column);
end;

Procedure TVirtualMatrixRows.GetRow(Matrix: Integer; var Row: TFloat64MatrixRow);
begin
  if FSize < Length(Row) then
  begin
    for var Column := 0 to FSize-1 do Row[Column] := DoGetValues(Matrix,Column);
    for var Column := FSize to Length(Row)-1 do Row[Column] := 0.0;
  end else
    for var Column := 0 to Length(Row)-1 do Row[Column] := DoGetValues(Matrix,Column);
end;

Function TVirtualMatrixRows.Total: Float64;
begin
  Result := 0.0;
  for var Matrix := 0 to FCount-1 do Result := Result + Total(Matrix);
end;

Function TVirtualMatrixRows.Total(Matrix: Integer): Float64;
begin
  Result := 0.0;
  for var Column := 0 to FSize-1 do Result := Result + GetValues(Matrix,Column);
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TMatrixFiler.CheckedRowSize<T>(const Rows: TArray<TArray<T>>): Integer;
begin
  Result := 0;
  if Length(Rows) > 0 then
  begin
    Result := Length(Rows[0]);
    for var Matrix := low(Rows) to high(Rows) do
    if Length(Rows[Matrix]) <> Result then raise Exception.Create('Matrix rows must have the same size');
  end;
end;

Procedure TMatrixFiler.SetCount(Count: Integer);
begin
  FCount := Count;
end;

Procedure TMatrixFiler.SetSize(Size: Integer);
begin
  FSize := Size;
end;

Procedure TMatrixFiler.SetRowsTargetMatrices(const Rows: TVirtualMatrixRows;
                                             const TargetMatrices: TArray<Integer>);
begin
  Rows.FTargetMatrices := TargetMatrices;
end;

Procedure TMatrixFiler.SetRowsRoundToZeroThreshold(const Rows: TVirtualMatrixRows;
                                                   const Threshold: Float64);
begin
  Rows.RoundToZeroThreshold := Threshold;
end;

Destructor TMatrixFiler.Destroy;
begin
  FileStream.Free;
  inherited Destroy;
end;

end.
