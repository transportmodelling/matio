unit matio.reader.hdf5.omx;

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
  SysUtils, matio.hdf5, matio.reader.hdf5;

Type
  TOMXMatrixReader = Class(THdf5MatrixReader)
  // The OMX-specification identifies matrices by name only and does not define
  // a matrix order, so the Ordered-property is false and matrices should be
  // selected by label. Without a selection the matrices are enumerated in
  // alphabetical order.
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

Function TOMXMatrixReader.ReadAttributes: Integer;
Var
  Shape: array[0..1] of Integer;
begin
  Hdf5Dll.ReadStringAttribute(Hdf5FileId,'/','OMX_VERSION',FVersion);
  Hdf5Dll.ReadIntArrayAttribute(Hdf5FileId,'/','SHAPE',Shape);
  if Shape[0] = Shape[1] then Result := Shape[0] else raise Exception.Create('square matrices required');
end;

Function TOMXMatrixReader.MatrixGroup: ANSIString;
begin
  Result := '/data';
end;

end.
