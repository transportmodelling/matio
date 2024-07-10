unit matio.formats.omx;

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
  SysUtils, Types, Propset, matio, matio.formats, matio.hdf5.omx;

Type
  TOMXMatrixReaderFormat = Class(TLabeledMatrixReaderFormat)
  public
    Function Format: String; override;
    Function Available: Boolean; override;
    Function HasFormat(const FileExtension: String): Boolean; override;
    Function CreateReader(const [ref] Properties: TPropertySet; const Selection: array of String): TMatrixReader; override;
  end;

  TOMXMatrixWriterFormat = Class(TMatrixWriterFormat)
  private
    Const
      PrecisionProperty = 'prec';
  strict protected
    Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Function Format: String; override;
    Function Available: Boolean; override;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TOMXMatrixReaderFormat.Format: String;
begin
  Result := 'omx';
end;

Function TOMXMatrixReaderFormat.Available: Boolean;
begin
  Result := TOMXMatrixReader.Available;
end;

Function TOMXMatrixReaderFormat.HasFormat(const FileExtension: String): Boolean;
begin
  Result := SameText(FileExtension,'.omx');
end;

Function TOMXMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet; const Selection: array of String): TMatrixReader;
begin
  if SameText(Properties[FormatProperty],Format) then
    Result := TOMXMatrixReader.Create(Properties.ToPath(FileProperty),Selection)
  else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TOMXMatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,PrecisionLabels[ftFloat32]);
end;

Function TOMXMatrixWriterFormat.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,PrecisionProperty) then
  begin
    Result := true;
    PickList := [PrecisionLabels[ftFloat32],PrecisionLabels[ftFloat64]];
  end else
    Result := false;
end;

Function TOMXMatrixWriterFormat.Format: String;
begin
  Result := 'omx';
end;

Function TOMXMatrixWriterFormat.Available: Boolean;
begin
  Result := TOMXMatrixWriter.Available;
end;

Function TOMXMatrixWriterFormat.CreateWriter(const [ref] Properties: TPropertySet;
                                             const FileLabel: string;
                                             const MatrixLabels: array of String;
                                             const Size: Integer): TMatrixWriter;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    var PrecisionPropertyValue := ExtendedProperties[PrecisionProperty];
    for var Prec := low(TOMXPrecision) to high(TOMXPrecision) do
    if SameText(PrecisionLabels[Prec],PrecisionPropertyValue) then
    begin
      result := TOMXMatrixWriter.Create(ExtendedProperties.ToPath(FileProperty),FileLabel,MatrixLabels,Size,Prec);
      Exit;
    end;
    raise Exception.Create('Invalid precision-property');
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
