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
  SysUtils, KeyVal, matio, matio.formats, matio.reader, matio.reader.minutp, matio.writer, matio.writer.minutp;

Type
  TMinutpMatrixReaderFormat = Class(TMatrixReaderFormat)
  strict protected
    Procedure AppendFormatProperties(var Config: TKeyValuePairs); override;
  public
    Function Format: String; override;
    Function HasFormat(const Header: TBytes): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

  TMinutpMatrixWriterFormat = Class(TMatrixWriterFormat)
  strict protected
    Procedure AppendFormatProperties(var Config: TKeyValuePairs); override;
  public
    Function Format: String; override;
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
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

Procedure TMinutpMatrixReaderFormat.AppendFormatProperties(var Config: TKeyValuePairs);
begin
  Config.Append(PrecisionProperty,'0');
end;

Function TMinutpMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    Result := TMinutpMatrixReader.Create(ExtendedConfig.Path(FileProperty),ExtendedConfig.Int(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Function TMinutpMatrixWriterFormat.Format: String;
begin
  Result := 'mtp';
end;

Procedure TMinutpMatrixWriterFormat.AppendFormatProperties(var Config: TKeyValuePairs);
begin
  Config.Append(PrecisionProperty,'');
end;

Function TMinutpMatrixWriterFormat.CreateWriter(const [ref] Config: TKeyValuePairs;
                                                const FileLabel: string;
                                                const MatrixLabels: array of String;
                                                const Size: Integer): TMatrixWriter;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    Result := TMinutpMatrixWriter.Create(ExtendedConfig.Path(FileProperty),FileLabel,Length(MatrixLabels),
                                         Size,ExtendedConfig.Int(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
