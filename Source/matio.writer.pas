unit matio.writer;

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
  Classes, SysUtils, IOUtils, ArrBld, matio, matio.row;

Type
  TMatrixWriter = Class(TMatrixFiler)
  // TMatrixWriter is the abstract base class for all format specific matrix writer objects.
  // The Write-method is called once for each row, and writes the data for each matrix in the file.
  private
    Procedure WriteUsingGetter(NMatrices,RowSize: Integer; const Getter: TMatrixGetter);
    Procedure WriteCurrentRow(const Rows: TVirtualMatrixRows);
  strict protected
    Constructor Create(const FileName: String;
                       const Count,Size: Integer;
                       const CreateStream: Boolean = true); overload;
  protected
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); overload; virtual; abstract;
  public
    Class Var
      RoundToZeroThreshold: Float64;
  public
    Procedure Write(const Row: TVirtualMatrixRow); overload;
    Procedure Write(const Rows: TVirtualMatrixRows); overload;
    Procedure Write(const Row: TMatrixRowGetter); overload;
    Procedure Write(const Rows: array of TVirtualMatrixRow); overload;
    Procedure Write(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Write(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Write(const Rows: TMatrixGetter); overload;
  end;

  TMatrixEnumWriter = Class
  // A separate call to the Write-method is required for each matrix in the file.
  // A call to the NextRow-method indicates all matrices for a specific row have been enumerated
  // and the matrix rows can actually been written to file. The FixedRows-argument for the constructor
  // indicates whether rows may change between the Write-method call and the NextRow-method call.
  private
    FloatType: TFloatType;
    Count: Integer;
    Fixed: Boolean;
    Writer: TMatrixWriter;
    OwnsWriter: Boolean;
    // Buffers holding the rows written for the current file row
    Rows32: TArray<TFloat32MatrixRow>;
    Rows64: TArray<TFloat64MatrixRow>;
    Function StartsRow(const RowSize: Integer; const RowType: TFloatType): Boolean;
    Procedure AddRow<T>(const Row: TArray<T>; var Rows: TArray<TArray<T>>);
    Function CompletedRows<T>(const Rows: TArray<TArray<T>>): TArray<TArray<T>>;
  public
    Constructor Create(const MatrixWriter: TMatrixWriter; FixedRows: Boolean; OwnsMatrixWriter: Boolean = true);
    Procedure Write(const Row: TFloat32MatrixRow); overload;
    Procedure Write(const Row: TFloat64MatrixRow); overload;
    Procedure NextRow;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixWriter.Create(const FileName: String;
                                 const Count,Size: Integer;
                                 const CreateStream: Boolean = true);
begin
  inherited Create;
  FFileName := ExpandFileName(FileName);
  if CreateStream then
  FileStream := TBufferedFileStream.Create(FFileName,fmCreate or fmShareDenyWrite,BufferSize);
  SetCount(Count);
  SetSize(Size);
end;

Procedure TMatrixWriter.WriteUsingGetter(NMatrices,RowSize: Integer; const Getter: TMatrixGetter);
begin
  var GetterRows := TGetterMatrixRows.Create(NMatrices,RowSize,Getter);
  try
    Write(GetterRows);
  finally
    GetterRows.Free;
  end;
end;

Procedure TMatrixWriter.WriteCurrentRow(const Rows: TVirtualMatrixRows);
begin
  try
    SetRowsRoundToZeroThreshold(Rows,RoundToZeroThreshold);
    try
      Write(CurrentRow,Rows);
    finally
      SetRowsRoundToZeroThreshold(Rows,0.0);
    end;
  except
    on E: Exception do
      raise Exception.Create('Error (' + E.Message + ') writing row ' + (CurrentRow+1).ToString + ' in ' + FileName);
  end;
end;

Procedure TMatrixWriter.Write(const Row: TVirtualMatrixRow);
begin
  var Ref := Row;
  WriteUsingGetter(1,Size,
                   Function(Matrix,Column: Integer): Float64 begin Result := Ref[Column] end);
end;

Procedure TMatrixWriter.Write(const Rows: TVirtualMatrixRows);
begin
  if Assigned(Rows) then
    if CurrentRow < Size then
    begin
      WriteCurrentRow(Rows);
      Inc(CurrentRow);
    end else
      raise Exception.Create('Writing too many rows to matrix file')
  else
    raise Exception.Create('Rows unassigned');
end;

Procedure TMatrixWriter.Write(const Row: TMatrixRowGetter);
begin
  var GetterRow := TGetterMatrixRow.Create(Size,Row);
  try
    Write(GetterRow);
  finally
    GetterRow.Free;
  end;
end;

Procedure TMatrixWriter.Write(const Rows: array of TVirtualMatrixRow);
begin
  var Refs: TArray<TVirtualMatrixRow> := TArrayBuilder<TVirtualMatrixRow>.Create(Rows);
  var RowSize := 0;
  if Length(Refs) > 0 then RowSize := Refs[0].Size;
  for var Matrix := low(Refs) to high(Refs) do
  if Refs[Matrix].Size <> RowSize then
  raise Exception.Create('Matrix rows must have the same size');
  WriteUsingGetter(Length(Refs),RowSize,
                   Function(Matrix,Column: Integer): Float64 begin Result := Refs[Matrix][Column] end);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat64MatrixRow);
begin
  var Refs: TArray<TFloat64MatrixRow> := TArrayBuilder<TFloat64MatrixRow>.Create(Rows);
  WriteUsingGetter(Length(Refs),CheckedRowSize<Float64>(Refs),
                   Function(Matrix,Column: Integer): Float64 begin Result := Refs[Matrix][Column] end);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat32MatrixRow);
