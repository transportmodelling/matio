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
    Constructor Create;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
    Function HasFormat(const Header: TBytes): Boolean; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TVisumMatrixReaderFormat.Create;
begin
  inherited Create('visum','Visum');
end;

Function TVisumMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  CheckFormat(Config);
  var ExtendedConfig := ExtendProperties(Config);
  Result := TVisumMatrixReader.Create(ExtendedConfig.Path(FileProperty));
end;

Function TVisumMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := (Length(Header) >= 5) and (Header[0] = 3) and (Header[1] = 0)
            and (TEncoding.ASCII.GetString(Copy(Header,2,2)) = '$B') and (ANSIChar(Header[4]) in ['I','K','L']);
end;

end.
