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
  SysUtils, Types, ArrayBld, matio, matio.hdf5.dll;

Type
  THdf5Precision = ftFloat32..ftFloat64;

  THdf5MatrixReader = Class(TMatrixReader)
  private
    Const
      Single: array[0..1] of UInt64 = (1,1);
    Var
      ChunkSize: array[0..1] of UInt64;
      RowSpaceId: Int64;
      Float32Row: TFloat32MatrixRow;
      Float64Row: TFloat64MatrixRow;
      AvailableMatrices: array of String;
      MatrixPrecision: array of THdf5Precision;
      MatrixDataSetIds,MatrixDataSpaceIds: array of Int64;
    Class Function LinkIterCallback(loc_id: Int64; Name: PAnsiChar; Info: Pointer; opdata:Pointer) : Integer;  static; cdecl;
    Procedure GetAvailableMatrices;
    Procedure GetMatrices(const MatrixLabels: array of String);
  protected
    Hdf5FileId: Int64;
    Function ReadAttributes: Integer; virtual; abstract; // Returns size
    Function MatrixGroup: ANSIString; virtual; abstract;
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
    Class Function Available: Boolean;
  public
    Constructor Create(const FileName: String); overload;
    Constructor Create(const FileName: String; const MatrixLabels: array of String); overload;
    Destructor Destroy; override;
  end;

  THdf5MatrixWriter = Class(TMatrixWriter)
  private
    Const
      Single: array[0..1] of UInt64 = (1,1);
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

Class Function THdf5MatrixReader.Available: Boolean;
begin
  Result := Assigned(Hdf5Dll);
end;

Constructor THdf5MatrixReader.Create(const FileName: String);
// Reads all matrices available in the file. If the Hdf5-file has been written
// without storing the creation order of the matrices, the Ordered-property
// is set to false.
begin
  inherited Create(FileName,false);
  Hdf5FileId := Hdf5Dll.H5Fopen(FileName,Hdf5Dll.H5F_ACC_RDONLY,Hdf5Dll.H5P_DEFAULT);
  SetSize(ReadAttributes);
  GetAvailableMatrices;
  GetMatrices(AvailableMatrices);
end;

Constructor THdf5MatrixReader.Create(const FileName: String; const MatrixLabels: array of String);
// A list of labels for the matrices to be read is passed as a constructor argument
// to enable indexed access. The index to use for a specific matrix is the index of its
// name in the list of matrix labels.
begin
  inherited Create(FileName,false);
  Hdf5FileId := Hdf5Dll.H5Fopen(FileName,Hdf5Dll.H5F_ACC_RDONLY,Hdf5Dll.H5P_DEFAULT);
  SetSize(ReadAttributes);
  GetAvailableMatrices;
  GetMatrices(MatrixLabels);
  FOrdered := true; // // Index provided by selection
end;

Class Function THdf5MatrixReader.LinkIterCallback(loc_id: Int64; Name: PAnsiChar; Info: Pointer; opdata:Pointer) : Integer;
begin
  var MatrixFile := THdf5MatrixReader(opdata);
  MatrixFile.AvailableMatrices := MatrixFile.AvailableMatrices + [Name];
  Result := 0;
end;

Procedure THdf5MatrixReader.GetAvailableMatrices;
begin
  var DataGroup := Hdf5Dll.H5Gopen2(Hdf5FileId,MatrixGroup,Hdf5Dll.H5P_DEFAULT);
  // Get creation-order availability
  var Info := Hdf5Dll.H5Gget_create_plist(DataGroup);
  var Flags := Hdf5Dll.H5Pget_link_creation_order(Info);
  Hdf5Dll.H5Pclose(info);
  // Iterate matrix names
  var PCallBack := @LinkIterCallback;
  var Idx: Int64 := 0;
  if ((flags and Hdf5Dll.H5P_CRT_ORDER_TRACKED) <> 0) then
    Hdf5Dll.H5Literate(DataGroup,Hdf5Dll.H5_INDEX_CRT_ORDER,Hdf5dll.H5_ITER_INC,@Idx,PCallback,Self)
  else
    begin
      FOrdered := false;
    	Hdf5Dll.H5Literate(DataGroup,Hdf5Dll.H5_INDEX_NAME,Hdf5dll.H5_ITER_INC,@Idx,PCallback,Self);
    end;
  Hdf5Dll.H5Gclose(DataGroup);
