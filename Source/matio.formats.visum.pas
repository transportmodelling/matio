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
  SysUtils, Classes, KeyVal, matio, matio.formats, matio.reader, matio.reader.visum;

Type
  TVisumMatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Function Format: String; override;
    Function HasFormat(const Header: TBytes): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TVisumMatrixReaderFormat.Format: String;
begin
  Result := 'visum';
end;

Function TVisumMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
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

Function TVisumMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    Result := TVisumMatrixReader.Create(ExtendedConfig.Path(FileProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
