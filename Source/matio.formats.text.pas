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
  TTextMatrixReaderFormat = Class(TMatrixReaderFormat)
  private
    TextFormatSettings: TFormatSettings;
  strict protected
    Procedure AppendFormatProperties(var Config: TKeyValuePairs); override;
  public
    Function Format: String; override;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; override;
  end;

  TTextMatrixWriterformat = Class(TMatrixWriterFormat)
  strict protected
    Procedure AppendFormatProperties(var Config: TKeyValuePairs); override;
  public
    Function Format: String; override;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; override;
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

Function TextPropertyPickList(const PropertyName: string; const IncludeBOM: Boolean;
                              out PickList: TStringDynArray): Boolean;
// The pick lists for the properties the reader and writer formats share
begin
  Result := true;
  if SameText(PropertyName,DelimiterProperty) then
    PickList := TStringArrayBuilder.Create(DelimiterOptions)
  else if SameText(PropertyName,HeaderProperty) or (IncludeBOM and SameText(PropertyName,BOMProperty)) then
    PickList := TStringArrayBuilder.Create([LowerCase(False.ToString(TUseBoolStrs.True)),LowerCase(True.ToString(TUseBoolStrs.True))])
  else if SameText(PropertyName,DecimalSeparatorProperty) then
    PickList := TStringArrayBuilder.Create(SeparatorOptions,1,Length(SeparatorOptions)-1)
  else if SameText(PropertyName,ThousandSeparatorProperty) then
    PickList := TStringArrayBuilder.Create(SeparatorOptions)
  else
    Result := false;
end;

////////////////////////////////////////////////////////////////////////////////

Function TTextMatrixReaderFormat.Format: String;
begin
  Result := 'txt';
end;

Procedure TTextMatrixReaderFormat.AppendFormatProperties(var Config: TKeyValuePairs);
begin
  Config.Append(EncodingProperty,'ascii');
  Config.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Config.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Config.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Config.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
end;

Function TTextMatrixReaderFormat.PropertyPickList(const PropertyName: string;
                                                        out PickList: TStringDynArray): Boolean;
begin
  Result := inherited PropertyPickList(PropertyName,PickList) or
            TextPropertyPickList(PropertyName,false,PickList);
end;

Function TTextMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    var Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
    var Header := BoolPropertyValue(ExtendedConfig.Str(HeaderProperty),'header');
    TextFormatSettings.DecimalSeparator :=
      Separators[OptionIndex(ExtendedConfig.Str(DecimalSeparatorProperty),SeparatorOptions,'decimal separator',1)];
    TextFormatSettings.ThousandSeparator :=
      Separators[OptionIndex(ExtendedConfig.Str(ThousandSeparatorProperty),SeparatorOptions,'thousand separator')];
    var Delimiter := TDelimiter(OptionIndex(ExtendedConfig.Str(DelimiterProperty),DelimiterOptions,'delimiter'));
    Result := TTextMatrixReader.Create(ExtendedConfig.Path(FileProperty),TextFormatSettings,Header,Delimiter,Encoding);
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Function TTextMatrixWriterFormat.Format: String;
begin
  Result := 'txt';
end;

Procedure TTextMatrixWriterFormat.AppendFormatProperties(var Config: TKeyValuePairs);
begin
  Config.Append(EncodingProperty,'ascii');
  Config.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Config.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Config.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Config.Append(DecimalsProperty,'3');
  Config.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
  Config.Append(BOMProperty,false.ToString(TUseBoolStrs.True));
end;

Function TTextMatrixWriterFormat.PropertyPickList(const PropertyName: string;
                                                  out PickList: TStringDynArray): Boolean;
begin
  Result := inherited PropertyPickList(PropertyName,PickList) or
            TextPropertyPickList(PropertyName,true,PickList);
end;

Function TTextMatrixWriterFormat.CreateWriter(const [ref] Config: TKeyValuePairs;
                                              const FileLabel: string;
                                              const MatrixLabels: array of String;
                                              const Size: Integer): TMatrixWriter;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    var Settings: TTextMatrixWriterSettings;
    Settings.Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
    Settings.Decimals := ExtendedConfig.Int(DecimalsProperty);
    Settings.Header := BoolPropertyValue(ExtendedConfig.Str(HeaderProperty),'header');
    Settings.FormatSettings.DecimalSeparator :=
      Separators[OptionIndex(ExtendedConfig.Str(DecimalSeparatorProperty),SeparatorOptions,'decimal separator',1)];
    Settings.FormatSettings.ThousandSeparator :=
      Separators[OptionIndex(ExtendedConfig.Str(ThousandSeparatorProperty),SeparatorOptions,'thousand separator')];
    Settings.Delimiter := TDelimiter(OptionIndex(ExtendedConfig.Str(DelimiterProperty),DelimiterOptions,'delimiter'));
    Settings.WriteByteOrderMark := BoolPropertyValue(ExtendedConfig.Str(BOMProperty),'bom');
    Result := TTextMatrixWriter.Create(ExtendedConfig.Path(FileProperty),MatrixLabels,Size,Settings);
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
