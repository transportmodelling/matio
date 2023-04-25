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
  System.Classes, System.SysUtils, System.IOUtils, System.Types, PropSet, ArrayVal;

Type
  TFloatType = (ftFloat16,ftFloat32,ftFloat64);

  TFloat32MatrixRow = TArray<Float32>;
  TFloat64MatrixRow = TArray<Float64>;
  TMatrixRow = TFloat64MatrixRow;

  TCustomMatrixRows = Class
  private
    FCount,FSize: Integer;
    RoundToZeroThreshold: Float64;
    Function DoGetValues(Matrix,Column: Integer): Float64; inline;
    Procedure DoSetValues(Matrix,Column: Integer; Value: Float64); inline;
  strict protected
    Procedure Init(Count,Size: Integer);
    Function GetValues(Matrix,Column: Integer): Float64; virtual; abstract;
    Procedure SetValues(Matrix,Column: Integer; Value: Float64); virtual; abstract;
  public
    Procedure GetRow(Matrix: Integer; var Row: TFloat32MatrixRow); overload;
    Procedure GetRow(Matrix: Integer; var Row: TFloat64MatrixRow); overload;
  public
    Property Count: Integer read FCount;
    Property Size: Integer read FSize;
    Property Values[Matrix,Column: Integer]: Float64 read DoGetValues write DoSetValues; default;
    Function Total: Float64; overload;
    Function Total(Matrix: Integer): Float64; overload;
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

  TMatrixFiler = Class
  // TMatrixFiler is the abstract base class for all matrix reader and writer objects
  private
    FFileName: String;
    FCount,FSize,CurrentRow: Integer;
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); virtual;
  strict protected
    Const
      BufferSize: Integer = 4096;
    Var
      FileStream: TBufferedFileStream;
      Float64MatrixRows: TFloat64MatrixRows;
      Float32MatrixRows: TFloat32MatrixRows;
    Procedure SetCount(Count: Integer); virtual;
    Procedure SetSize(Size: Integer);
    Function ExtendProperties(const [ref] Properties: TPropertySet): TPropertySet;
  public
    Const
      FileProperty = 'file';
      FormatProperty = 'format';
    Class Function Format: String; virtual; abstract;
    Class Function Available: Boolean; virtual;
    Class Function FormatProperties(ReadOnly: Boolean = true): TPropertySet;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; virtual;
    Class Function TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
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
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; virtual; abstract;
  public
    Class Function HasFormat(const Header: TBytes): Boolean; virtual;
  public
    Constructor Create(const [ref] Properties: TPropertySet); overload; virtual; abstract;
    Procedure Read(const Row: TFloat64MatrixRow); overload;
    Procedure Read(const Row: TFloat32MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Read(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Read(const Rows: TCustomMatrixRows); overload;
    Function  MatrixLabelsArray: TStringDynArray;
  public
    Property FileLabel: String read FFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels;
  end;

  TMatrixWriter = Class(TMatrixFiler)
  // TMatrixWriter is the abstract base class for all format specific matrix writer objects
  strict protected
    Constructor Create(const FileName: String; const Count,Size: Integer; const CreateStream: Boolean = true); overload;
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; virtual; abstract;
  public
    Class Var
      RoundToZeroThreshold: Float64;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; virtual; abstract;
    Procedure Write(const Row: TFloat64MatrixRow); overload;
    Procedure Write(const Row: TFloat32MatrixRow); overload;
    Procedure Write(const Rows: array of TFloat64MatrixRow); overload;
    Procedure Write(const Rows: array of TFloat32MatrixRow); overload;
    Procedure Write(const Rows: TCustomMatrixRows); overload;
  end;

Const
  PrecisionLabels: array[TFloatType] of String = ('float16','float32','float64');

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCustomMatrixRows.DoGetValues(Matrix,Column: Integer): Float64;
begin
  if (Matrix < FCount) and (Column < FSize) then
  begin
    Result := GetValues(Matrix,Column);
    if Abs(Result) < RoundToZeroThreshold then Result := 0.0
  end else
    Result := 0.0;
end;

Procedure TCustomMatrixRows.DoSetValues(Matrix,Column: Integer; Value: Float64);
begin
  if (Matrix < FCount) and (Column < FSize) then SetValues(Matrix,Column,Value);
end;

Procedure TCustomMatrixRows.Init(Count,Size: Integer);
begin
  FCount := Count;
  FSize := Size;
end;

Procedure TCustomMatrixRows.GetRow(Matrix: Integer; var Row: TFloat32MatrixRow);
begin
  if FSize < Length(Row) then
  begin
    for var Column := 0 to FSize-1 do Row[Column] := DoGetValues(Matrix,Column);
    for var Column := FSize to Length(Row)-1 do Row[Column] := 0.0;
  end else
    for var Column := 0 to Length(Row)-1 do Row[Column] := DoGetValues(Matrix,Column);
end;

Procedure TCustomMatrixRows.GetRow(Matrix: Integer; var Row: TFloat64MatrixRow);
begin
  if FSize < Length(Row) then
  begin
    for var Column := 0 to FSize-1 do Row[Column] := DoGetValues(Matrix,Column);
    for var Column := FSize to Length(Row)-1 do Row[Column] := 0.0;
  end else
    for var Column := 0 to Length(Row)-1 do Row[Column] := DoGetValues(Matrix,Column);
end;

Function TCustomMatrixRows.Total: Float64;
begin
  Result := 0.0;
  for var Matrix := 0 to FCount-1 do Result := Result + Total(Matrix);
end;

Function TCustomMatrixRows.Total(Matrix: Integer): Float64;
begin
  Result := 0.0;
  for var Column := 0 to FSize-1 do Result := Result + GetValues(Matrix,Column);
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

Class Function TMatrixFiler.Available: Boolean;
begin
  Result := true;
end;

Class Function TMatrixFiler.FormatProperties(ReadOnly: Boolean = true): TPropertySet;
begin
  Result := TPropertySet.Create(ReadOnly);
  Result.Append(FileProperty,'');
  Result.Append(FormatProperty,Format);
  AppendFormatProperties(Result);
end;

Class Function TMatrixFiler.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if PropertyName = FormatProperty then
  begin
    Result := true;
    PickList := [Format];
  end else
    Result := false;
end;

Class Function TMatrixFiler.TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
Var
  Value: String;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var Defaults := FormatProperties;
    Result := TPropertySet.Create(ReadOnly);
    for var Prop := 0 to Defaults.Count-1 do
    begin
      var Name := Defaults.Names[Prop];
      if SameText(Name,FileProperty) or SameText(Name,FormatProperty) then
        Result.Append(Name,Properties[Name])
      else
        if Properties.Contains(Name,Value) then
        if not SameText(Defaults.ValueFromIndex[Prop],Value) then
        Result.Append(Name,Value)
    end;
  end else
    raise Exception.Create('Invalid format-property');
end;

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

Class Procedure TMatrixFiler.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
end;

Function TMatrixFiler.ExtendProperties(const [ref] Properties: TPropertySet): TPropertySet;
Var
  Value: String;
begin
  Result := FormatProperties(false);
  for var Prop := 0 to Result.Count-1 do
  begin
    if Properties.Contains(Result.Names[Prop],Value) then
    Result.ValueFromIndex[Prop] := Value;
  end;
end;

Destructor TMatrixFiler.Destroy;
begin
  Float64MatrixRows.Free;
  Float32MatrixRows.Free;
  FileStream.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TMatrixReader.HasFormat(const Header: TBytes): Boolean;
begin
  Result := false;
end;

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

Function TMatrixReader.MatrixLabelsArray: TStringDynArray;
begin
  Result := Copy(FMatrixLabels);
end;

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

Procedure TMatrixWriter.Write(const Rows: TCustomMatrixRows);
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

end.
