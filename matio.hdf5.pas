unit matio.hdf5;

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
  SysUtils, Windows, matio;

Type
  THdf5Dll = Class
  private
    DllHandle: THandle;
    FH5P_CLS_GROUP_CREATE_ID,FH5P_CLS_DATASET_CREATE_ID,
    FH5T_C_S1,FH5T_NATIVE_INT,FH5T_NATIVE_FLOAT,FH5T_NATIVE_DOUBLE: Int64;
    FH5open: Function: Integer; cdecl;
    FH5Fcreate: Function(FileName: PAnsiChar; Flags: UInt32; fcpl_id: Int64; fapl_id : Int64): Int64; cdecl;
    FH5Fopen: Function(filename: PAnsiChar; flags: UInt32; access_plist: Int64): Int64; cdecl;
    FH5Oopen: Function(FileId: Int64; Name: PAnsiChar; lapl_id: Int64): Int64; cdecl;
    FH5Tcopy:  Function(TypeId: Int64): Int64; cdecl;
    FH5Tget_class: Function(type_id: Int64): Integer; cdecl;
    FH5Tget_size: Function(type_id: Int64): UInt64; cdecl;
    FH5Tset_size: Function(TypeId: Int64; Size: UInt32): Integer; cdecl;
    FH5Tset_strpad: Function(TypeId: Int64; StrType: Integer): Integer; cdecl;
    FH5Screate: Function(ClassType: Integer): Int64; cdecl;
    FH5Screate_simple: Function(Rank: Integer; Dims: PUInt64; MaxDims: PUInt64): Int64; cdecl;
    FH5Sselect_hyperslab: Function(SpaceId: Int64; op: Integer; start: PUInt64; _stride: PUInt64;
                                   count: PUInt64; _block: PUInt64): Integer; cdecl;
    FH5Sget_select_bounds: Function(spaceid: Int64; start: Pointer; end_: Pointer): Integer; cdecl;
    FH5Acreate2: Function(ObjId: Int64; AttributeName: PAnsiChar; TypeId: Int64;
                          SpaceId: Int64; acpl_id: Int64; aapl_id: Int64): Int64; cdecl;
    FH5Aopen_by_name: Function(ObjId: Int64; obj_name: PAnsiChar; attr_name: PAnsiChar; aapl_id: Int64; lapl_id: Int64): Int64; cdecl;
    FH5Aget_type: Function(attr_id: Int64): Int64; cdecl;
    FH5Aget_space: Function(attr_id: Int64): Int64; cdecl;
    FH5Aget_storage_size: Function(attr_id: Int64): UInt64; cdecl;
    FH5Aread: Function(attr_id: Int64; type_id: Int64; Buf: Pointer): Integer; cdecl;
    FH5Pcreate: Function(cls_id: Int64): Int64; cdecl;
    FH5Pset_link_creation_order: Function(plist_id: Int64; crt_order_flags: UInt32): Integer; cdecl;
    FH5Pset_chunk: Function(plist_id: Int64; ndims: Integer; dim: PUInt64): Integer; cdecl;
    FH5Pset_deflate: Function(plist_id: Int64; aggression: UInt32): Integer; cdecl;
    FH5Pset_fill_value: Function(plist_id: Int64; type_id: Int64; value: Pointer): Integer; cdecl;
    FH5Gcreate2: Function(loc_id: Int64; Name: PAnsiChar; lcpl_id: Int64; gcpl_id: Int64; gapl_id: Int64): Int64; cdecl;
    FH5Awrite: Function(AttributeId: Int64; TypeId: Int64; Buf: Pointer): Integer; cdecl;
    FH5Dcreate2: Function(loc_id: Int64; name: PAnsiChar; type_id: Int64; space_id: Int64;
                          lcpl_id: Int64; dcpl_id: Int64; dapl_id: Int64): Int64; cdecl;
    FH5Dopen2: Function(file_id: Int64; name: PAnsiChar; dapl_id: Int64): Int64; cdecl;
    FH5Dget_type: Function(dset_id: Int64): Int64; cdecl;
    FH5Dget_space: Function(dset_id: Int64): Int64; cdecl;
    FH5Dread: Function(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64; file_space_id: Int64; plist_id: Int64; buf: Pointer): Integer; cdecl;
    FH5Dwrite: Function(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64;
                        file_space_id: Int64; plist_id: Int64; buf: Pointer): Integer; cdecl;
    FH5Dclose: Function(dset_id: Int64): Integer; cdecl;
    FH5Aclose: Function(AttributeId: Int64): Integer; cdecl;
    FH5Sclose: Function(SpaceId: Int64): Integer; cdecl;
    FH5Tclose: Function(TypeId: Int64): Integer; cdecl;
    FH5Oclose: Function(ObjectId: Int64): Integer; cdecl;
    FH5Pclose: Function(Listid: Int64): Integer; cdecl;
    FH5Fclose: Function(FileId: Int64): Integer; cdecl;
    FH5close: Function: Integer; cdecl;
    Function GetDllMethod(MethodName: String): Pointer;
  public
    Constructor Create(const DllPath: string);
    // Dll methods
    Procedure H5open;
    Function H5Fcreate(FileName: AnsiString; Flags: UInt32; fcpl_id: Int64; fapl_id : Int64): Int64;
    Function H5Fopen(FileName: AnsiString; flags: UInt32; access_plist: Int64): Int64;
    Function H5Oopen(FileId: Int64; Name: AnsiString; lapl_id: Int64): Int64;
    Function H5Tcopy(TypeId: Int64): Int64;
    Function H5Tget_class(type_id: Int64): Integer;
    Function H5Tget_size(type_id: Int64): UInt64;
    Procedure H5Tset_size(TypeId: Int64; Size: UInt32);
    Procedure H5Tset_strpad(TypeId: Int64; StrType: Integer);
    Function H5Screate(ClassType: Integer): Int64;
    Function H5Screate_simple(Rank: Integer; Dims: PUInt64): Int64;
    Procedure H5Sselect_hyperslab(SpaceId: Int64; op: Integer; const start,stride,count,block);
    Function H5Acreate2(FileId: Int64; AttributeName: AnsiString; TypeId: Int64;
                        SpaceId: Int64; acpl_id: Int64; aapl_id: Int64): Int64;
    Function H5Aopen_by_name(ObjId: Int64; obj_name,attr_name: AnsiString; aapl_id: Int64; lapl_id: Int64): Int64;
    Function H5Aget_type(attr_id: Int64): Int64;
    Function H5Aget_space(attr_id: Int64): Int64;
    Function H5Aget_storage_size(attr_id: Int64): UInt64;
    Procedure H5Aread(attr_id: Int64; type_id: Int64; Buf: Pointer);
    Function H5Pcreate(cls_id: Int64): Int64;
    Procedure H5Pset_link_creation_order(plist_id: Int64; crt_order_flags: UInt32);
    Procedure H5Pset_chunk(plist_id: Int64; ndims: Integer; dim: PUInt64);
    Procedure H5Pset_deflate(plist_id: Int64; aggression: UInt32);
    Procedure H5Pset_fill_value(plist_id: Int64; type_id: Int64; value: Pointer);
    Function H5Gcreate2(loc_id: Int64; Name: AnsiString; lcpl_id: Int64; gcpl_id: Int64; gapl_id: Int64): Int64;
    Procedure H5Awrite(AttributeId: Int64; TypeId: Int64; Buf: Pointer);
    Function H5Dcreate2(loc_id: Int64; name: AnsiString; type_id: Int64; space_id: Int64;
                        lcpl_id: Int64; dcpl_id: Int64; dapl_id: Int64): Int64;
    Function H5Dopen2(file_id: Int64; name: AnsiString; dapl_id: Int64): Int64;
    Function H5Dget_type(dset_id: Int64): Int64;
    Function H5Dget_space(dset_id: Int64): Int64;
    Procedure H5Dread(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64;
                     file_space_id: Int64; plist_id: Int64; buf: Pointer);
    Procedure H5Dwrite(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64;
                       file_space_id: Int64; plist_id: Int64; buf: Pointer);
    Procedure H5Dclose(dset_id: Int64);
    Procedure H5Aclose(AttributeId: Int64);
    Procedure H5Sclose(SpaceId: Int64);
    Procedure H5Tclose(TypeId: Int64);
    Procedure H5Oclose(ObjectId: Int64);
    Procedure H5Pclose(ListId: Int64);
    Procedure H5Fclose(FileId: Int64);
    Procedure H5close;
    // Hdf5 utilities
    Procedure CreateStringAttribute(ObjId: Int64; ObjectName,AttributeName,AttributeValue: AnsiString);
    Procedure CreateIntArrayAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; const ArrayData: array of Integer);
    Procedure ReadStringAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; var AttributeValue: AnsiString);
    Procedure ReadIntArrayAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; var ArrayData: array of Integer);
    Destructor Destroy; override;
  public
    Const
      H5P_DEFAULT = 0;
      H5F_ACC_RDONLY = 0;
      H5F_ACC_TRUNC = 2;
      H5P_CRT_ORDER_TRACKED = 1;
      H5S_SELECT_SET = 0;
      H5T_STR_NULLTERM = 0;
      H5S_SCALAR = 0;
      H5T_FLOAT = 1;
    Property H5T_C_S1: Int64 read FH5T_C_S1;
    Property H5P_CLS_GROUP_CREATE_ID: Int64 read FH5P_CLS_GROUP_CREATE_ID;
    Property H5P_CLS_DATASET_CREATE_ID: Int64 read FH5P_CLS_DATASET_CREATE_ID;
    Property H5T_NATIVE_INT: Int64 read FH5T_NATIVE_INT;
    Property H5T_NATIVE_FLOAT: Int64 read FH5T_NATIVE_FLOAT;
    Property H5T_NATIVE_DOUBLE: Int64 read FH5T_NATIVE_DOUBLE;
  end;

  THdf5MatrixReader = Class(TMatrixReader)
  protected
    Hdf5FileId: Int64;
    Constructor Create(const FileName: string); overload;
  public
    Class Function Available: Boolean;
  public
    Destructor Destroy; override;
  end;

  THdf5MatrixWriter = Class(TMatrixWriter)
  protected
    Hdf5FileId: Int64;
    Constructor Create(const FileName,FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload;
  public
    Class Function Available: Boolean;
  public
    Destructor Destroy; override;
  end;

Var
  Hdf5Dll: THdf5Dll = nil;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor THdf5Dll.Create(const DllPath: string);
begin
  inherited Create;
  DllHandle := SafeLoadLibrary(DllPath);
  if DllHandle <> 0 then
  begin
    // Load Hdf5 dll
    FH5open := GetDllMethod('H5open');
    FH5Fcreate := GetDllMethod('H5Fcreate');
    FH5Fopen := GetDllMethod('H5Fopen');
    FH5Oopen := GetDllMethod('H5Oopen');
    FH5Tcopy := GetDllMethod('H5Tcopy');
    FH5Tget_class := GetDllMethod('H5Tget_class');
    FH5Tget_size := GetDllMethod('H5Tget_size');
    FH5Tset_size := GetDllMethod('H5Tset_size');
    FH5Tset_strpad := GetDllMethod('H5Tset_strpad');
    FH5Screate := GetDllMethod('H5Screate');
    FH5Screate_simple := GetDllMethod('H5Screate_simple');
    FH5Sselect_hyperslab := GetDllMethod('H5Sselect_hyperslab');
    FH5Sget_select_bounds := GetDllMethod('H5Sget_select_bounds');
    FH5Acreate2 := GetDllMethod('H5Acreate2');
    FH5Aopen_by_name := GetDllMethod('H5Aopen_by_name');
    FH5Aget_type := GetDllMethod('H5Aget_type');
    FH5Aget_space := GetDllMethod('H5Aget_space');
    FH5Aget_storage_size := GetDllMethod('H5Aget_storage_size');
    FH5Aread := GetDllMethod('H5Aread');
    FH5Pcreate := GetDllMethod('H5Pcreate');
    FH5Pset_link_creation_order := GetDllMethod('H5Pset_link_creation_order');
    FH5Pset_chunk := GetDllMethod('H5Pset_chunk');
    FH5Pset_deflate := GetDllMethod('H5Pset_deflate');
    FH5Pset_fill_value := GetDllMethod('H5Pset_fill_value');
    FH5Gcreate2 := GetDllMethod('H5Gcreate2');
    FH5Awrite := GetDllMethod('H5Awrite');
    FH5Dcreate2 := GetDllMethod('H5Dcreate2');
    FH5Dopen2 := GetDllMethod('H5Dopen2');
    FH5Dget_type := GetDllMethod('H5Dget_type');
    FH5Dget_space := GetDllMethod('H5Dget_space');
    FH5Dread := GetDllMethod('H5Dread');
    FH5Dwrite := GetDllMethod('H5Dwrite');
    FH5Dclose := GetDllMethod('H5Dclose');
    FH5Aclose:= GetDllMethod('H5Aclose');
    FH5Sclose := GetDllMethod('H5Sclose');
    FH5Tclose := GetDllMethod('H5Tclose');
    FH5Oclose := GetDllMethod('H5Oclose');
    FH5Fclose := GetDllMethod('H5Fclose');
    FH5Pclose := GetDllMethod('H5Pclose');
    FH5close := GetDllMethod('H5close');
    // Set constants
    H5open;
    FH5T_C_S1 := PInt64(GetDllMethod('H5T_C_S1_g'))^;
    if FH5T_C_S1 < 0 then raise Exception.Create('Error getting H5T_C_S1');
    FH5P_CLS_GROUP_CREATE_ID := PInt64(GetDllMethod('H5P_CLS_GROUP_CREATE_ID_g'))^;
    if FH5P_CLS_GROUP_CREATE_ID < 0 then raise Exception.Create('Error getting H5P_CLS_GROUP_CREATE_ID');
    FH5P_CLS_DATASET_CREATE_ID := PInt64(GetDllMethod('H5P_CLS_DATASET_CREATE_ID_g'))^;
    if FH5P_CLS_DATASET_CREATE_ID < 0 then raise Exception.Create('Error getting H5P_CLS_DATASET_CREATE_ID');
    FH5T_NATIVE_INT := PInt64(GetDllMethod('H5T_NATIVE_INT_g'))^;
    if FH5T_NATIVE_INT < 0 then raise Exception.Create('Error getting H5T_NATIVE_INT');
    FH5T_NATIVE_FLOAT := PInt64(GetDllMethod('H5T_NATIVE_FLOAT_g'))^;
    if FH5T_NATIVE_FLOAT < 0 then raise Exception.Create('Error getting H5T_NATIVE_FLOAT');
    FH5T_NATIVE_DOUBLE := PInt64(GetDllMethod('H5T_NATIVE_DOUBLE_g'))^;
    if FH5T_NATIVE_DOUBLE < 0 then raise Exception.Create('Error getting H5T_NATIVE_DOUBLE');
  end else
    raise Exception.Create('Cannot load hdf5-dll');
end;

Function THdf5Dll.GetDllMethod(MethodName: String): Pointer;
begin
  Result := GetProcAddress(DllHandle,PChar(MethodName));
  if Result = nil then raise Exception.Create('Cannot load dll method ' + MethodName);
end;

Procedure THdf5Dll.H5open;
begin
  if FH5Open < 0 then raise Exception.Create('Error calling H5open')
end;

Function THdf5Dll.H5Fcreate(FileName: AnsiString; Flags: UInt32; fcpl_id: Int64; fapl_id : Int64): Int64;
begin
  Result := FH5Fcreate(PAnsiChar(FileName),Flags,fcpl_id,fapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Fcreate')
end;

Function THdf5Dll.H5Fopen(FileName: AnsiString; flags: UInt32; access_plist: Int64): Int64;
begin
  Result := FH5Fopen(PAnsiChar(FileName),flags,access_plist);
  if Result < 0 then raise Exception.Create('Error calling H5Fopen')
end;

Function THdf5Dll.H5Oopen(FileId: Int64; Name: AnsiString; lapl_id: Int64): Int64;
begin
  Result := FH5Oopen(FileId,PAnsiChar(Name),lapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Oopen')
end;

Function THdf5Dll.H5Tcopy(TypeId: Int64): Int64;
begin
  Result := FH5Tcopy(TypeId);
  if Result < 0 then raise Exception.Create('Error calling H5Tcopy')
end;

Function THdf5Dll.H5Tget_class(type_id: Int64): Integer;
begin
  Result := FH5Tget_class(type_id);
  if Result < 0 then raise Exception.Create('Error calling H5Tget_class')
end;

Function THdf5Dll.H5Tget_size(type_id: Int64): UInt64;
begin
  Result := FH5Tget_size(type_id);
  if Result < 0 then raise Exception.Create('Error calling H5Tget_size')
end;

Procedure THdf5Dll.H5Tset_size(TypeId: Int64; Size: UInt32);
begin
  if FH5Tset_size(TypeId,Size) < 0 then raise Exception.Create('Error calling H5Tset_size')
end;

Procedure THdf5Dll.H5Tset_strpad(TypeId: Int64; StrType: Integer);
begin
  if FH5Tset_strpad(TypeId,StrType) < 0 then raise Exception.Create('Error calling H5Tset_strpad')
end;

Function THdf5Dll.H5Screate(ClassType: Integer): Int64;
begin
  Result := FH5Screate(ClassType);
  if Result < 0 then raise Exception.Create('Error calling H5Screate')
end;

Function THdf5Dll.H5Screate_simple(Rank: Integer; Dims: PUInt64): Int64;
begin
  Result := FH5Screate_simple(Rank,Dims,nil);
  if Result < 0 then raise Exception.Create('Error calling H5Screate_simple')
end;

Procedure THdf5Dll.H5Sselect_hyperslab(SpaceId: Int64; op: Integer; const start,stride,count,block);
begin
  if FH5Sselect_hyperslab(SpaceId,op,@start,@stride,@count,@block) < 0 then
    raise Exception.Create('Error calling H5Sselect_hyperslab')
end;

Function THdf5Dll.H5Acreate2(FileId: Int64; AttributeName: AnsiString; TypeId: Int64;
                             SpaceId: Int64; acpl_id: Int64; aapl_id: Int64): Int64;
begin
  Result := FH5Acreate2(FileId,PAnsiChar(AttributeName),TypeId,SpaceId,acpl_id,aapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Acreate2')
end;

Function THdf5Dll.H5Aopen_by_name(ObjId: Int64; obj_name,attr_name: AnsiString; aapl_id: Int64; lapl_id: Int64): Int64;
begin
  Result := FH5Aopen_by_name(ObjId,PAnsiChar(obj_name),PAnsiChar(attr_name),aapl_id,lapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Aopen_by_name')
end;

Function THdf5Dll.H5Aget_type(attr_id: Int64): Int64;
begin
  Result := FH5Aget_type(attr_id);
  if Result < 0 then raise Exception.Create('Error calling H5Aget_type')
end;

Function THdf5Dll.H5Aget_space(attr_id: Int64): Int64;
begin
  Result := FH5Aget_space(attr_id);
  if Result < 0 then raise Exception.Create('Error calling H5Aget_space')
end;

Function THdf5Dll.H5Aget_storage_size(attr_id: Int64): UInt64;
begin
  Result := FH5Aget_storage_size(attr_id);
end;

Procedure THdf5Dll.H5Aread(attr_id: Int64; type_id: Int64; Buf: Pointer);
begin
  if FH5Aread(attr_id,type_id,Buf) < 0 then
    raise Exception.Create('Error calling H5Aread')
end;

Function THdf5Dll.H5Pcreate(cls_id: Int64): Int64;
begin
  Result := FH5Pcreate(cls_id);
  if Result < 0 then raise Exception.Create('Error calling H5Pcreate')
end;

Procedure THdf5Dll.H5Pset_link_creation_order(plist_id: Int64; crt_order_flags: UInt32);
begin
  if FH5Pset_link_creation_order(plist_id,crt_order_flags) < 0 then
    raise Exception.Create('Error calling H5Pset_link_creation_order')
end;

Procedure THdf5Dll.H5Pset_chunk(plist_id: Int64; ndims: Integer; dim: PUInt64);
begin
  if FH5Pset_chunk(plist_id,ndims,dim) < 0 then raise Exception.Create('Error calling H5Pset_chunk')
end;

Procedure THdf5Dll.H5Pset_deflate(plist_id: Int64; aggression: UInt32);
begin
  if FH5Pset_deflate(plist_id,aggression) < 0 then raise Exception.Create('Error calling H5Pset_deflate')
end;

Procedure THdf5Dll.H5Pset_fill_value(plist_id: Int64; type_id: Int64; value: Pointer);
begin
  if FH5Pset_fill_value(plist_id,type_id,value) < 0 then raise Exception.Create('Error calling H5Pset_fill_value')
end;

Function THdf5Dll.H5Gcreate2(loc_id: Int64; Name: AnsiString; lcpl_id: Int64; gcpl_id: Int64; gapl_id: Int64): Int64;
begin
  Result := FH5Gcreate2(loc_id,PAnsiChar(Name),lcpl_id,gcpl_id,gapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Gcreate2')
end;

Procedure THdf5Dll.H5Awrite(AttributeId: Int64; TypeId: Int64; Buf: Pointer);
begin
  if FH5Awrite(AttributeId,TypeId,Buf) < 0 then raise Exception.Create('Error calling H5Awrite')
end;

Function THdf5Dll.H5Dcreate2(loc_id: Int64; name: AnsiString; type_id: Int64; space_id: Int64;
                             lcpl_id: Int64; dcpl_id: Int64; dapl_id: Int64): Int64;
begin
  Result := FH5Dcreate2(loc_id,PAnsiChar(name),type_id,space_id,lcpl_id,dcpl_id,dapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Dcreate2')
end;

Function THdf5Dll.H5Dopen2(file_id: Int64; name: Ansistring; dapl_id: Int64): Int64;
begin
  Result := FH5Dopen2(file_id,PAnsiChar(name),dapl_id);
  if Result < 0 then raise Exception.Create('Error calling H5Dopen2')
end;

Function THdf5Dll.H5Dget_type(dset_id: Int64): Int64;
begin
  Result := FH5Dget_type(dset_id);
  if Result < 0 then raise Exception.Create('Error calling H5Dget_type')
end;

Function THdf5Dll.H5Dget_space(dset_id: Int64): Int64;
begin
  Result := FH5Dget_space(dset_id);
  if Result < 0 then raise Exception.Create('Error calling H5Dget_space')
end;

Procedure THdf5Dll.H5Dread(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64;
                           file_space_id: Int64; plist_id: Int64; buf: Pointer);
begin
  if FH5Dread(dset_id,mem_type_id,mem_space_id,file_space_id,plist_id,buf) < 0 then
    raise Exception.Create('Error calling H5Dread')
end;

Procedure THdf5Dll.H5Dwrite(dset_id: Int64; mem_type_id: Int64; mem_space_id: Int64;
                            file_space_id: Int64; plist_id: Int64; buf: Pointer);
begin
  if FH5Dwrite(dset_id,mem_type_id,mem_space_id,file_space_id,plist_id,buf) < 0 then
    raise Exception.Create('Error calling H5Dwrite')
end;

Procedure THdf5Dll.H5Dclose(dset_id: Int64);
begin
  if FH5Dclose(dset_id) < 0 then raise Exception.Create('Error calling H5Dclose')
end;

Procedure THdf5Dll.H5Aclose(AttributeId: Int64);
begin
  if FH5Aclose(AttributeId) < 0 then raise Exception.Create('Error calling H5Aclose')
end;

Procedure THdf5Dll.H5Sclose(SpaceId: Int64);
begin
  if FH5Sclose(SpaceId) < 0 then raise Exception.Create('Error calling H5Sclose')
end;

Procedure THdf5Dll.H5Tclose(TypeId: Int64);
begin
  if FH5Tclose(TypeId) < 0 then raise Exception.Create('Error calling H5Tclose')
end;

Procedure THdf5Dll.H5Oclose(ObjectId: Int64);
begin
  if FH5Oclose(ObjectId) < 0 then raise Exception.Create('Error calling H5Oclose')
end;

Procedure THdf5Dll.H5Pclose(ListId: Int64);
begin
  if FH5Pclose(ListId) < 0 then raise Exception.Create('Error calling H5Pclose')
end;

Procedure THdf5Dll.H5Fclose(FileId: Int64);
begin
  if FH5Fclose(FileId) < 0 then raise Exception.Create('Error calling H5Fclose')
end;

Procedure THdf5Dll.H5close;
begin
  if FH5close < 0 then raise Exception.Create('Error calling H5close')
end;

Procedure THdf5Dll.CreateStringAttribute(ObjId: Int64; ObjectName,AttributeName,AttributeValue: AnsiString);
Var
  AttributeSize: UInt32;
  ObjectId,TypeId,SpaceId,AttributeId: Int64;
begin
  AttributeSize := Length(AttributeValue) + 1;
  ObjectId := H5Oopen(ObjId,ObjectName,H5P_DEFAULT);
  TypeId := H5Tcopy(H5T_C_S1);
  H5Tset_size(TypeId,AttributeSize);
  H5Tset_strpad(TypeId,H5T_STR_NULLTERM);
  SpaceId := H5Screate(H5S_SCALAR);
  AttributeId := H5Acreate2(ObjId,AttributeName,TypeId,SpaceId,H5P_DEFAULT,H5P_DEFAULT);
  H5Awrite(AttributeId,TypeId,pAnsiChar(AttributeValue));
  H5Aclose(AttributeId);
  H5Sclose(SpaceId);
  H5Tclose(TypeId);
  H5Oclose(ObjectId);
end;

Procedure THdf5Dll.CreateIntArrayAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; const ArrayData: array of Integer);
Var
  Len: UInt64;
  ObjectId,SpaceId,AttributeId: Int64;
begin
  Len := Length(ArrayData);
  ObjectId := H5Oopen(ObjId,ObjectName,H5P_DEFAULT);
  SpaceId := H5Screate_simple(1,@Len);
  AttributeId := H5Acreate2(ObjId,AttributeName,H5T_NATIVE_INT,SpaceId,H5P_DEFAULT,H5P_DEFAULT);
  H5Awrite(AttributeId,H5T_NATIVE_INT,@ArrayData[0]);
  H5Aclose(AttributeId);
  H5Sclose(SpaceId);
  H5Oclose(ObjectId);
end;

Procedure THdf5Dll.ReadStringAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; var AttributeValue: AnsiString);
var
  AttributeId,TypeId,SpaceId: Int64;
  AttributeSize: UInt64;
begin
  AttributeID := H5Aopen_by_name(ObjID,ObjectName,AttributeName,H5P_DEFAULT,H5P_DEFAULT);
  TypeID := H5Aget_type(AttributeId);
  SpaceId := H5Aget_space(AttributeID);
  AttributeSize := H5Aget_storage_size(AttributeId);
  SetLength(AttributeValue, AttributeSize+1);
  H5Aread(AttributeId,TypeId,pAnsiChar(AttributeValue));
  H5Aclose(AttributeId);
  H5Tclose(TypeId);
  H5Sclose(SpaceId);
end;

Procedure THdf5Dll.ReadIntArrayAttribute(ObjId: Int64; ObjectName,AttributeName: AnsiString; var ArrayData: array of Integer);
Var
  AttributeId,SpaceId: Int64;
begin
  AttributeId := H5Aopen_by_name(ObjID,ObjectName,AttributeName,H5P_DEFAULT,H5P_DEFAULT);
  SpaceId := H5Aget_space(AttributeID);
  H5Aread(AttributeId,H5T_NATIVE_INT,@ArrayData[0]);
  H5Aclose(AttributeId);
  H5Sclose(SpaceId);
end;

Destructor THdf5Dll.Destroy;
begin
  if DllHandle <> 0 then
  begin
    H5Close;
    FreeLibrary(DllHandle);
  end;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function THdf5MatrixReader.Available: Boolean;
begin
  Result := Assigned(Hdf5Dll);
end;

Constructor THdf5MatrixReader.Create(const FileName: string);
begin
  inherited Create(FileName,false);
  Hdf5FileId := Hdf5Dll.H5Fopen(FileName,Hdf5Dll.H5F_ACC_RDONLY,Hdf5Dll.H5P_DEFAULT);
end;

Destructor THdf5MatrixReader.Destroy;
begin
  Hdf5Dll.H5Fclose(Hdf5FileId);
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function THdf5MatrixWriter.Available: Boolean;
begin
  Result := Assigned(Hdf5Dll);
end;

Constructor THdf5MatrixWriter.Create(const FileName,FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer);
begin
  inherited Create(FileName,Length(MatrixLabels),Size,false);
  Hdf5FileId := Hdf5Dll.H5Fcreate(FileName,Hdf5Dll.H5F_ACC_TRUNC,Hdf5Dll.H5P_DEFAULT,Hdf5Dll.H5P_DEFAULT);
end;

Destructor THdf5MatrixWriter.Destroy;
begin
  Hdf5Dll.H5Fclose(Hdf5FileId);
  inherited Destroy;
end;

Initialization
  var DllPath := ExtractFileDir(Paramstr(0)) + '\hdf5.dll';
  if FileExists(DllPath) then Hdf5Dll := THdf5Dll.Create(DllPath);
Finalization
  Hdf5Dll.Free;
end.
