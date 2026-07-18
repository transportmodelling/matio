unit matio.reader.hdf5;

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
  SysUtils, Types, ArrBld, matio, matio.row, matio.reader, matio.hdf5;

Type
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
    Procedure ReadFileLabel;
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

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function THdf5MatrixReader.Available: Boolean;
begin
  Result := Assigned(Hdf5Dll);
end;

Constructor THdf5MatrixReader.Create(const FileName: String);
// Reads all matrices available in the file. Hdf5-based formats identify their
// matrices by name and do not define a matrix order, so the Ordered-property
// is set to false. The matrices are enumerated in alphabetical order.
begin
  inherited Create(FileName,false);
  Hdf5FileId := Hdf5Dll.H5Fopen(FileName,Hdf5Dll.H5F_ACC_RDONLY,Hdf5Dll.H5P_DEFAULT);
  SetSize(ReadAttributes);
  ReadFileLabel;
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
  ReadFileLabel;
  GetAvailableMatrices;
  GetMatrices(MatrixLabels);
  FOrdered := true; // Index provided by selection
end;

Class Function THdf5MatrixReader.LinkIterCallback(loc_id: Int64; Name: PAnsiChar; Info: Pointer; opdata:Pointer) : Integer;
begin
  var MatrixFile := THdf5MatrixReader(opdata);
  MatrixFile.AvailableMatrices := MatrixFile.AvailableMatrices + [Name];
  Result := 0;
end;

Procedure THdf5MatrixReader.ReadFileLabel;
// The LABEL attribute is optional; files written by other tools may not have it
Var
  FileLabel: AnsiString;
begin
  if Hdf5Dll.H5Aexists_by_name(Hdf5FileId,'/','LABEL',Hdf5Dll.H5P_DEFAULT) then
  begin
    Hdf5Dll.ReadStringAttribute(Hdf5FileId,'/','LABEL',FileLabel);
    // Fixed-size Hdf5 strings are padded with trailing spaces
    SetFileLabel(TrimRight(String(FileLabel)));
  end;
end;

Procedure THdf5MatrixReader.GetAvailableMatrices;
// Enumerates the matrix names in alphabetical order, the same order other
// Hdf5 tools display. The file does not define a matrix order, so the
// Ordered-property is set to false.
begin
  FOrdered := false;
  var DataGroup := Hdf5Dll.H5Gopen2(Hdf5FileId,MatrixGroup,Hdf5Dll.H5P_DEFAULT);
  var PCallBack := @LinkIterCallback;
  var Idx: Int64 := 0;
  Hdf5Dll.H5Literate(DataGroup,Hdf5Dll.H5_INDEX_NAME,Hdf5dll.H5_ITER_INC,@Idx,PCallback,Self);
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

end.
