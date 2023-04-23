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
  SysUtils, Types, ArrayBld, PropSet, matio, matio.hdf5;

Type
  TOMXPrecision = ftFloat32..ftFloat64;

  TOMXMatrixWriter = Class(THdf5MatrixWriter)
  private
    Const
      PrecisionProperty = 'prec';
      Single: array[0..1] of UInt64 = (1,1);
    Var
      FPrecision: TOMXPrecision;
      RowSpaceId: Int64;
      MatrixDataSetIds,MatrixDataSpaceIds: array of Int64;
      Row32: TFloat32MatrixRow;
      Row64: TFloat64MatrixRow;
      ChunkSize: array[0..1] of UInt64;
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Const
      OMXversion = '0.2';
    Class Function Format: String; override;
    Class Function Available: Boolean; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; override;
    Constructor Create(const FileName,FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const Precision: TOMXPrecision = ftFloat32); overload;
    Destructor Destroy; override;
  public
    Property Precision: TOMXPrecision read FPrecision;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Procedure TOMXMatrixWriter.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,PrecisionLabels[ftFloat32]);
end;

Class Function TOMXMatrixWriter.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,PrecisionProperty) then
  begin
    Result := true;
    PickList := [PrecisionLabels[ftFloat32],PrecisionLabels[ftFloat64]];
  end else
    Result := false;
end;

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
  begin
    Create(Properties.ToPath(FileProperty),FileLabel,MatrixLabels,Size);
    // Set precision
    var ValidPrecision := false;
    var ExtendedProperties := ExtendProperties(Properties);
    var PrecisionPropertyValue := ExtendedProperties[PrecisionProperty];
    for var Prec := low(TOMXPrecision) to high(TOMXPrecision) do
    if SameText(PrecisionLabels[Prec],PrecisionPropertyValue) then
    begin
      FPrecision := Prec;
      ValidPrecision := true;
      Break;
    end;
    if not ValidPrecision then raise Exception.Create('Invalid precision');
  end else
    raise Exception.Create('Invalid format-property');
end;

Constructor TOMXMatrixWriter.Create(const FileName,FileLabel: string;
                                    const MatrixLabels: array of String;
                                    const Size: Integer;
                                    const Precision: TOMXPrecision = ftFloat32);
Var
  SpaceId,ListId: Int64;
  Dims: array[0..1] of UInt64;
  FillValue32: Float32;
  FillValue64: Float64;
begin
  inherited Create(FileName,FileLabel,MatrixLabels,Size);
  FPrecision := Precision;
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
          MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,'/data/'+MatrixLabels[Matrix],Hdf5Dll.H5T_NATIVE_FLOAT,
                                                         SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
        end;
      ftFloat64:
        begin
          SetLength(Row64,Size);
          Hdf5Dll.H5Pset_fill_value(ListId,Hdf5Dll.H5T_NATIVE_DOUBLE,@FillValue64);
          MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dcreate2(Hdf5FileId,'/data/'+MatrixLabels[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,
                                                         SpaceId,Hdf5Dll.H5P_DEFAULT,ListId,Hdf5Dll.H5P_DEFAULT);
        end;
    end;
    MatrixDataSpaceIds[Matrix] := Hdf5Dll.H5Dget_space(MatrixDataSetIds[Matrix]);
  end;
  Hdf5Dll.H5Pclose(ListId);
  Hdf5Dll.H5Sclose(SpaceId);
end;

Procedure TOMXMatrixWriter.Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  Offset: array[0..1] of UInt64;
begin
  Offset[0] := CurrentRow;
  Offset[1] := 0;
  for var Matrix := 0 to Count-1 do
  begin
    Hdf5Dll.H5Sselect_hyperslab(MatrixDataSpaceIds[Matrix],Hdf5Dll.H5S_SELECT_SET,Offset,Single,ChunkSize,Single);
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
