unit matio.formats.gen4;

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
  SysUtils, KeyVal, ArrBld, matio, matio.formats, matio.gen4,
  matio.reader, matio.reader.gen4, matio.writer, matio.writer.gen4;

Type
  T4GMatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Constructor Create;
    Function HasFormat(const Header: TBytes): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

  T4GMatrixWriterFormat = Class(TCustomMatrixWriterFormat)
  private
    Const
      PrecisionProperty = 'prec';
      CompressionProperty = 'compress';
      CompressionOptions: array[T4GCompression] of String = ('none','gzip');
  strict protected
    Function NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter; override;
  public
    Constructor Create;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor T4GMatrixReaderFormat.Create;
begin
  inherited Create('4g','4G');
end;

Function T4GMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := (Length(Header) >= 4) and (TEncoding.ASCII.GetString(Copy(Header,0,2)) = '4G')
            and (Header[2] = 20) and (Header[3] = 1);
end;

Function T4GMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  CheckFormat(Config);
  Result := T4GMatrixReader.Create(Config.Path(FileProperty));
end;

////////////////////////////////////////////////////////////////////////////////

Constructor T4GMatrixWriterFormat.Create;
begin
  inherited Create('4g','4G');
  AddProperty(PrecisionProperty,PrecisionLabels[ftFloat32],'Precision',TStringArrayBuilder.Create(PrecisionLabels));
  AddProperty(CompressionProperty,CompressionOptions[cpGZip],'Compression',TStringArrayBuilder.Create(CompressionOptions));
end;

Function T4GMatrixWriterFormat.NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter;
begin
  var ExtendedConfig := ExtendProperties(Config);
  var Precision := TFloatType(OptionIndex(ExtendedConfig.Str(PrecisionProperty),PrecisionLabels,'precision'));
  var Compression := T4GCompression(OptionIndex(ExtendedConfig.Str(CompressionProperty),CompressionOptions,'compression'));
  Result := T4GMatrixWriter.Create(ExtendedConfig.Path(FileProperty),NewFile.FileLabel,NewFile.MatrixLabels,
                                   NewFile.Size,Precision,Compression);
end;

end.
