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
  strict protected
    Constructor Create(const FileName: String; const Count,Size: Integer; const CreateStream: Boolean = true); overload;
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

Procedure TMatrixWriter.Write(const Row: TVirtualMatrixRow);
begin
  var Ref := Row;
  WriteUsingGetter(1,Size,
    function(Matrix,Column: Integer): Float64
    begin
      Result := Ref[Column]
    end);
end;

Procedure TMatrixWriter.Write(const Rows: TVirtualMatrixRows);
begin
  if Assigned(Rows) then
    if CurrentRow < Size then
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
      Inc(CurrentRow);
    end else
      raise Exception.Create('Writing too many rows to matrix file')
  else
    raise Exception.Create('Rows unassigned');
end;

Procedure TMatrixWriter.Write(const Rows: TMatrixGetter);
begin
  WriteUsingGetter(Count,Size,Rows);
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
    function(Matrix,Column: Integer): Float64
    begin
      Result := Refs[Matrix][Column]
    end);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat32MatrixRow);
begin
  var Refs: TArray<TFloat32MatrixRow> := TArrayBuilder<TFloat32MatrixRow>.Create(Rows);
  WriteUsingGetter(Length(Refs),CheckedRowSize<Float32>(Refs),
    function(Matrix,Column: Integer): Float64
    begin
      Result := Refs[Matrix][Column]
    end);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat64MatrixRow);
begin
  var Refs: TArray<TFloat64MatrixRow> := TArrayBuilder<TFloat64MatrixRow>.Create(Rows);
  WriteUsingGetter(Length(Refs),CheckedRowSize<Float64>(Refs),
    function(Matrix,Column: Integer): Float64
    begin
      Result := Refs[Matrix][Column]
    end);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixEnumWriter.Create(const MatrixWriter: TMatrixWriter; FixedRows: Boolean; OwnsMatrixWriter: Boolean = true);
begin
  inherited Create;
  Fixed := FixedRows;
  Writer := MatrixWriter;
  OwnsWriter := OwnsMatrixWriter;
end;

Procedure TMatrixEnumWriter.Write(const Row: TFloat32MatrixRow);
begin
  if Length(Row) <> Writer.Size then raise Exception.Create('Invalid row size');
  // Set float type and reset the row collection on the first matrix of a file row
  if Count = 0 then
  begin
    FloatType := ftFloat32;
    Rows32 := nil;
    SetLength(Rows32,Writer.Count);
  end else
    if FloatType <> ftFloat32 then raise Exception.Create('Inconsistent row type');
  // Add row
  if Count < Writer.Count then
  begin
    if Fixed then
      Rows32[Count] := Row
    else
      Rows32[Count] := Copy(Row);
    Inc(Count);
  end else
    raise Exception.Create('Writing too many matrices');
end;

Procedure TMatrixEnumWriter.Write(const Row: TFloat64MatrixRow);
begin
  if Length(Row) <> Writer.Size then raise Exception.Create('Invalid row size');
  // Set float type and reset the row collection on the first matrix of a file row
  if Count = 0 then
  begin
    FloatType := ftFloat64;
    Rows64 := nil;
    SetLength(Rows64,Writer.Count);
  end else
    if FloatType <> ftFloat64 then raise Exception.Create('Inconsistent row type');
  // Add row
  if Count < Writer.Count then
  begin
    if Fixed then
      Rows64[Count] := Row
    else
      Rows64[Count] := Copy(Row);
    Inc(Count);
  end else
    raise Exception.Create('Writing too many matrices');
end;

Procedure TMatrixEnumWriter.NextRow;
begin
  if Count > 0 then
  begin
    case FloatType of
      ftFloat32:
        begin
          var Rows := Rows32;
          Writer.Write(function(Matrix,Column: Integer): Float64
                       begin
                         // Matrices that have not been written read as zero
                         if (Matrix < Length(Rows)) and (Column < Length(Rows[Matrix])) then
                           Result := Rows[Matrix][Column]
                         else
                           Result := 0.0
                       end);
        end;
      ftFloat64:
        begin
          var Rows := Rows64;
          Writer.Write(function(Matrix,Column: Integer): Float64
                       begin
                         // Matrices that have not been written read as zero
                         if (Matrix < Length(Rows)) and (Column < Length(Rows[Matrix])) then
                           Result := Rows[Matrix][Column]
                         else
                           Result := 0.0
                       end);
        end;
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
