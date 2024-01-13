unit matio.formats.minutp;

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
  SysUtils, PropSet, matio, matio.formats, matio.minutp;

Type
  TMinutpMatrixReaderFormat = Class(TIndexedMatrixReaderFormat)
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function HasFormat(const Header: TBytes): Boolean; override;
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; override;
  end;

  TMinutpMatrixWriterFormat = Class(TMatrixWriterFormat)
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
  public
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  PrecisionProperty = 'prec';

Class Function TMinutpMatrixReaderFormat.Format: String;
begin
  Result := 'mtp';
end;

Class Function TMinutpMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  if Length(Header) >= 74 then
  begin
    if TEncoding.ASCII.GetString(Copy(Header,66,7)) = ' MATRIX' then
      if Header[73] = 45 then
        Result := true
      else
        Result := false
    else
      Result := false;
  end else
    Result := false;
end;

Class Procedure TMinutpMatrixReaderFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,'0');
end;

Function TMinutpMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    Result := TMinutpMatrixReader.Create(ExtendedProperties.ToPath(FileProperty),ExtendedProperties.ToInt(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TMinutpMatrixWriterFormat.Format: String;
begin
  Result := 'mtp';
end;

Class Procedure TMinutpMatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,'');
end;

Function TMinutpMatrixWriterFormat.CreateWriter(const [ref] Properties: TPropertySet;
                                                const FileLabel: string;
                                                const MatrixLabels: array of String;
                                                const Size: Integer): TMatrixWriter;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    Result := TMinutpMatrixWriter.Create(ExtendedProperties.ToPath(FileProperty),FileLabel,Length(MatrixLabels),
                                         Size,ExtendedProperties.ToInt(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
