unit matio.formats.hdf5;

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
  SysUtils, Types, PropSet, matio, matio.formats, matio.hdf5;

Type
  THdf5MatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Function Available: Boolean; override;
  end;

  THdf5MatrixWriterFormat = Class(TMatrixWriterFormat)
  strict protected
    Const
      PrecisionProperty = 'prec';
    Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Function Available: Boolean; override;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function THdf5MatrixReaderFormat.Available: Boolean;
begin
  Result := THdf5MatrixReader.Available;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure THdf5MatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,PrecisionLabels[ftFloat32]);
end;

Function THdf5MatrixWriterFormat.Available: Boolean;
begin
  Result := THdf5MatrixReader.Available;
end;

Function THdf5MatrixWriterFormat.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,PrecisionProperty) then
  begin
    Result := true;
    PickList := [PrecisionLabels[ftFloat32],PrecisionLabels[ftFloat64]];
  end else
    Result := false;
end;

end.
