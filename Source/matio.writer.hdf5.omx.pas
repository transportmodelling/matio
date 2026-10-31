unit matio.writer.hdf5.omx;

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
  SysUtils, matio.hdf5, matio.writer.hdf5;

Type
  TOMXMatrixWriter = Class(THdf5MatrixWriter)
  public
    Const
      OMXversion = '0.2';
  strict protected
    Function MatrixGroup: ANSIString; override;
    Function Groups: TArray<ANSIString>; override;
    Procedure WriteAttributes(const FileLabel: ANSIString; Size: Integer); override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TOMXMatrixWriter.MatrixGroup: ANSIString;
begin
  Result := '/data';
end;

Function TOMXMatrixWriter.Groups: TArray<ANSIString>;
begin
  Result := ['/data','/lookup'];
end;

Procedure TOMXMatrixWriter.WriteAttributes(const FileLabel: ANSIString; Size: Integer);
begin
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','LABEL',FileLabel);
  Hdf5Dll.CreateStringAttribute(Hdf5FileId,'/','OMX_VERSION',OMXversion);
  Hdf5Dll.CreateIntArrayAttribute(Hdf5FileId,'/','SHAPE',[Size,Size]);
end;

end.
