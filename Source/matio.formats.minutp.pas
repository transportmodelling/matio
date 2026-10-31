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
  TMinutpMatrixWriterFormat = Class(TCustomMatrixWriterFormat)
  strict protected
    Function NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter; override;
  public
    Constructor Create;
  end;

  TMinutpMatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Constructor Create;
    Function HasFormat(const Header: TBytes): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  PrecisionProperty = 'prec';
  PrecisionLabel = 'Precision';

Constructor TMinutpMatrixWriterFormat.Create;
begin
  inherited Create('mtp','Minutp');
  AddProperty(PrecisionProperty,'',PrecisionLabel);
end;

Function TMinutpMatrixWriterFormat.NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter;
begin
  var ExtendedConfig := ExtendProperties(Config);
  Result := TMinutpMatrixWriter.Create(ExtendedConfig.Path(FileProperty),NewFile.FileLabel,Length(NewFile.MatrixLabels),
                                       NewFile.Size,ExtendedConfig.Int(PrecisionProperty));
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMinutpMatrixReaderFormat.Create;
begin
  inherited Create('mtp','Minutp');
  AddProperty(PrecisionProperty,'0',PrecisionLabel);
end;

Function TMinutpMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := (Length(Header) >= 74) and (TEncoding.ASCII.GetString(Copy(Header,66,7)) = ' MATRIX') and (Header[73] = 45);
end;

Function TMinutpMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  CheckFormat(Config);
  var ExtendedConfig := ExtendProperties(Config);
  Result := TMinutpMatrixReader.Create(ExtendedConfig.Path(FileProperty),ExtendedConfig.Int(PrecisionProperty));
end;

end.
