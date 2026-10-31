unit matio.writer.hdf5;

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
  SysUtils, Types, ArrBld, matio, matio.writer, matio.hdf5;

Type
  THdf5MatrixWriterClass = Class of THdf5MatrixWriter;

  THdf5MatrixWriter = Class(TMatrixWriter)
  private
    Var
      FPrecision: TFloatType;
      RowSpaceId: Int64;
      MatrixDataSetIds,MatrixDataSpaceIds: array of Int64;
      Row32: TFloat32MatrixRow;
      Row64: TFloat64MatrixRow;
      ChunkSize: array[0..1] of UInt64;
    Procedure AllocateMatrices(const NMatrices: Integer);
    Procedure CreateGroups;
    Function MatrixType: Int64;
    Function NewMatrixSpace: Int64;
    Function NewMatrixProperties: Int64;
    Procedure CreateMatrices(const MatrixLabels: array of String);
    Procedure WriteFloat32Row(const Matrix: Integer; const Rows: TVirtualMatrixRows);
    Procedure WriteFloat64Row(const Matrix: Integer; const Rows: TVirtualMatrixRows);
  strict protected
    Hdf5FileId: Int64;
    Function Groups: TArray<ANSIString>; virtual; abstract;
    Function MatrixGroup: ANSIString; virtual; abstract;
    Procedure WriteAttributes(const FileLabel: ANSIString; Size: Integer); virtual; abstract;
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); override;
  public
    Class Function Available: Boolean;
  public
    Constructor Create(const FileName,FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const Precision: THdf5Precision = ftFloat32); overload;
    Destructor Destroy; override;
  public
    Property Precision: TFloatType read FPrecision;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function THdf5MatrixWriter.Available: Boolean;
begin
  Result := Assigned(Hdf5Dll);
end;

Constructor THdf5MatrixWriter.Create(const FileName,FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer;
                                     const Precision: THdf5Precision = ftFloat32);
begin
  inherited Create(FileName,Length(MatrixLabels),Size,false);
  Hdf5FileId := Hdf5Dll.H5Fcreate(FileName,Hdf5Dll.H5F_ACC_TRUNC,Hdf5Dll.H5P_DEFAULT,Hdf5Dll.H5P_DEFAULT);
  FPrecision := Precision;
  WriteAttributes(FileLabel,Size);
  AllocateMatrices(Length(MatrixLabels));
  CreateGroups;
  CreateMatrices(MatrixLabels);
end;

Procedure THdf5MatrixWriter.AllocateMatrices(const NMatrices: Integer);
begin
  SetLength(MatrixDataSetIds,NMatrices);
  SetLength(MatrixDataSpaceIds,NMatrices);
  SetLength(Row32,Size);
  SetLength(Row64,Size);
  ChunkSize[0] := 1;
  ChunkSize[1] := Size;
end;

Procedure THdf5MatrixWriter.CreateGroups;
// Creates the folder structure. The group handles must be closed, otherwise the
// file stays open (and locked) after H5Fclose.
begin
  var GroupNames := Groups;
  for var Group := low(GroupNames) to high(GroupNames) do
  begin
    var GroupId := Hdf5Dll.H5Gcreate2(Hdf5FileId,GroupNames[Group],0,Hdf5Dll.H5P_DEFAULT,0);
    Hdf5Dll.H5Gclose(GroupId);
  end;
end;

Function THdf5MatrixWriter.MatrixType: Int64;
begin
  if FPrecision = ftFloat32 then Result := Hdf5Dll.H5T_NATIVE_FLOAT else Result := Hdf5Dll.H5T_NATIVE_DOUBLE;
end;

Function THdf5MatrixWriter.NewMatrixSpace: Int64;
Var
  Dims: array[0..1] of UInt64;
begin
  Dims[0] := Size;
  Dims[1] := Size;
  Result := Hdf5Dll.H5Screate_simple(2,@dims[0]);
end;

Function THdf5MatrixWriter.NewMatrixProperties: Int64;
Var
  FillValue32: Float32;
  FillValue64: Float64;
begin
  FillValue32 := 0.0;
  FillValue64 := 0.0;
  Result := Hdf5Dll.H5Pcreate(Hdf5Dll.H5P_CLS_DATASET_CREATE_ID);
  Hdf5Dll.H5Pset_chunk(Result,2,@ChunkSize[0]);
  Hdf5Dll.H5Pset_deflate(Result,1);
  case FPrecision of
    ftFloat32: Hdf5Dll.H5Pset_fill_value(Result,MatrixType,@FillValue32);
    ftFloat64: Hdf5Dll.H5Pset_fill_value(Result,MatrixType,@FillValue64);
  end;
end;

Procedure THdf5MatrixWriter.CreateMatrices(const MatrixLabels: array of String);
begin
  var SpaceId := NewMatrixSpace;
  RowSpaceId := Hdf5Dll.H5Screate_simple(2,@ChunkSize[0]);
  var ListId := NewMatrixProperties;
  for var Matrix := 0 to Count-1 do
  begin
    MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,MatrixGroup+'/'+MatrixLabels[Matrix],MatrixType,
                                                   SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
    MatrixDataSpaceIds[Matrix] := Hdf5Dll.H5Dget_space(MatrixDataSetIds[Matrix]);
  end;
  Hdf5Dll.H5Pclose(ListId);
  Hdf5Dll.H5Sclose(SpaceId);
end;

Procedure THdf5MatrixWriter.WriteFloat32Row(const Matrix: Integer; const Rows: TVirtualMatrixRows);
begin
  Rows.GetRow(Matrix,Row32);
  Hdf5Dll.H5Dwrite(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_FLOAT,RowSpaceId,
                   MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Row32[0]);
end;

Procedure THdf5MatrixWriter.WriteFloat64Row(const Matrix: Integer; const Rows: TVirtualMatrixRows);
begin
  Rows.GetRow(Matrix,Row64);
  Hdf5Dll.H5Dwrite(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,RowSpaceId,
                   MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Row64[0]);
end;

Procedure THdf5MatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
begin
  for var Matrix := 0 to Count-1 do
  begin
    Hdf5Dll.SelectRowHyperslab(MatrixDataSpaceIds[Matrix],CurrentRow,Size);
    case FPrecision of
      ftFloat32: WriteFloat32Row(Matrix,Rows);
      ftFloat64: WriteFloat64Row(Matrix,Rows);
    end;
  end;
end;

Destructor THdf5MatrixWriter.Destroy;
begin
  if Hdf5Dll <> nil then Hdf5Dll.CloseMatrices(Hdf5FileId,RowSpaceId,MatrixDataSetIds,MatrixDataSpaceIds);
  inherited Destroy;
end;

end.
