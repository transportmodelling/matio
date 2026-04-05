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
  SysUtils, Types, ArrBld, matio, matio.hdf5.dll, matio.hdf5;

Type
  TOMXMatrixReader = Class(THdf5MatrixReader)
  // The OMX-specification does not require omx-files to store the creation order
  // of the matrices. If an omx-file was written without storing the creation order,
  // it is not possible to read matrices in the same order they have been written
  // and the Ordered-property will be set to false.
  private
    FVersion: AnsiString;
  protected
    Function ReadAttributes: Integer; override; // Returns size
    Function MatrixGroup: ANSIString; override;
  public
    Property Version: AnsiString read FVersion;
  end;

  TOMXMatrixWriter = Class(THdf5MatrixWriter)
  strict protected
    Function Groups: TArray<ANSIString>; override;
    Function MatrixGroup: ANSIString; override;
    Procedure WriteAttributes(const FileLabel: ANSIString; Size: Integer); override;
  public
    Const
      OMXversion = '0.2';
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

////////////////////////////////////////////////////////////////////////////////

Function TOMXMatrixWriter.Groups: TArray<ANSIString>;
begin
  Result := ['/data','/lookup'];
end;

Function TOMXMatrixWriter.MatrixGroup: ANSIString;
begin
  Result := '/data';
end;

Procedure TOMXMatrixWriter.WriteAttributes(const FileLabel: ANSIString; Size: Integer);
begin
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','LABEL',FileLabel);
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','OMX_VERSION',OMXversion);
  Hdf5Dll.CreateIntArrayAttribute(Hdf5FileId,'/','SHAPE',[Size,Size]);
end;

end.