begin
  var Refs: TArray<TFloat32MatrixRow> := TArrayBuilder<TFloat32MatrixRow>.Create(Rows);
  WriteUsingGetter(Length(Refs),CheckedRowSize<Float32>(Refs),
                   Function(Matrix,Column: Integer): Float64 begin Result := Refs[Matrix][Column] end);
end;

Procedure TMatrixWriter.Write(const Rows: TMatrixGetter);
begin
  WriteUsingGetter(Count,Size,Rows);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixEnumWriter.Create(const MatrixWriter: TMatrixWriter; FixedRows: Boolean; OwnsMatrixWriter: Boolean = true);
begin
  inherited Create;
  Fixed := FixedRows;
  Writer := MatrixWriter;
  OwnsWriter := OwnsMatrixWriter;
end;

Function TMatrixEnumWriter.StartsRow(const RowSize: Integer; const RowType: TFloatType): Boolean;
// The first matrix of a file row sets the float type
begin
  if RowSize <> Writer.Size then raise Exception.Create('Invalid row size');
  Result := Count = 0;
  if Result then
    FloatType := RowType
  else
    if FloatType <> RowType then raise Exception.Create('Inconsistent row type');
end;

Procedure TMatrixEnumWriter.AddRow<T>(const Row: TArray<T>; var Rows: TArray<TArray<T>>);
begin
  if Count < Writer.Count then
  begin
    if Fixed then
      Rows[Count] := Row
    else
      Rows[Count] := Copy(Row);
    Inc(Count);
  end else
    raise Exception.Create('Writing too many matrices');
end;

Function TMatrixEnumWriter.CompletedRows<T>(const Rows: TArray<TArray<T>>): TArray<TArray<T>>;
// Matrices that have not been written read as zero
begin
  for var Matrix := Count to high(Rows) do SetLength(Rows[Matrix],Writer.Size);
  Result := Rows;
end;

Procedure TMatrixEnumWriter.Write(const Row: TFloat32MatrixRow);
begin
  if StartsRow(Length(Row),ftFloat32) then
  begin
    Rows32 := nil;
    SetLength(Rows32,Writer.Count);
  end;
  AddRow<Float32>(Row,Rows32);
end;

Procedure TMatrixEnumWriter.Write(const Row: TFloat64MatrixRow);
begin
  if StartsRow(Length(Row),ftFloat64) then
  begin
    Rows64 := nil;
    SetLength(Rows64,Writer.Count);
  end;
  AddRow<Float64>(Row,Rows64);
end;

Procedure TMatrixEnumWriter.NextRow;
begin
  if Count > 0 then
  begin
    case FloatType of
      ftFloat32: Writer.Write(CompletedRows<Float32>(Rows32));
      ftFloat64: Writer.Write(CompletedRows<Float64>(Rows64));
    end;
    Count := 0;
  end;
end;

Destructor TMatrixEnumWriter.Destroy;
begin
  if OwnsWriter then Writer.Free;
  inherited Destroy;
end;

end.
