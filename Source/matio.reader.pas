unit matio.reader;

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
  Classes, SysUtils, System.IOUtils, System.Types, ArrHlp, ArrBld, ArrVal, matio, matio.row;

Type
  TMatrixReader = Class(TMatrixFiler)
  // TMatrixReader is the abstract base class for all format specific matrix reader objects
  // The Read-method is called once for every row, and reads the data for each matrix in the file
  private
    FFileLabel: String;
    FMatrixLabels: TArray<String>;
    Function GetMatrixLabels(Mtrx: Integer): String; inline;
    Procedure ReadUsingSetter(NMatrices,RowSize: Integer; const Setter: TMatrixSetter);
    Procedure ReadCurrentRow(const Rows: TCustomMatrixRows);
    Procedure ZeroizeCells(const Rows: TCustomMatrixRows; const FirstMatrix,FirstColumn: Integer);
  strict protected
    FOrdered: Boolean; // True if matrices have a stable, well-defined order (index-based selection supported)
    Procedure SetCount(Count: Integer); override;
    Procedure SetFileLabel(const FileLabel: String);
    Procedure SetMatrixLabels(const Matrix: Integer; const MatrixLabel: String);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; virtual; abstract;
  public
    Constructor Create(const FileName: String; const CreateStream: Boolean = true); overload;
    Function  GetMatrix(const MatrixLabel: string): Integer;
    Function  MatrixLabelsArray: TStringDynArray;
    Procedure Read(const Row: TFloat32MatrixRow); overload;
    Procedure Read(const Row: TFloat64MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Read(const Rows: TCustomMatrixRows); overload;
    Procedure Read(const Setter: TMatrixSetter); overload;
  public
    Property Ordered: Boolean read FOrdered; // False if the format does not define a matrix order (e.g. OMX files, which identify matrices by name only); index-based selection will raise an error in that case
    Property FileLabel: String read FFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels;
  end;

  TMaskedMatrixReader = Class(TMatrixReader)
  // Reads a selection of the matrices in a file
  // The object takes ownership of the unmasked reader
  private
    Unmasked: TMatrixReader;
    TargetMatrices: TArray<Integer>;
    Procedure CopyFileProperties(const Reader: TMatrixReader);
    Function CheckedIndex(const Reader: TMatrixReader; const Selected: Integer): Integer;
    Function LabelIndex(const Reader: TMatrixReader; const MatrixLabel: String): Integer;
    Procedure ExtendTargetMatrices(const Selected: Integer);
    Procedure SelectMatrix(const Reader: TMatrixReader; const Selected: Integer);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; override;
  public
    Constructor Create(const Reader: TMatrixReader; const Selection: array of Integer); overload;
    Constructor Create(const Reader: TMatrixReader; const Selection: array of String); overload;
    Destructor Destroy; override;
  end;

  TMatrixEnumReader = Class
  // A separate call to the Read-method is required for each matrix in the file.
  // A call to the NextRow-method indicates all matrices for a specific row have been enumerated.
  private
    FloatType: TFloatType;
    Size,Count,Index: Integer;
    Reader: TMatrixReader;
    OwnsReader: Boolean;
    // Buffers holding all matrices of the current row
    Rows32: TArray<TFloat32MatrixRow>;
    Rows64: TArray<TFloat64MatrixRow>;
    Function ReadsMatrices(const RowSize: Integer; const RowType: TFloatType): Boolean;
    Procedure AllocateRows<T>(var Rows: TArray<TArray<T>>);
    Procedure TakeRow<T>(var Row: TArray<T>; var Rows: TArray<TArray<T>>);
  public
    Constructor Create(const Reader: TMatrixReader; Count,Size: Integer; OwnsReader: Boolean = true);
    Procedure Read(var Row: TFloat32MatrixRow); overload;
    Procedure Read(var Row: TFloat64MatrixRow); overload;
    Procedure NextRow;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixReader.Create(const FileName: String; const CreateStream: Boolean = true);
begin
  inherited Create;
  FOrdered := true;
  FFileName := ExpandFileName(FileName);
  if CreateStream then
  FileStream := TBufferedFileStream.Create(FFileName,fmOpenRead or fmShareDenyWrite,BufferSize);
end;

Function TMatrixReader.GetMatrixLabels(Mtrx: Integer): String;
begin
  Result := FMatrixLabels[Mtrx];
end;

Procedure TMatrixReader.ReadUsingSetter(NMatrices,RowSize: Integer; const Setter: TMatrixSetter);
begin
  var SetterRows := TSetterMatrixRows.Create(NMatrices,RowSize,Setter);
  try
    Read(SetterRows);
  finally
    SetterRows.Free;
  end;
end;

Procedure TMatrixReader.ReadCurrentRow(const Rows: TCustomMatrixRows);
begin
  try
    Read(CurrentRow,Rows);
  except
    on E: Exception do
      raise Exception.Create('Error (' + E.Message + ') reading row ' + (CurrentRow+1).ToString + ' in ' + FileName);
  end;
end;

Procedure TMatrixReader.ZeroizeCells(const Rows: TCustomMatrixRows; const FirstMatrix,FirstColumn: Integer);
begin
  for var Matrix := FirstMatrix to Rows.Count-1 do
  for var Column := FirstColumn to Rows.Size-1 do
  Rows[Matrix,Column] := 0.0;
end;

Procedure TMatrixReader.SetCount(Count: Integer);
begin
  inherited SetCount(Count);
  SetLength(FMatrixLabels,Count);
end;

Procedure TMatrixReader.SetFileLabel(const FileLabel: String);
begin
  FFileLabel := FileLabel;
end;

Procedure TMatrixReader.SetMatrixLabels(const Matrix: Integer; const MatrixLabel: String);
begin
  FMatrixLabels[Matrix] := MatrixLabel;
end;

Function TMatrixReader.GetMatrix(const MatrixLabel: string): Integer;
begin
  Result := -1;
  for var Matrix := 0 to Count-1 do
  if SameText(FMatrixLabels[Matrix],MatrixLabel) then Exit(Matrix);
end;

Function TMatrixReader.MatrixLabelsArray: TStringDynArray;
begin
  Result := Copy(FMatrixLabels);
end;

Procedure TMatrixReader.Read(const Row: TFloat32MatrixRow);
begin
  var Ref := Row;
  ReadUsingSetter(1,Length(Ref),
                  Procedure(Matrix,Column: Integer; Value: Float64) begin Ref[Column] := Value end);
end;

Procedure TMatrixReader.Read(const Row: TFloat64MatrixRow);
begin
  var Ref := Row;
  ReadUsingSetter(1,Length(Ref),
                  Procedure(Matrix,Column: Integer; Value: Float64) begin Ref[Column] := Value end);
end;

Procedure TMatrixReader.Read(const Rows: array of TFloat32MatrixRow);
// The rows keep referencing the caller's arrays, so the values are written
// directly into the caller's arrays
begin
  var Refs: TArray<TFloat32MatrixRow> := TArrayBuilder<TFloat32MatrixRow>.Create(Rows);
  ReadUsingSetter(Length(Refs),CheckedRowSize<Float32>(Refs),
                  Procedure(Matrix,Column: Integer; Value: Float64) begin Refs[Matrix][Column] := Value end);
end;

Procedure TMatrixReader.Read(const Rows: array of TFloat64MatrixRow);
// The rows keep referencing the caller's arrays, so the values are written
// directly into the caller's arrays
begin
  var Refs: TArray<TFloat64MatrixRow> := TArrayBuilder<TFloat64MatrixRow>.Create(Rows);
  ReadUsingSetter(Length(Refs),CheckedRowSize<Float64>(Refs),
                  Procedure(Matrix,Column: Integer; Value: Float64) begin Refs[Matrix][Column] := Value end);
end;

Procedure TMatrixReader.Read(const Setter: TMatrixSetter);
// The setter is called for every cell of the current row the format reader
// produces; cells that are absent from the file (and thus read as zero) may
// not be passed. The column dimension is left unbounded because some formats
// (e.g. text) discover their size incrementally while reading.
begin
  var SetterRows := TSetterMatrixRows.Create(Count,MaxInt,Setter);
  try
    ReadCurrentRow(SetterRows);
    Inc(CurrentRow);
  finally
    SetterRows.Free;
  end;
end;

Procedure TMatrixReader.Read(const Rows: TCustomMatrixRows);
begin
  if Assigned(Rows) then
  begin
    ReadCurrentRow(Rows);
    // Zeroize values not read from file
    if Size < Rows.Size then ZeroizeCells(Rows,0,Size);
    if Count < Rows.Count then ZeroizeCells(Rows,Count,0);
    Inc(CurrentRow);
  end else
    raise Exception.Create('Rows unassigned');
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMaskedMatrixReader.Create(const Reader: TMatrixReader; const Selection: array of Integer);
begin
  if Length(Selection) > 0 then
  begin
    inherited Create(Reader.FileName,false);
    CopyFileProperties(Reader);
    for var Index := low(Selection) to high(Selection) do SelectMatrix(Reader,CheckedIndex(Reader,Selection[Index]));
    Unmasked := Reader;
  end else
    raise Exception.Create('Empty selection');
end;

Constructor TMaskedMatrixReader.Create(const Reader: TMatrixReader; const Selection: array of String);
begin
  if Length(Selection) > 0 then
  begin
    inherited Create(Reader.FileName,false);
    CopyFileProperties(Reader);
    for var Index := low(Selection) to high(Selection) do SelectMatrix(Reader,LabelIndex(Reader,Selection[Index]));
    Unmasked := Reader;
  end else
    raise Exception.Create('Empty selection');
end;

Procedure TMaskedMatrixReader.CopyFileProperties(const Reader: TMatrixReader);
begin
  FFileLabel := Reader.FFileLabel;
  SetSize(Reader.Size);
end;

Function TMaskedMatrixReader.CheckedIndex(const Reader: TMatrixReader; const Selected: Integer): Integer;
begin
  if (Selected < 0) or (Selected >= Reader.Count) then
    raise Exception.Create('Matrix index ' + Selected.ToString + ' out of range');
  Result := Selected;
end;

Function TMaskedMatrixReader.LabelIndex(const Reader: TMatrixReader; const MatrixLabel: String): Integer;
begin
  Result := Reader.GetMatrix(MatrixLabel);
  if Result < 0 then raise Exception.Create('Matrix ' + MatrixLabel + ' does not exist');
end;

Procedure TMaskedMatrixReader.ExtendTargetMatrices(const Selected: Integer);
begin
  var Nmatrices := TargetMatrices.Length;
  if Selected >= Nmatrices then
  begin
    TargetMatrices.Length := Selected+1;
    for var Matrix := Nmatrices to Selected do TargetMatrices[Matrix] := -1;
  end;
end;

Procedure TMaskedMatrixReader.SelectMatrix(const Reader: TMatrixReader; const Selected: Integer);
// Maps the selected source matrix onto the next target index
begin
  ExtendTargetMatrices(Selected);
  if TargetMatrices[Selected] < 0 then
  begin
    TargetMatrices[Selected] := Count;
    SetCount(Count+1);
    SetMatrixLabels(Count-1,Reader.MatrixLabels[Selected]);
  end else
    raise Exception.Create('Matrix ' + Selected.ToString + ' selected multiple times');
end;

Procedure TMaskedMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  SetRowsTargetMatrices(Rows,TargetMatrices);
  try
    Unmasked.Read(CurrentRow,Rows);
    SetCount(Unmasked.Count);
    SetSize(Unmasked.Size);
  finally
    SetRowsTargetMatrices(Rows,nil);
  end;
end;

Destructor TMaskedMatrixReader.Destroy;
begin
  Unmasked.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixEnumReader.Create(const Reader: TMatrixReader; Count,Size: Integer; OwnsReader: Boolean = true);
begin
  inherited Create;
  Self.Reader := Reader;
  Self.Size := Size;
  Self.Count := Count;
  Self.OwnsReader := OwnsReader;
end;

Function TMatrixEnumReader.ReadsMatrices(const RowSize: Integer; const RowType: TFloatType): Boolean;
// The matrices are read when the first matrix of a file row is requested
begin
  if RowSize <> Size then raise Exception.Create('Invalid row size');
  Result := Index = 0;
  if Result then
    FloatType := RowType
  else
    if FloatType <> RowType then raise Exception.Create('Inconsistent row type');
end;

Procedure TMatrixEnumReader.AllocateRows<T>(var Rows: TArray<TArray<T>>);
begin
  SetLength(Rows,Count);
  for var Matrix := 0 to Count-1 do
  if Length(Rows[Matrix]) <> Size then SetLength(Rows[Matrix],Size);
end;

Procedure TMatrixEnumReader.TakeRow<T>(var Row: TArray<T>; var Rows: TArray<TArray<T>>);
// Copies the result from the matrices
begin
  if Index < Count then
  begin
    if TArrayInfo.RefCount(Row) = 1 then
    begin
      // Exchange rows to avoid copying values
      var ReadRow := Rows[Index];
      Rows[Index] := Row;
      Row := ReadRow;
    end else
      // Multiple references to row, so copy values
      for var Column := 0 to Size-1 do Row[Column] := Rows[Index][Column];
    Inc(Index);
  end;
end;

Procedure TMatrixEnumReader.Read(var Row: TFloat32MatrixRow);
begin
  if ReadsMatrices(Length(Row),ftFloat32) then
  begin
    AllocateRows<Float32>(Rows32);
    Reader.Read(Rows32);
  end;
  TakeRow<Float32>(Row,Rows32);
end;

Procedure TMatrixEnumReader.Read(var Row: TFloat64MatrixRow);
begin
  if ReadsMatrices(Length(Row),ftFloat64) then
  begin
    AllocateRows<Float64>(Rows64);
    Reader.Read(Rows64);
  end;
  TakeRow<Float64>(Row,Rows64);
end;

Procedure TMatrixEnumReader.NextRow;
begin
  Index := 0;
end;

Destructor TMatrixEnumReader.Destroy;
begin
  if OwnsReader then Reader.Free;
  inherited Destroy;
end;

end.
