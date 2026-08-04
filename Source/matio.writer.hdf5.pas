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
  THdf5MatrixWriter = Class(TMatrixWriter)
  private
    Var
      FPrecision: TFloatType;
      RowSpaceId: Int64;
      MatrixDataSetIds,MatrixDataSpaceIds: array of Int64;
      Row32: TFloat32MatrixRow;
      Row64: TFloat64MatrixRow;
      ChunkSize: array[0..1] of UInt64;
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
Var
  SpaceId,ListId: Int64;
  Dims: array[0..1] of UInt64;
  FillValue32: Float32;
  FillValue64: Float64;
begin
  inherited Create(FileName,Length(MatrixLabels),Size,false);
  Hdf5FileId := Hdf5Dll.H5Fcreate(FileName,Hdf5Dll.H5F_ACC_TRUNC,Hdf5Dll.H5P_DEFAULT,Hdf5Dll.H5P_DEFAULT);
  FPrecision := Precision;
  WriteAttributes(FileLabel,Size);
  SetLength(MatrixDataSetIds,Length(MatrixLabels));
  SetLength(MatrixDataSpaceIds,Length(MatrixLabels));
  // Create folder structure. The group handles must be closed, otherwise the
  // file stays open (and locked) after H5Fclose.
  for var Group in Groups do
  begin
    var GroupId := Hdf5Dll.H5Gcreate2(Hdf5FileId,Group,0,Hdf5Dll.H5P_DEFAULT,0);
    Hdf5Dll.H5Gclose(GroupId);
  end;
  // Create matrices
  Dims[0] := Size;
  Dims[1] := Size;
  ChunkSize[0] := 1;
  ChunkSize[1] := Size;
  FillValue32 := 0.0;
  FillValue64 := 0.0;
  SpaceId := Hdf5Dll.H5Screate_simple(2,@dims[0]);
  RowSpaceId := Hdf5Dll.H5Screate_simple(2,@ChunkSize[0]);
  ListId := Hdf5Dll.H5Pcreate(Hdf5Dll.H5P_CLS_DATASET_CREATE_ID);
  Hdf5Dll.H5Pset_chunk(ListId,2,@ChunkSize[0]);
  Hdf5Dll.H5Pset_deflate(ListId,1);
  for var Matrix := 0 to Count-1 do
  begin
    case FPrecision of
      ftFloat32:
        begin
          SetLength(Row32,Size);
          Hdf5Dll.H5Pset_fill_value(ListId,Hdf5Dll.H5T_NATIVE_FLOAT,@FillValue32);
          MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,MatrixGroup+'/'+MatrixLabels[Matrix],Hdf5Dll.H5T_NATIVE_FLOAT,
                                                         SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
        end;
      ftFloat64:
        begin
          SetLength(Row64,Size);
          Hdf5Dll.H5Pset_fill_value(ListId,Hdf5Dll.H5T_NATIVE_DOUBLE,@FillValue64);
          MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,MatrixGroup+'/'+MatrixLabels[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,
                                                         SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
        end;
    end;
    MatrixDataSpaceIds[Matrix] := Hdf5Dll.H5Dget_space(MatrixDataSetIds[Matrix]);
  end;
  Hdf5Dll.H5Pclose(ListId);
  Hdf5Dll.H5Sclose(SpaceId);
end;

Procedure THdf5MatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
begin
  for var Matrix := 0 to Count-1 do
  begin
    Hdf5Dll.SelectRowHyperslab(MatrixDataSpaceIds[Matrix],CurrentRow,Size);
    case FPrecision of
      ftFloat32:
        begin
          Rows.GetRow(Matrix,Row32);
          Hdf5Dll.H5Dwrite(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_FLOAT,RowSpaceId,
                           MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Row32[0]);
        end;
      ftFloat64:
        begin
          Rows.GetRow(Matrix,Row64);
          Hdf5Dll.H5Dwrite(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,RowSpaceId,
                           MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Row64[0]);
        end;
    end;
  end;
end;

Destructor THdf5MatrixWriter.Destroy;
begin
  if Hdf5Dll <> nil then
  begin
    for var Matrix := 0 to Count-1 do
    begin
      Hdf5Dll.H5Dclose(MatrixDataSetIds[Matrix]);
      Hdf5Dll.H5Sclose(MatrixDataSpaceIds[Matrix]);
    end;
    Hdf5Dll.H5Sclose(RowSpaceId);
  end;
  Hdf5Dll.H5Fclose(Hdf5FileId);
  inherited Destroy;
end;

end.
