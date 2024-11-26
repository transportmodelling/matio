unit matio.hdf5.cube;

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
  SysUtils, Types, ArrayBld, matio, matio.hdf5.dll, matio.hdf5;

Type
  TCubeMatrixReader = Class(THdf5MatrixReader)
  private
    FVersion: AnsiString;
  protected
    Function ReadAttributes: Integer; override; // Returns size
    Function MatrixGroup: ANSIString; override;
  public
    Property Version: AnsiString read FVersion;
  end;

  TCubeMatrixWriter = Class(THdf5MatrixWriter)
  strict protected
    Function Groups: TArray<ANSIString>; override;
    Function MatrixGroup: ANSIString; override;
    Procedure WriteAttributes(const FileLabel: ANSIString; Size: Integer); override;
  public
    Const
      CubeMatrixVersion = '1.0';
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCubeMatrixReader.ReadAttributes: Integer;
begin
  Hdf5Dll.ReadStringAttribute(Hdf5FileId,'/','CUBE_MATRIX_VERSION',FVersion);
  Hdf5Dll.ReadIntArrayAttribute(Hdf5FileId,'/','CUBE_MATRIX_ZONES',Result);
end;

Function TCubeMatrixReader.MatrixGroup: ANSIString;
begin
  Result := '/matrices';
end;

////////////////////////////////////////////////////////////////////////////////

Function TCubeMatrixWriter.Groups: TArray<ANSIString>;
begin
  Result := ['/matrices','/zonalReferences'];
end;

Function TCubeMatrixWriter.MatrixGroup: ANSIString;
begin
  Result := '/matrices';
end;

Procedure TCubeMatrixWriter.WriteAttributes(const FileLabel: ANSIString; Size: Integer);
begin
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','LABEL',FileLabel);
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','CUBE_MATRIX_VERSION',CubeMatrixVersion);
  Hdf5Dll.CreateIntAttribute(Hdf5FileId,'/','CUBE_MATRIX_ZONES',Size);
end;

end.
