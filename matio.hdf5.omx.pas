unit matio.hdf5.omx;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/matio
//
// Open matrix format: https://github.com/osPlanning/omx
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, PropSet, matio, matio.hdf5;

Type
  TOMXMatrixWriter = Class(THdf5MatrixWriter)
  private
    RowSpaceId: Int64;
    MatrixDataSetIds,MatrixDataSpaceIds: array of Int64;
    Row: TFloat64MatrixRow;
    ChunkSize: array[0..1] of UInt64;
  strict protected
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Const
      OMXversion = '0.2';
    Class Function Format: String; override;
    Class Function Available: Boolean; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; override;
    Constructor Create(const FileName,FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function TOMXMatrixWriter.Format: String;
begin
  Result := 'omx';
end;

Class Function TOMXMatrixWriter.Available: Boolean;
begin
  Result := FileExists(THdf5Dll.Path);
end;

Constructor TOMXMatrixWriter.Create(const [ref] Properties: TPropertySet;
                                    const FileLabel: string;
                                    const MatrixLabels: array of String;
                                    const Size: Integer);
begin
  if SameText(Properties[FormatProperty],Format) then
    Create(Properties.ToPath(FileProperty),FileLabel,MatrixLabels,Size)
  else
    raise Exception.Create('Invalid format-property');
end;

Constructor TOMXMatrixWriter.Create(const FileName,FileLabel: string;
                                    const MatrixLabels: array of String;
                                    const Size: Integer);
Var
  SpaceId,ListId: Int64;
  Dims: array[0..1] of UInt64;
  FillValue: Float64;
begin
  inherited Create(FileName,FileLabel,MatrixLabels,Size);
  SetLength(Row,Size);
  SetLength(MatrixDataSetIds,Length(MatrixLabels));
  SetLength(MatrixDataSpaceIds,Length(MatrixLabels));
  // Write file attributes
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','LABEL',FileLabel);
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','OMX_VERSION',OMXversion);
  Hdf5Dll.CreateIntArrayAttribute(Hdf5FileId,'/','SHAPE',[Size,Size]);
  // Save creation order
  var plist := Hdf5Dll.H5Pcreate (Hdf5Dll.H5P_CLS_GROUP_CREATE_ID);
  Hdf5Dll.H5Pset_link_creation_order(plist,Hdf5Dll.H5P_CRT_ORDER_TRACKED);
  // Create folder structure
  Hdf5Dll.H5Gcreate2(Hdf5FileId,'/data',0,plist,0);
  Hdf5Dll.H5Pclose(plist);
  // Create matrices
  Dims[0] := Size;
  Dims[1] := Size;
  ChunkSize[0] := 1;
  ChunkSize[1] := Size;
  FillValue := 0.0;
  SpaceId := Hdf5Dll.H5Screate_simple(2,@dims[0]);
  RowSpaceId := Hdf5Dll.H5Screate_simple(2,@ChunkSize[0]);
  ListId := Hdf5Dll.H5Pcreate(Hdf5Dll.H5P_CLS_DATASET_CREATE_ID);
  Hdf5Dll.H5Pset_chunk(ListId,2,@ChunkSize[0]);
  Hdf5Dll.H5Pset_deflate(ListId,1);
  Hdf5Dll.H5Pset_fill_value(ListId,Hdf5Dll.H5T_NATIVE_DOUBLE,@FillValue);
  for var Matrix := 0 to Count-1 do
  begin
    MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,'/data/'+MatrixLabels[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,
                                                   SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
    MatrixDataSpaceIds[Matrix] := Hdf5Dll.H5Dget_space(MatrixDataSetIds[Matrix]);
  end;
  Hdf5Dll.H5Pclose(ListId);
  Hdf5Dll.H5Sclose(SpaceId);
end;

Procedure TOMXMatrixWriter.Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  Offset,Single: array[0..1] of UInt64;
begin
  Offset[0] := CurrentRow;
  Offset[1] := 0;
  Single[0] := 1;
  Single[1] := 1;
  for var Matrix := 0 to Count-1 do
  begin
    Rows.GetRow(Matrix,Row);
    Hdf5Dll.H5Sselect_hyperslab(MatrixDataSpaceIds[Matrix],Hdf5Dll.H5S_SELECT_SET,Offset,Single,ChunkSize,Single);
    Hdf5Dll.H5Dwrite(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,RowSpaceId,MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Row[0]);
  end;
end;

Destructor TOMXMatrixWriter.Destroy;
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
  inherited Destroy;
end;

end.
