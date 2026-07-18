unit matio.reader.hdf5.cube;

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
  SysUtils, matio.hdf5, matio.reader.hdf5;

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

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TCubeMatrixReader.ReadAttributes: Integer;
begin
  Hdf5Dll.ReadStringAttribute(Hdf5FileId,'/',  'CUBE_MATRIX_VERSION',FVersion);
  Hdf5Dll.ReadIntArrayAttribute(Hdf5FileId,'/','CUBE_MATRIX_ZONES',Result);
end;

Function TCubeMatrixReader.MatrixGroup: ANSIString;
begin
  Result := '/matrices';
end;

end.