end;

Procedure THdf5MatrixReader.GetMatrices(const MatrixLabels: array of String);
begin
  SetCount(Length(MatrixLabels));
  ChunkSize[0] := 1;
  ChunkSize[1] := Size;
  SetLength(MatrixPrecision,Length(MatrixLabels));
  SetLength(MatrixDataSetIds,Length(MatrixLabels));
  SetLength(MatrixDataSpaceIds,Length(MatrixLabels));
  RowSpaceId := Hdf5Dll.H5Screate_simple(2,@ChunkSize[0]);
  for var Matrix := 0 to Count-1 do
  begin
    SetMatrixLabels(Matrix,MatrixLabels[Matrix]);
    MatrixDataSetIds[Matrix] := Hdf5Dll.H5Dopen2(Hdf5FileId,MatrixGroup+'/'+MatrixLabels[Matrix],Hdf5Dll.H5P_DEFAULT);
    MatrixDataSpaceIds[Matrix] := Hdf5Dll.H5Dget_space(MatrixDataSetIds[Matrix]);
    // Set matrix data type
    var DataType := Hdf5Dll.H5Dget_type(MatrixDataSetIds[Matrix]);
    var TypeSize := Hdf5Dll.H5Tget_size(DataType);
    var TypeClass := Hdf5Dll.H5Tget_class(DataType);
    if TypeClass = Hdf5Dll.H5T_FLOAT then
    begin
      if TypeSize = 4 then
      begin
        SetLength(Float32Row,Size);
        MatrixPrecision[Matrix] := ftFloat32;
      end else
      if TypeSize = 8 then
      begin
        SetLength(Float64Row,Size);
        MatrixPrecision[Matrix] := ftFloat64;
      end else
        raise Exception.Create('Dataset type not supported')
    end else
      raise Exception.Create('Dataset type not supported');
  end;
end;

Procedure THdf5MatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  Offset: array[0..1] of UInt64;
begin
  Offset[0] := CurrentRow;
  Offset[1] := 0;
  for var Matrix := 0 to Count-1 do
  begin
    Hdf5Dll.H5Sselect_hyperslab(MatrixDataSpaceIds[Matrix],Hdf5Dll.H5S_SELECT_SET,Offset,Single,ChunkSize,Single);
    case MatrixPrecision[Matrix] of
      ftFloat32:
        begin
          Hdf5Dll.H5Dread(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_FLOAT,RowSpaceId,MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Float32Row[0]);
          if Size < Rows.Size then
            for var Column := 0 to Size-1 do Rows[Matrix,Column] := Float32Row[Column]
          else
            for var Column := 0 to Rows.Size-1 do Rows[Matrix,Column] := Float32Row[Column]
        end;
      ftFloat64:
        begin
          Hdf5Dll.H5Dread(MatrixDataSetIds[Matrix],Hdf5Dll.H5T_NATIVE_DOUBLE,RowSpaceId,MatrixDataSpaceIds[Matrix],Hdf5Dll.H5P_DEFAULT,@Float64Row[0]);
          if Size < Rows.Size then
            for var Column := 0 to Size-1 do Rows[Matrix,Column] := Float64Row[Column]
          else
            for var Column := 0 to Rows.Size-1 do Rows[Matrix,Column] := Float64Row[Column]
        end;
    end;
  end;
end;

Destructor THdf5MatrixReader.Destroy;
begin
  if Hdf5Dll <> nil then
  begin
    for var Matrix := 0 to Count-1 do
    begin
      Hdf5Dll.H5Dclose(MatrixDataSetIds[Matrix]);
      Hdf5Dll.H5Sclose(MatrixDataSpaceIds[Matrix]);
    end;
  end;
  Hdf5Dll.H5Sclose(RowSpaceId);
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
  // Save creation order
  var plist := Hdf5Dll.H5Pcreate (Hdf5Dll.H5P_CLS_GROUP_CREATE_ID);
  Hdf5Dll.H5Pset_link_creation_order(plist,Hdf5Dll.H5P_CRT_ORDER_TRACKED);
  // Create folder structure
  for var Group in Groups do Hdf5Dll.H5Gcreate2(Hdf5FileId,Group,0,plist,0);
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
