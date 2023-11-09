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
  SysUtils, Types, PropSet, Parse, ArrayBld, matio, matio.formats, matio.text;

Type
  TTextMatrixReaderFormat = Class(TMatrixReaderFormat)
  private
    TextFormatSettings: TFormatSettings;
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; override;
  end;

  TTextMatrixWriterformat = Class(TMatrixWriterFormat)
  private
    TextFormatSettings: TFormatSettings;
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
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

Class Function TTextMatrixReaderFormat.Format: String;
begin
  Result := 'txt';
end;

Class Procedure TTextMatrixReaderFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(EncodingProperty,'ascii');
  Properties.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Properties.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Properties.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Properties.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
end;

Class Function TTextMatrixReaderFormat.PropertyPickList(const PropertyName: string;
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

Function TTextMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
Var
  Header: Boolean;
  Delimiter: TDelimiter;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    // Set encoding
    var Encoding := TEncoding.GetEncoding(ExtendedProperties[EncodingProperty]);
    // Set header
    var ValidHeader := false;
    var HeaderPropertyValue := ExtendedProperties[HeaderProperty];
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
    var DecimalSeparatorPropertyValue := ExtendedProperties[DecimalSeparatorProperty];
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
    var ThousandSeparatorPropertyValue := ExtendedProperties[ThousandSeparatorProperty];
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
    var DelimiterPropertyValue := ExtendedProperties[DelimiterProperty];
    for var Delim := low(DelimiterOptions) to high(DelimiterOptions) do
    if SameText(DelimiterOptions[Delim],DelimiterPropertyValue) then
    begin
      Delimiter := Delim;
      ValidDelimiter := true;
      Break;
    end;
    if not ValidDelimiter then raise Exception.Create('Invalid delimiter');
    // Create reader
    Result := TTextMatrixReader.Create(ExtendedProperties.ToPath(FileProperty),TextFormatSettings,Header,Delimiter,Encoding);
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TTextMatrixWriterFormat.Format: String;
begin
  Result := 'txt';
end;

Class Procedure TTextMatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(EncodingProperty,'ascii');
  Properties.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Properties.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Properties.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Properties.Append(DecimalsProperty,'3');
  Properties.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
  Properties.Append(BOMProperty,false.ToString(TUseBoolStrs.True));
end;

Class Function TTextMatrixWriterFormat.PropertyPickList(const PropertyName: string;
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

Function TTextMatrixWriterFormat.CreateWriter(const [ref] Properties: TPropertySet;
                                              const FileLabel: string;
                                              const MatrixLabels: array of String;
                                              const Size: Integer): TMatrixWriter;
Var
  Header,WriteBOM: Boolean;
  Decimals: Integer;
  Delimiter: TDelimiter;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    // Set encoding
    var Encoding := TEncoding.GetEncoding(ExtendedProperties[EncodingProperty]);
    // Set decimals
    Decimals := ExtendedProperties[DecimalsProperty].ToInteger;
    // Set header
    var ValidHeader := false;
    var HeaderPropertyValue := ExtendedProperties[HeaderProperty];
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
    var DecimalSeparatorPropertyValue := ExtendedProperties[DecimalSeparatorProperty];
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
    var ThousandSeparatorPropertyValue := ExtendedProperties[ThousandSeparatorProperty];
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
    var DelimiterPropertyValue := ExtendedProperties[DelimiterProperty];
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
    var BOMPropertyValue := ExtendedProperties[BOMProperty];
    for var BOM := false to true do
    if SameText(BOM.ToString(TUseBoolStrs.True),BOMPropertyValue) then
    begin
      WriteBOM := BOM;
      ValidBOM := true;
      Break;
    end;
    if not ValidBOM then raise Exception.Create('Invalid bom');
    // Create writer
    result := TTextMatrixWriter.Create(ExtendedProperties.ToPath(FileProperty),MatrixLabels,Size,
                                       TextFormatSettings,Header,Delimiter,Decimals,Encoding,WriteBOM);
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
