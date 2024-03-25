unit matio.formats.visum;

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
  SysUtils, Classes, PropSet, matio, matio.formats, matio.visum;

Type
  TVisumMatrixReaderFormat = Class(TIndexedMatrixReaderFormat)
  public
    Class Function Format: String; override;
    Class Function HasFormat(const Header: TBytes): Boolean; override;
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function TVisumMatrixReaderFormat.Format: String;
begin
  Result := 'visum';
end;

Class Function TVisumMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := false;
  if Length(Header) >= 5 then
  begin
    if Header[0] = 3 then
    if Header[1] = 0 then
    if ANSIChar(Header[2]) = '$' then
    if ANSIChar(Header[3]) = 'B' then
    if ANSIChar(Header[4]) in ['I','K','L'] then
    Result := true;
  end else
    Result := false;
end;

Function TVisumMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    Result := TVisumMatrixReader.Create(ExtendedProperties.ToPath(FileProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
