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
  TMinutpMatrixReaderFormat = Class(TMatrixReaderFormat)
  strict protected
    Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Function Format: String; override;
    Function HasFormat(const Header: TBytes): Boolean; override;
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; override;
  end;

  TMinutpMatrixWriterFormat = Class(TMatrixWriterFormat)
  strict protected
    Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Function Format: String; override;
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

Function TMinutpMatrixReaderFormat.Format: String;
begin
  Result := 'mtp';
end;

Function TMinutpMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
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

Procedure TMinutpMatrixReaderFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
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

Function TMinutpMatrixWriterFormat.Format: String;
begin
  Result := 'mtp';
end;

Procedure TMinutpMatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
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
