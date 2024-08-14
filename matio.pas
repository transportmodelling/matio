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
  System.Classes, System.SysUtils, System.IOUtils, System.Types, PropSet, ArrayHlp, ArrayVal;

Type
  TFloatType = (ftFloat16,ftFloat32,ftFloat64);

  TFloat32MatrixRow = TArray<Float32>;
  TFloat64MatrixRow = TArray<Float64>;
  TMatrixRow = TFloat64MatrixRow;

  TVirtualMatrixRow = Class
  // Read only matrix row
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

  TDelegatedMatrixRow = Class(TVirtualMatrixRow)
  private
    FValues: TFunc<Integer,Float64>;
  strict protected
    Function GetValues(Column: Integer): Float64; override; final;
  public
    Constructor Create(const Size: Integer; const Values: TFunc<Integer,Float64>);
  end;

  TVirtualMatrixRows = Class
  // Read only matrix rows
  private
    FCount,FSize: Integer;
    RoundToZeroThreshold: Float64;
    Function DoGetValues(Matrix,Column: Integer): Float64; inline;
  strict protected
    Procedure Init(Count,Size: Integer);
    Function GetValues(Matrix,Column: Integer): Float64; virtual; abstract;
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

  TCustomMatrixRows = Class(TVirtualMatrixRows)
  // Base class for matrix rows with read and write access. Descendents must implement
  // the in memory storage for matrix values.
  private
    TargetMatrices: TArray<Integer>;
    Procedure DoSetValues(Matrix,Column: Integer; Value: Float64); inline;
  strict protected
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); virtual; abstract;
  public
    Procedure Initialize(Value: Float64 = 0.0);
  public
    Property Values[Matrix,Column: Integer]: Float64 read DoGetValues write DoSetValues; default;
  end;

  TFloat64MatrixRows = Class(TCustomMatrixRows)
  private
    FValues: array of TFloat64MatrixRow;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); override;
  public
    Constructor Create; overload;
    Constructor Create(Count,Size: Integer); overload;
    Procedure Allocate(Count,Size: Integer);
    Function RowValues(Matrix: Integer): TFloat64ArrayValues;
  end;

  TFloat32MatrixRows = Class(TCustomMatrixRows)
  private
    FValues: array of TFloat32MatrixRow;
  strict protected
    Function GetValues(Matrix,Column: Integer): Float64; override;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); override;
  public
    Constructor Create; overload;
    Constructor Create(Count,Size: Integer); overload;
    Procedure Allocate(Count,Size: Integer);
    Function RowValues(Matrix: Integer): TFloat32ArrayValues;
  end;

  TMatrixIterator = Class
  private
    FCount,FSize,Index: Integer;
    Matrices: TFloat64MatrixRows;
  strict protected
    Procedure Yield(const Row: TMatrixRow);
  public
    Constructor Create(Count,Size: Integer);
    Procedure Iterate; virtual; abstract;
    Destructor Destroy; override;
  public
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
  end;

  TMatrixFiler = Class
  // TMatrixFiler is the abstract base class for all matrix reader and writer objects
  private
    FFileName: String;
    FCount,FSize,CurrentRow: Integer;
  strict protected
    Const
      BufferSize: Integer = 4096;
    Var
      FileStream: TBufferedFileStream;
      Float64MatrixRows: TFloat64MatrixRows;
      Float32MatrixRows: TFloat32MatrixRows;
    Procedure SetCount(Count: Integer); virtual;
    Procedure SetSize(Size: Integer);
  public
    Constructor Create;
    Destructor Destroy; override;
  public
    Property FileName: String read FFileName;
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
  end;

  TMatrixReader = Class(TMatrixFiler)
  // TMatrixReader is the abstract base class for all format specific matrix reader objects
  private
    FFileLabel: String;
    FMatrixLabels: TArray<String>;
    Function GetMatrixLabels(Mtrx: Integer): String; inline;
  strict protected
    Constructor Create(const FileName: String; const CreateStream: Boolean = true); overload;
    Procedure SetCount(Count: Integer); override;
    Procedure SetFileLabel(const FileLabel: String);
    Procedure SetMatrixLabels(const Matrix: Integer; const MatrixLabel: String);
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; virtual; abstract;
  public
    Function  GetMatrix(const MatrixLabel: string): Integer;
    Function  MatrixLabelsArray: TStringDynArray;
    Procedure Read(const Row: TFloat64MatrixRow); overload;
    Procedure Read(const Row: TFloat32MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Read(const Rows: TCustomMatrixRows); overload;
    Procedure Read(const Rows: TMatrixIterator); overload;
  public
    Property FileLabel: String read FFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels;
  end;

  TMaskedMatrixReader = Class(TMatrixReader)
  // Reads a selection of the matrices in a file
  // The object takes ownership of the unmasked reader
  private
    Unmasked: TMatrixReader;
    TargetMatrices: TArray<Integer>;
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; override;
  public
    Constructor Create(const Reader: TMatrixReader; const Selection: array of Integer); overload;
    Constructor Create(const Reader: TMatrixReader; const Selection: array of String); overload;
    Destructor Destroy; override;
  end;

  TMatrixWriter = Class(TMatrixFiler)
  // TMatrixWriter is the abstract base class for all format specific matrix writer objects
  private
    Type
      TMatrixRows = Class(TVirtualMatrixRows)
      private
        Values: array of TVirtualMatrixRow;
      strict protected
        Function GetValues(Matrix,Column: Integer): Float64; override;
      end;
    Var
      MatrixRows: TMatrixRows;
  strict protected
    Constructor Create(const FileName: String; const Count,Size: Integer; const CreateStream: Boolean = true); overload;
  protected
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); overload; virtual; abstract;
  public
    Class Var
      RoundToZeroThreshold: Float64;
  public
    Procedure Write(const Row: TVirtualMatrixRow); overload;
    Procedure Write(const Row: TFloat64MatrixRow); overload;
    Procedure Write(const Row: TFloat32MatrixRow); overload;
    Procedure Write(const Rows: array of TVirtualMatrixRow); overload;
    Procedure Write(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Write(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Write(const Rows: TVirtualMatrixRows); overload;
    Procedure Write(const Rows: TMatrixIterator); overload;
    Destructor Destroy; override;
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

Constructor TDelegatedMatrixRow.Create(const Size: Integer; const Values: TFunc<Integer,Float64>);
begin
  inherited Create;
  Init(Size);
  FValues := Values;
end;

Function TDelegatedMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := FValues(Column);
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

Procedure TCustomMatrixRows.DoSetValues(Matrix,Column: Integer; Value: Float64);
begin
  if TargetMatrices.Length = 0 then
  begin
    if (Matrix < FCount) and (Column < FSize) then SetValues(Matrix,Column,Value);
  end else
  if Matrix < TargetMatrices.Length then
  begin
    Matrix := TargetMatrices[Matrix];
    if (Matrix >= 0) and (Matrix < FCount) and (Column < FSize) then SetValues(Matrix,Column,Value);
  end;
end;

Procedure TCustomMatrixRows.Initialize(Value: Float64 = 0.0);
begin
  for var Matrix := 0 to FCount-1 do
  for var Column := 0 to FSize-1 do
  SetValues(Matrix,Column,Value);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TFloat64MatrixRows.Create;
begin
  inherited Create;
end;

Constructor TFloat64MatrixRows.Create(Count,Size: Integer);
begin
  inherited Create;
  Allocate(Count,Size);
end;

Function TFloat64MatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues[Matrix,Column];
end;

Procedure TFloat64MatrixRows.SetValues(Matrix,Column: Integer; Value: Float64);
begin
  FValues[Matrix,Column] := Value
end;

Procedure TFloat64MatrixRows.Allocate(Count,Size: Integer);
begin
  Init(Count,Size);
  SetLength(FValues,Count,Size);
end;

Function TFloat64MatrixRows.RowValues(Matrix: Integer): TFloat64ArrayValues;
begin
  Result := TFloat64ArrayValues.Create(FValues[Matrix])
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TFloat32MatrixRows.Create;
begin
  inherited Create;
end;

Constructor TFloat32MatrixRows.Create(Count,Size: Integer);
begin
  inherited Create;
  Allocate(Count,Size);
end;

Function TFloat32MatrixRows.GetValues(Matrix,Column: Integer): Float64;
begin
  Result := FValues[Matrix,Column];
end;

Procedure TFloat32MatrixRows.SetValues(Matrix,Column: Integer; Value: Float64);
begin
  FValues[Matrix,Column] := Value
end;

Procedure TFloat32MatrixRows.Allocate(Count,Size: Integer);
begin
  Init(Count,Size);
  SetLength(FValues,Count,Size);
end;

Function TFloat32MatrixRows.RowValues(Matrix: Integer): TFloat32ArrayValues;
begin
  Result := TFloat32ArrayValues.Create(FValues[Matrix])
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixIterator.Create(Count,Size: Integer);
begin
  inherited Create;
  FCount := Count;
  FSize := Size;
  Matrices := TFloat64MatrixRows.Create(Count,0);
  Matrices.FSize := Size;
end;

Procedure TMatrixIterator.Yield(const Row: TMatrixRow);
begin
  if Length(Row) = FSize then
  begin
    Matrices.FValues[Index] := Row;
    Inc(Index);
  end else
    raise Exception.Create('Invalid row size');
end;

Destructor TMatrixIterator.Destroy;
begin
  Matrices.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixFiler.Create;
begin
  inherited Create;
  Float64MatrixRows := TFloat64MatrixRows.Create(0,0);
  Float32MatrixRows := TFloat32MatrixRows.Create(0,0);
end;

Procedure TMatrixFiler.SetCount(Count: Integer);
begin
  FCount := Count;
end;

Procedure TMatrixFiler.SetSize(Size: Integer);
begin
  FSize := Size;
end;

Destructor TMatrixFiler.Destroy;
begin
  Float64MatrixRows.Free;
  Float32MatrixRows.Free;
  FileStream.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixReader.Create(const FileName: String; const CreateStream: Boolean = true);
begin
  inherited Create;
  FFileName := ExpandFileName(FileName);
  if CreateStream then
  FileStream := TBufferedFileStream.Create(FFileName,fmOpenRead or fmShareDenyWrite,BufferSize);
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

Function TMatrixReader.GetMatrixLabels(Mtrx: Integer): String;
begin
  Result := FMatrixLabels[Mtrx];
end;

Procedure TMatrixReader.SetMatrixLabels(const Matrix: Integer; const MatrixLabel: String);
begin
  FMatrixLabels[Matrix] := MatrixLabel;
end;

Function TMatrixReader.GetMatrix(const MatrixLabel: string): Integer;
begin
  Result := -1;
  for var Matrix := 0 to FCount-1 do
  if SameText(FMatrixLabels[Matrix],MatrixLabel) then Exit(Matrix);
end;

Function TMatrixReader.MatrixLabelsArray: TStringDynArray;
begin
  Result := Copy(FMatrixLabels);
end;

Procedure TMatrixReader.Read(const Row: TFloat64MatrixRow);
begin
  Float64MatrixRows.FCount := 1;
  Float64MatrixRows.FSize := Length(Row);
  SetLength(Float64MatrixRows.FValues,1);
  Float64MatrixRows.FValues[0] := Row;
  Read(Float64MatrixRows);
end;

Procedure TMatrixReader.Read(const Row: TFloat32MatrixRow);
begin
  Float32MatrixRows.FCount := 1;
  Float32MatrixRows.FSize := Length(Row);
  SetLength(Float32MatrixRows.FValues,1);
  Float32MatrixRows.FValues[0] := Row;
  Read(Float32MatrixRows);
end;

Procedure TMatrixReader.Read(const Rows: array of TFloat64MatrixRow);
begin
  Float64MatrixRows.FCount := Length(Rows);
  Float64MatrixRows.FSize := Length(Rows[0]);
  SetLength(Float64MatrixRows.FValues,Length(Rows));
  for var Matrix := low(Rows) to high(Rows) do
  if Length(Rows[Matrix]) = Float64MatrixRows.FSize then
    Float64MatrixRows.FValues[Matrix] := Rows[Matrix]
  else
    raise Exception.Create('Matrix rows must have the same size');
  Read(Float64MatrixRows);
end;

Procedure TMatrixReader.Read(const Rows: array of TFloat32MatrixRow);
begin
  Float32MatrixRows.FCount := Length(Rows);
  Float32MatrixRows.FSize := Length(Rows[0]);
  SetLength(Float32MatrixRows.FValues,Length(Rows));
  for var Matrix := low(Rows) to high(Rows) do
  if Length(Rows[Matrix]) = Float32MatrixRows.FSize then
    Float32MatrixRows.FValues[Matrix] := Rows[Matrix]
  else
    raise Exception.Create('Matrix rows must have the same size');
  Read(Float32MatrixRows);
end;

Procedure TMatrixReader.Read(const Rows: TCustomMatrixRows);
begin
  if Assigned(Rows) then
  begin
    try
      Read(CurrentRow,Rows);
    except
      on E: Exception do
        raise Exception.Create('Error (' + E.Message + ') reading row ' +
                               (CurrentRow+1).ToString + ' in ' + FFileName);
    end;
    // Zeroize values not read from file
    if Size < Rows.Size then
    for var Matrix := 0 to Rows.Count-1 do
    for var Column := Size to Rows.Size-1 do
    Rows[Matrix,Column] := 0.0;
    if FCount < Rows.Count then
    for var Matrix := FCount to Rows.Count-1 do
    for var Column := 0 to Rows.Size-1 do
    Rows[Matrix,Column] := 0.0;
    Inc(CurrentRow);
  end else
    raise Exception.Create('Rows unassigned');
end;

Procedure TMatrixReader.Read(const Rows: TMatrixIterator);
begin
  Rows.Index := 0;
  Rows.Iterate;
  if Rows.Index = Rows.FCount then
    Read(Rows.Matrices)
  else
    raise Exception.Create('Invalid iteration count');
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMaskedMatrixReader.Create(const Reader: TMatrixReader; const Selection: array of Integer);
begin
  if Length(Selection) > 0 then
  begin
    inherited Create(Reader.FileName,false);
    // Copy file properties
    FFileLabel := Reader.FFileLabel;
    SetSize(Reader.Size);
    // Set target matrices
    var Nmatrices := 0;
    for var Selected in Selection do
    begin
      if Selected >= Nmatrices then
      begin
        TargetMatrices.Length := Selected+1;
        for var Matrix := Nmatrices to Selected do TargetMatrices[Matrix] := -1;
        Nmatrices := TargetMatrices.Length;
      end;
      if TargetMatrices[Selected] < 0 then
      begin
        TargetMatrices[Selected] := FCount;
        SetCount(FCount+1);
        SetMatrixLabels(FCount-1,Reader.MatrixLabels[Selected]);
      end else
        raise Exception.Create('Matrix ' + Selected.ToString + ' selected multiple times');
    end;
    // Set unmasked reader
    Unmasked := Reader;
  end else
    raise Exception.Create('Empty selection');
end;

Constructor TMaskedMatrixReader.Create(const Reader: TMatrixReader; const Selection: array of String);
begin
  if Length(Selection) > 0 then
  begin
    inherited Create(Reader.FileName,false);
    // Copy file properties
    FFileLabel := Reader.FFileLabel;
    SetSize(Reader.Size);
    // Set target matrices
    var Nmatrices := 0;
    for var MatrixLabel in Selection do
    begin
      var Selected := Reader.GetMatrix(MatrixLabel);
      if Selected >= 0 then
      begin
        if Selected >= Nmatrices then
        begin
          TargetMatrices.Length := Selected+1;
          for var Matrix := Nmatrices to Selected do TargetMatrices[Matrix] := -1;
          Nmatrices := TargetMatrices.Length;
        end;
        if TargetMatrices[Selected] < 0 then
        begin
          TargetMatrices[Selected] := FCount;
          SetCount(FCount+1);
          SetMatrixLabels(FCount-1,Reader.MatrixLabels[Selected]);
        end else
          raise Exception.Create('Matrix ' + Selected.ToString + ' selected multiple times');
      end else
        raise Exception.Create('Matrix ' + MatrixLabel + ' does not exist');
    end;
    // Set unmasked reader
    Unmasked := Reader;
  end else
    raise Exception.Create('Empty selection');
end;

Procedure TMaskedMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  Rows.TargetMatrices := TargetMatrices;
  try
    Unmasked.Read(CurrentRow,Rows);
    SetCount(Unmasked.Count);
    SetSize(Unmasked.Size);
  finally
    Rows.TargetMatrices := nil;
  end;
end;

Destructor TMaskedMatrixReader.Destroy;
begin
  Unmasked.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Function TMatrixWriter.TMatrixRows.GetValues(Matrix: Integer; Column: Integer): Float64;
begin
  Result := Values[Matrix].Values[Column]
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixWriter.Create(const FileName: String;
                                 const Count,Size: Integer;
                                 const CreateStream: Boolean = true);
begin
  inherited Create;
  FFileName := ExpandFileName(FileName);
  MatrixRows := TMatrixRows.Create;
  MatrixRows.FSize := Size;
  if CreateStream then
  FileStream := TBufferedFileStream.Create(FFileName,fmCreate or fmShareDenyWrite,BufferSize);
  SetCount(Count);
  SetSize(Size);
end;

Procedure TMatrixWriter.Write(const Row: TVirtualMatrixRow);
begin
  MatrixRows.FCount := 1;
  MatrixRows.FSize := FSize;
  SetLength(MatrixRows.Values,1);
  MatrixRows.Values[0] := Row;
  Write(MatrixRows);
end;

Procedure TMatrixWriter.Write(const Row: TFloat64MatrixRow);
begin
  Float64MatrixRows.FCount := 1;
  Float64MatrixRows.FSize := Length(Row);
  SetLength(Float64MatrixRows.FValues,1);
  Float64MatrixRows.FValues[0] := Row;
  Write(Float64MatrixRows);
end;

Procedure TMatrixWriter.Write(const Row: TFloat32MatrixRow);
begin
  Float32MatrixRows.FCount := 1;
  Float32MatrixRows.FSize := Length(Row);
  SetLength(Float32MatrixRows.FValues,1);
  Float32MatrixRows.FValues[0] := Row;
  Write(Float32MatrixRows);
end;

Procedure TMatrixWriter.Write(const Rows: array of TVirtualMatrixRow);
begin
  MatrixRows.FCount := Length(Rows);
  MatrixRows.FSize := Rows[0].FSize;
  SetLength(MatrixRows.Values,Length(Rows));
  for var Matrix := low(Rows) to high(Rows) do
  if Rows[Matrix].FSize = MatrixRows.FSize then
    MatrixRows.Values[Matrix] := Rows[Matrix]
  else
    raise Exception.Create('Matrix rows must have the same size');
  Write(MatrixRows);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat64MatrixRow);
begin
  Float64MatrixRows.FCount := Length(Rows);
  Float64MatrixRows.FSize := Length(Rows[0]);
  SetLength(Float64MatrixRows.FValues,Length(Rows));
  for var Matrix := low(Rows) to high(Rows) do
  if Length(Rows[Matrix]) = Float64MatrixRows.FSize then
    Float64MatrixRows.FValues[Matrix] := Rows[Matrix]
  else
    raise Exception.Create('Matrix rows must have the same size');
  Write(Float64MatrixRows);
end;

Procedure TMatrixWriter.Write(const Rows: array of TFloat32MatrixRow);
begin
  Float32MatrixRows.FCount := Length(Rows);
  Float32MatrixRows.FSize := Length(Rows[0]);
  SetLength(Float32MatrixRows.FValues,Length(Rows));
  for var Matrix := low(Rows) to high(Rows) do
  if Length(Rows[Matrix]) = Float32MatrixRows.FSize then
    Float32MatrixRows.FValues[Matrix] := Rows[Matrix]
  else
    raise Exception.Create('Matrix rows must have the same size');
  Write(Float32MatrixRows);
end;

Procedure TMatrixWriter.Write(const Rows: TVirtualMatrixRows);
begin
  if Assigned(Rows) then
    if CurrentRow < Size then
    begin
      try
        Rows.RoundToZeroThreshold := RoundToZeroThreshold;
        try
          Write(CurrentRow,Rows);
        finally
          Rows.RoundToZeroThreshold := 0.0;
        end;
      except
        on E: Exception do
          raise Exception.Create('Error (' + E.Message + ') writing row ' +
                                 (CurrentRow+1).ToString + ' in ' + FFileName);
      end;
      Inc(CurrentRow);
    end else
      raise Exception.Create('Writing too many rows to matrix file')
  else raise Exception.Create('Rows unassigned');
end;

Procedure TMatrixWriter.Write(const Rows: TMatrixIterator);
begin
  Rows.Index := 0;
  Rows.Iterate;
  if Rows.Index = Rows.FCount then
    write(Rows.Matrices)
  else
    raise Exception.Create('Invalid iteration count');
end;

Destructor TMatrixWriter.Destroy;
begin
  MatrixRows.Free;
  inherited Destroy;
end;

end.
