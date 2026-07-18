unit matio.writer.hdf5.cube;

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
  SysUtils, matio.hdf5, matio.writer.hdf5;

Type
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
