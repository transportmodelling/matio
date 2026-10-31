unit matio.formats.text;

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
  SysUtils, Types, KeyVal, Parse, ArrBld, matio, matio.formats,
  matio.reader, matio.reader.text, matio.writer, matio.writer.text;

Type
  TTextMatrixWriterFormat = Class(TCustomMatrixWriterFormat)
  strict protected
    Function NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter; override;
  public
    Constructor Create;
  end;

  TTextMatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Constructor Create;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  EncodingProperty = 'encoding';
  DecimalsProperty = 'decimals';
  HeaderProperty = 'header';
  DecimalSeparatorProperty = 'separator';
  ThousandSeparatorProperty = 'e3separator';
  SeparatorOptions: array[0..2] of String = ('none','point','comma');
  Separators: array[0..2] of Char = (#0,'.',',');
  DelimiterProperty = 'delim';
  DelimiterOptions: array[TDelimiter] of String = ('comma','tab','semicolon','space');
  BOMProperty = 'bom';

Function BoolPickList: TStringDynArray;
// The pick list of a boolean property of the reader and writer formats
begin
  Result := TStringArrayBuilder.Create([LowerCase(False.ToString(TUseBoolStrs.True)),LowerCase(True.ToString(TUseBoolStrs.True))]);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TTextMatrixWriterFormat.Create;
begin
  inherited Create('txt','Text');
  var BoolOptions := BoolPickList;
  AddProperty(EncodingProperty,'ascii','Encoding');
  AddProperty(DelimiterProperty,DelimiterOptions[Tab],'Delimiter',TStringArrayBuilder.Create(DelimiterOptions));
  AddProperty(HeaderProperty,true.ToString(TUseBoolStrs.True),'Header',BoolOptions);
  AddProperty(DecimalSeparatorProperty,SeparatorOptions[1],'Decimal separator',
              TStringArrayBuilder.Create(SeparatorOptions,1,Length(SeparatorOptions)-1));
  AddProperty(DecimalsProperty,'3','Decimals');
  AddProperty(ThousandSeparatorProperty,SeparatorOptions[0],'Thousand separator',TStringArrayBuilder.Create(SeparatorOptions));
  AddProperty(BOMProperty,false.ToString(TUseBoolStrs.True),'Byte order mark',BoolOptions);
end;

Function TTextMatrixWriterFormat.NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter;
Var
  Settings: TTextMatrixWriterSettings;
begin
  var ExtendedConfig := ExtendProperties(Config);
  Settings.Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
  Settings.Decimals := ExtendedConfig.Int(DecimalsProperty);
  Settings.Header := BoolPropertyValue(ExtendedConfig.Str(HeaderProperty),'header');
  Settings.FormatSettings.DecimalSeparator := Separators[OptionIndex(ExtendedConfig.Str(DecimalSeparatorProperty),SeparatorOptions,'decimal separator',1)];
  Settings.FormatSettings.ThousandSeparator := Separators[OptionIndex(ExtendedConfig.Str(ThousandSeparatorProperty),SeparatorOptions,'thousand separator')];
  Settings.Delimiter := TDelimiter(OptionIndex(ExtendedConfig.Str(DelimiterProperty),DelimiterOptions,'delimiter'));
  Settings.WriteByteOrderMark := BoolPropertyValue(ExtendedConfig.Str(BOMProperty),'bom');
  Result := TTextMatrixWriter.Create(ExtendedConfig.Path(FileProperty),NewFile.MatrixLabels,NewFile.Size,Settings);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TTextMatrixReaderFormat.Create;
begin
  inherited Create('txt','Text');
  AddProperty(EncodingProperty,'ascii','Encoding');
  AddProperty(DelimiterProperty,DelimiterOptions[Tab],'Delimiter',TStringArrayBuilder.Create(DelimiterOptions));
  AddProperty(HeaderProperty,true.ToString(TUseBoolStrs.True),'Header',BoolPickList);
  AddProperty(DecimalSeparatorProperty,SeparatorOptions[1],'Decimal separator',
              TStringArrayBuilder.Create(SeparatorOptions,1,Length(SeparatorOptions)-1));
  AddProperty(ThousandSeparatorProperty,SeparatorOptions[0],'Thousand separator',TStringArrayBuilder.Create(SeparatorOptions));
end;

Function TTextMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
Var
  TextFormatSettings: TFormatSettings;
begin
  CheckFormat(Config);
  var ExtendedConfig := ExtendProperties(Config);
  var Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
  var Header := BoolPropertyValue(ExtendedConfig.Str(HeaderProperty),'header');
  TextFormatSettings.DecimalSeparator := Separators[OptionIndex(ExtendedConfig.Str(DecimalSeparatorProperty),SeparatorOptions,'decimal separator',1)];
  TextFormatSettings.ThousandSeparator := Separators[OptionIndex(ExtendedConfig.Str(ThousandSeparatorProperty),SeparatorOptions,'thousand separator')];
  var Delimiter := TDelimiter(OptionIndex(ExtendedConfig.Str(DelimiterProperty),DelimiterOptions,'delimiter'));
  Result := TTextMatrixReader.Create(ExtendedConfig.Path(FileProperty),TextFormatSettings,Header,Delimiter,Encoding);
end;

end.
