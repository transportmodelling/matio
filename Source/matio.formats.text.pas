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
  private
    TextFormatSettings: TFormatSettings;
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
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,DelimiterProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(DelimiterOptions);
  end else
  if SameText(PropertyName,HeaderProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create([LowerCase(False.ToString(TUseBoolStrs.True)),
                                            LowerCase(True.ToString(TUseBoolStrs.True))]);
  end else
  if SameText(PropertyName,DecimalSeparatorProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(SeparatorOptions,1,Length(SeparatorOptions)-1);
  end else
  if SameText(PropertyName,ThousandSeparatorProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(SeparatorOptions);
  end else
    Result := false;
end;

Function TTextMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader;
Var
  Header: Boolean;
  Delimiter: TDelimiter;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    // Set encoding
    var Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
    // Set header
    var ValidHeader := false;
    var HeaderPropertyValue := ExtendedConfig.Str(HeaderProperty);
    for var Head := false to true do
    if SameText(Head.ToString(TUseBoolStrs.True),HeaderPropertyValue) then
    begin
      Header := Head;
      ValidHeader := true;
      Break;
    end;
    if not ValidHeader then raise Exception.Create('Invalid header');
    // Set decimal separator
    var ValidDecimalSeparator := false;
    var DecimalSeparatorPropertyValue := ExtendedConfig.Str(DecimalSeparatorProperty);
    for var Separator := 1 to 2 do
    if SameText(SeparatorOptions[Separator],DecimalSeparatorPropertyValue) then
    begin
      TextFormatSettings.DecimalSeparator := Separators[Separator];
      ValidDecimalSeparator := true;
      Break;
    end;
    if not ValidDecimalSeparator then raise Exception.Create('Invalid decimal separator');
    // Set thousand separator
    var ValidThousandSeparator := false;
    var ThousandSeparatorPropertyValue := ExtendedConfig.Str(ThousandSeparatorProperty);
    for var Separator := 0 to 2 do
    if SameText(SeparatorOptions[Separator],ThousandSeparatorPropertyValue) then
    begin
      TextFormatSettings.ThousandSeparator := Separators[Separator];
      ValidThousandSeparator := true;
      Break;
    end;
    if not ValidThousandSeparator then raise Exception.Create('Invalid thousand separator');
    // Set delimiter
    var ValidDelimiter := false;
    var DelimiterPropertyValue := ExtendedConfig.Str(DelimiterProperty);
    for var Delim := low(DelimiterOptions) to high(DelimiterOptions) do
    if SameText(DelimiterOptions[Delim],DelimiterPropertyValue) then
    begin
      Delimiter := Delim;
      ValidDelimiter := true;
      Break;
    end;
    if not ValidDelimiter then raise Exception.Create('Invalid delimiter');
    // Create reader
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
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,DelimiterProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(DelimiterOptions);
  end else
  if SameText(PropertyName,HeaderProperty) or SameText(PropertyName,BOMProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create([LowerCase(False.ToString(TUseBoolStrs.True)),
                                            LowerCase(True.ToString(TUseBoolStrs.True))]);
  end else
  if SameText(PropertyName,DecimalSeparatorProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(SeparatorOptions,1,Length(SeparatorOptions)-1);
  end else
  if SameText(PropertyName,ThousandSeparatorProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(SeparatorOptions);
  end else
    Result := false;
end;

Function TTextMatrixWriterFormat.CreateWriter(const [ref] Config: TKeyValuePairs;
                                              const FileLabel: string;
                                              const MatrixLabels: array of String;
                                              const Size: Integer): TMatrixWriter;
Var
  Header,WriteBOM: Boolean;
  Decimals: Integer;
  Delimiter: TDelimiter;
begin
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var ExtendedConfig := ExtendProperties(Config);
    // Set encoding
    var Encoding := TEncoding.GetEncoding(ExtendedConfig.Str(EncodingProperty));
    // Set decimals
    Decimals := ExtendedConfig.Int(DecimalsProperty);
    // Set header
    var ValidHeader := false;
    var HeaderPropertyValue := ExtendedConfig.Str(HeaderProperty);
    for var Head := false to true do
    if SameText(Head.ToString(TUseBoolStrs.True),HeaderPropertyValue) then
    begin
      Header := Head;
      ValidHeader := true;
      Break;
    end;
    if not ValidHeader then raise Exception.Create('Invalid header');
    // Set decimal separator
    var ValidDecimalSeparator := false;
    var DecimalSeparatorPropertyValue := ExtendedConfig.Str(DecimalSeparatorProperty);
    for var Separator := 1 to 2 do
    if SameText(SeparatorOptions[Separator],DecimalSeparatorPropertyValue) then
    begin
      TextFormatSettings.DecimalSeparator := Separators[Separator];
      ValidDecimalSeparator := true;
      Break;
    end;
    if not ValidDecimalSeparator then raise Exception.Create('Invalid decimal separator');
    // Set thousand separator
    var ValidThousandSeparator := false;
    var ThousandSeparatorPropertyValue := ExtendedConfig.Str(ThousandSeparatorProperty);
    for var Separator := 0 to 2 do
    if SameText(SeparatorOptions[Separator],ThousandSeparatorPropertyValue) then
    begin
      TextFormatSettings.ThousandSeparator := Separators[Separator];
      ValidThousandSeparator := true;
      Break;
    end;
    if not ValidThousandSeparator then raise Exception.Create('Invalid thousand separator');
    // Set delimiter
    var ValidDelimiter := false;
    var DelimiterPropertyValue := ExtendedConfig.Str(DelimiterProperty);
    for var Delim := low(DelimiterOptions) to high(DelimiterOptions) do
    if SameText(DelimiterOptions[Delim],DelimiterPropertyValue) then
    begin
      Delimiter := Delim;
      ValidDelimiter := true;
      Break;
    end;
    if not ValidDelimiter then raise Exception.Create('Invalid delimiter');
    // Set Byte Order Mark
    var ValidBOM := false;
    var BOMPropertyValue := ExtendedConfig.Str(BOMProperty);
    for var BOM := false to true do
    if SameText(BOM.ToString(TUseBoolStrs.True),BOMPropertyValue) then
    begin
      WriteBOM := BOM;
      ValidBOM := true;
      Break;
    end;
    if not ValidBOM then raise Exception.Create('Invalid bom');
    // Create writer
    result := TTextMatrixWriter.Create(ExtendedConfig.Path(FileProperty),MatrixLabels,Size,
                                       TextFormatSettings,Header,Delimiter,Decimals,Encoding,WriteBOM);
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
