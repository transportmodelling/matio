unit matio.formats.hdf5;

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
  SysUtils, KeyVal, matio, matio.formats, matio.hdf5,
  matio.reader, matio.reader.hdf5, matio.writer, matio.writer.hdf5;

Type
  THdf5MatrixReaderFormat = Class(TMatrixReaderFormat)
  // Descendants name the format and the reader class in their constructor
  private
    Extension: String;
    ReaderClass: THdf5MatrixReaderClass;
  strict protected
    Constructor Create(const Format,FormatName,Extension: String;
                       const ReaderClass: THdf5MatrixReaderClass); overload;
  public
    Function Available: Boolean; override;
    Function HasFormat(const FileExtension: String): Boolean; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
    Function CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader; override;
  end;

  THdf5MatrixWriterFormat = Class(TCustomMatrixWriterFormat)
  // Descendants name the format and the writer class in their constructor
  private
    Const
      PrecisionProperty = 'prec';
    Var
      WriterClass: THdf5MatrixWriterClass;
    Function PrecisionValue(const PropertyValue: String): THdf5Precision;
  strict protected
    Constructor Create(const Format,FormatName: String; const WriterClass: THdf5MatrixWriterClass); overload;
    Function NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter; override;
  public
    Function Available: Boolean; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor THdf5MatrixReaderFormat.Create(const Format,FormatName,Extension: String;
                                           const ReaderClass: THdf5MatrixReaderClass);
begin
  inherited Create(Format,FormatName);
  Self.Extension := Extension;
  Self.ReaderClass := ReaderClass;
end;

Function THdf5MatrixReaderFormat.Available: Boolean;
begin
  Result := THdf5MatrixReader.Available;
end;

Function THdf5MatrixReaderFormat.HasFormat(const FileExtension: String): Boolean;
begin
  Result := SameText(FileExtension,Extension);
end;

Function THdf5MatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  CheckFormat(Config);
  Result := ReaderClass.Create(Config.Path(FileProperty));
end;

Function THdf5MatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader;
begin
  CheckFormat(Config);
  Result := ReaderClass.Create(Config.Path(FileProperty),Selection);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor THdf5MatrixWriterFormat.Create(const Format,FormatName: String; const WriterClass: THdf5MatrixWriterClass);
begin
  inherited Create(Format,FormatName);
  Self.WriterClass := WriterClass;
  AddProperty(PrecisionProperty,PrecisionLabels[ftFloat32],'Precision',
              [PrecisionLabels[ftFloat32],PrecisionLabels[ftFloat64]]);
end;

Function THdf5MatrixWriterFormat.PrecisionValue(const PropertyValue: String): THdf5Precision;
begin
  if SameText(PrecisionLabels[ftFloat32],PropertyValue) then
    Result := ftFloat32
  else if SameText(PrecisionLabels[ftFloat64],PropertyValue) then
    Result := ftFloat64
  else
    raise Exception.Create('Invalid precision-property');
end;

Function THdf5MatrixWriterFormat.NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter;
begin
  var ExtendedConfig := ExtendProperties(Config);
  var Precision := PrecisionValue(ExtendedConfig.Str(PrecisionProperty));
  Result := WriterClass.Create(ExtendedConfig.Path(FileProperty),NewFile.FileLabel,NewFile.MatrixLabels,NewFile.Size,Precision);
end;

Function THdf5MatrixWriterFormat.Available: Boolean;
begin
  Result := THdf5MatrixWriter.Available;
end;

end.
