unit matio.formats.cube;

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
  SysUtils, Types, KeyVal, matio, matio.formats, matio.formats.hdf5, matio.hdf5,
  matio.reader, matio.reader.hdf5.cube, matio.writer, matio.writer.hdf5.cube;

Type
  TCubeMatrixReaderFormat = Class(THdf5MatrixReaderFormat)
  public
    Function Format: String; override;
    Function HasFormat(const FileExtension: String): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader; override;
  end;

  TCubeMatrixWriterFormat = Class(THdf5MatrixWriterFormat)
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

Function TCubeMatrixReaderFormat.Format: String;
begin
  Result := 'cube';
end;

Function TCubeMatrixReaderFormat.HasFormat(const FileExtension: String): Boolean;
begin
  Result := SameText(FileExtension,'.Cube-matrix');
end;

Function TCubeMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  if SameText(Config.Str(FormatProperty),Format) then
    Result := TCubeMatrixReader.Create(Config.Path(FileProperty))
  else
    raise Exception.Create('Invalid format-property');
end;

Function TCubeMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader;
begin
  if SameText(Config.Str(FormatProperty),Format) then
    Result := TCubeMatrixReader.Create(Config.Path(FileProperty),Selection)
  else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Function TCubeMatrixWriterFormat.Format: String;
begin
  Result := 'cube';
end;

Function TCubeMatrixWriterFormat.CreateWriter(const [ref] Config: TKeyValuePairs;
                                              const FileLabel: string;
                                              const MatrixLabels: array of String;
                                              const Size: Integer): TMatrixWriter;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    var PrecisionPropertyValue := ExtendedConfig.Str(PrecisionProperty);
    for var Prec := low(THdf5Precision) to high(THdf5Precision) do
    if SameText(PrecisionLabels[Prec],PrecisionPropertyValue) then
    begin
      Result := TCubeMatrixWriter.Create(ExtendedConfig.Path(FileProperty),FileLabel,MatrixLabels,Size,Prec);
      Exit;
    end;
    raise Exception.Create('Invalid precision-property');
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
