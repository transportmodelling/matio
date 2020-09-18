unit matio.text;

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
  System.Classes,System.SysUtils,System.Math,System.Types,Parse,ArrayBld,PropSet,matio;

Type
  TTextMatrixReader = Class(TMatrixReader)
  private
    LineCount,NextRow,NextCol,NValues: Integer;
    Values: TArray<Float64>;
    Parser: TStringParser;
    TextFormatSettings: TFormatSettings;
    StreamReader: TStreamReader;
    Procedure Proceed;
  strict protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Constructor Create(const Properties: TPropertySet); overload; override;
    Constructor Create(const FileName: String;
                       const Header: Boolean = true;
                       const Delimiter: TDelimiter = Tab;
                       const Encoding: TEncoding = nil); overload;
    Constructor Create(const FileName: String;
                       const FormatSettings: TFormatSettings;
                       const Header: Boolean = true;
                       const Delimiter: TDelimiter = Tab;
                       const Encoding: TEncoding = nil); overload;
    Destructor Destroy; override;
  end;

  TTextMatrixWriter = Class(TMatrixWriter)
  private
    Class Var
      FRowLabel,FColumnLabel: String;
    Var
      Delim: Char;
      FloatFormat: String;
      TextFormatSettings: TFormatSettings;
      StreamWriter: TStreamWriter;
    Class Procedure SetRowLabel(RowLabel: String); static;
    Class Procedure SetColumnLabel(ColumnLabel: String); static;
  strict protected
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Constructor Create;
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Class Property RowLabel: String read FRowLabel write SetRowLabel;
    Class Property ColumnLabel: String read FColumnLabel write SetColumnLabel;
  public
    Constructor Create(const Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; override;
    Constructor Create(const FileName: String;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const Header: Boolean = true;
                       const Delimiter: TDelimiter = Tab;
                       const Decimals: Integer = 3;
                       const Encoding: TEncoding = nil;
                       const WriteByteOrderMark: Boolean = false); overload;
    Constructor Create(const FileName: String;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const FormatSettings: TFormatSettings;
                       const Header: Boolean = true;
                       const Delimiter: TDelimiter = Tab;
                       const Decimals: Integer = 3;
                       const Encoding: TEncoding = nil;
                       const WriteByteOrderMark: Boolean = false); overload;
    Destructor Destroy; override;
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
  Delimiters: array[TDelimiter] of Char = (',',#9,';',#9);
  BOMProperty = 'bom';


Class Function TTextMatrixReader.Format: String;
begin
  Result := 'txt';
end;

Class Procedure TTextMatrixReader.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(EncodingProperty,'ascii');
  Properties.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Properties.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Properties.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Properties.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
end;

Class Function TTextMatrixReader.PropertyPickList(const PropertyName: string;
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

Constructor TTextMatrixReader.Create(const Properties: TPropertySet);
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
    Create(ExtendedProperties.ToPath(FileProperty),TextFormatSettings,Header,Delimiter,Encoding);
  end else
    raise Exception.Create('Invalid format-property');
end;

Constructor TTextMatrixReader.Create(const FileName: String;
                                     const Header: Boolean = true;
                                     const Delimiter: TDelimiter = Tab;
                                     const Encoding: TEncoding = nil);
begin
  Create(FileName,System.SysUtils.FormatSettings,Header,Delimiter,Encoding);
end;

Constructor TTextMatrixReader.Create(const FileName: String;
                                     const FormatSettings: TFormatSettings;
                                     const Header: Boolean = true;
                                     const Delimiter: TDelimiter = Tab;
                                     const Encoding: TEncoding = nil);
begin
  inherited Create(FileName);
  Parser := TStringParser.Create(Delimiter);
  // Set format settings
  TextFormatSettings.DecimalSeparator := FormatSettings.DecimalSeparator;
  TextFormatSettings.ThousandSeparator := FormatSettings.ThousandSeparator;
  // Create reader
  if Encoding <> nil then
    StreamReader := TStreamReader.Create(FileStream,Encoding,true,BufferSize)
  else
    StreamReader := TStreamReader.Create(FileStream,TEncoding.ASCII,true,BufferSize);
  // Read first line
  NextRow := -1;
  NextCol := -1;
  if Header then
  begin
    Inc(LineCount);
    Parser.ReadLine(StreamReader);
    if Parser.Count > 2 then
    begin
      SetCount(Parser.Count-2);
      for var Matrix := 0 to Count-1 do SetMatrixLabels(Matrix,Parser[Matrix+2]);
      Proceed;
      if (NValues <> 0) and (NValues <> Count) then
      raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
    end else
      raise Exception.Create('Missing matrix header(s)');
  end else
  begin
    Proceed;
    SetCount(Nvalues);
  end;
end;

Procedure TTextMatrixReader.Proceed;
begin
  if not StreamReader.EndOfStream then
  begin
    Inc(LineCount);
    Parser.ReadLine(StreamReader);
    if Parser.Count > 0 then
    begin
      if Parser.Count > 2 then
      begin
        NValues := Parser.Count-2;
        var Next := Parser.Int[0];
        if Next > Size then SetSize(Next);
        if Next > NextRow then NextCol := -1;
        if Next >= NextRow then
        begin
          NextRow := Next;
          Next := Parser[1];
          if Next > Size then SetSize(Next);
          if Next > NextCol then
          begin
            NextCol := Next;
            Values := Parser.ToFloatArray(TextFormatSettings,2,NValues);
          end else raise Exception.Create('Invalid sorting at line ' + LineCount.ToString);
        end else raise Exception.Create('Invalid sorting at line ' + LineCount.ToString);
      end else raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
    end else
    if StreamReader.EndOfStream then NValues := 0 else
    raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
  end else NValues := 0;
end;

Procedure TTextMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  var LastCol := -1;
  while(NValues > 0) and (NextRow <= CurrentRow+1) do
  begin
    if NextRow = CurrentRow+1 then
    begin
      // Zeroize skipped matrix cells
      if LastCol < NextCol-2 then
      for var Matrix := 0 to Count-1 do
      for var Col := LastCol+1 to NextCol-2 do
      Rows[Matrix,Col] := 0;
      // Set matrix cells current line
      for var Matrix := 0 to Count-1 do Rows[Matrix,NextCol-1] := Values[Matrix];
      LastCol := NextCol-1;
    end;
    // Proceed to next line
    Proceed;
    if (NValues <> 0) and (NValues <> Count) then
    raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
  end;
  // Zeroize skipped matrix cells
  if Size > 0 then
  for var Col := LastCol+1 to Size-1 do
  for var Matrix := 0 to Count-1 do
  Rows[Matrix,Col] := 0;
end;

Destructor TTextMatrixReader.Destroy;
begin
  StreamReader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Class Constructor TTextMatrixWriter.Create;
begin
  RowLabel := 'Row';
  ColumnLabel := 'Column';
end;

Class Procedure TTextMatrixWriter.SetRowLabel(RowLabel: String);
begin
  RowLabel := Trim(RowLabel);
  if RowLabel <> '' then FRowLabel := RowLabel else
  raise Exception.Create('Header label cannot be empty');
end;

Class Procedure TTextMatrixWriter.SetColumnLabel(ColumnLabel: String);
begin
  ColumnLabel := Trim(ColumnLabel);
  if ColumnLabel <> '' then FColumnLabel := ColumnLabel else
  raise Exception.Create('Header label cannot be empty');
end;

Class Function TTextMatrixWriter.Format: String;
begin
  Result := 'txt';
end;

Class Procedure TTextMatrixWriter.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(EncodingProperty,'ascii');
  Properties.Append(DelimiterProperty,DelimiterOptions[Tab]);
  Properties.Append(HeaderProperty,true.ToString(TUseBoolStrs.True));
  Properties.Append(DecimalSeparatorProperty,SeparatorOptions[1]);
  Properties.Append(DecimalsProperty,'3');
  Properties.Append(ThousandSeparatorProperty,SeparatorOptions[0]);
  Properties.Append(BOMProperty,false.ToString(TUseBoolStrs.True));
end;

Class Function TTextMatrixWriter.PropertyPickList(const PropertyName: string;
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

Constructor TTextMatrixWriter.Create(const Properties: TPropertySet;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer);
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
    Create(ExtendedProperties.ToPath(FileProperty),MatrixLabels,Size,
           TextFormatSettings,Header,Delimiter,Decimals,Encoding,WriteBOM);
  end else
    raise Exception.Create('Invalid format-property');
end;

Constructor TTextMatrixWriter.Create(const FileName: String;
                                     const MatrixLabels: array of String;
                                     const Size: Integer;
                                     const Header: Boolean = true;
                                     const Delimiter: TDelimiter = Tab;
                                     const Decimals: Integer = 3;
                                     const Encoding: TEncoding = nil;
                                     const WriteByteOrderMark: Boolean = false);
begin
  Create(FileName,MatrixLabels,Size,System.SysUtils.FormatSettings,
         Header,Delimiter,Decimals,Encoding,WriteByteOrderMark);
end;

Constructor TTextMatrixWriter.Create(const FileName: String;
                                     const MatrixLabels: array of String;
                                     const Size: Integer;
                                     const FormatSettings: TFormatSettings;
                                     const Header: Boolean = true;
                                     const Delimiter: TDelimiter = Tab;
                                     const Decimals: Integer = 3;
                                     const Encoding: TEncoding = nil;
                                     const WriteByteOrderMark: Boolean = false);
begin
  inherited Create(FileName,Length(MatrixLabels),Size);
  // Create writer
  if Encoding <> nil then
    StreamWriter := TStreamWriter.Create(FileStream,Encoding,BufferSize)
  else
    StreamWriter := TStreamWriter.Create(FileStream,TEncoding.ASCII,BufferSize);
  if not WriteByteOrderMark then FileStream.Size := 0;
  // Set format settings
  TextFormatSettings.DecimalSeparator := FormatSettings.DecimalSeparator;
  TextFormatSettings.ThousandSeparator := FormatSettings.ThousandSeparator;
  // Set delimiter
  Delim := Delimiters[Delimiter];
  // Set float format
  FloatFormat := '0';
  if Decimals > 0 then
  begin
    FloatFormat := FloatFormat + '.';
    for var Decimal := 1 to Decimals do FloatFormat := FloatFormat + '#';
  end;
  // Write header
  if Header then
  begin
    StreamWriter.Write(RowLabel);
    StreamWriter.Write(Delim+ColumnLabel);
    for var Matrix := low(MatrixLabels) to high(MatrixLabels) do StreamWriter.Write(Delim+MatrixLabels[Matrix]);
    StreamWriter.WriteLine;
  end;
end;

Procedure TTextMatrixWriter.Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  for var Column := 0 to Size-1 do
  begin
    var Line := '';
    var Empty := true;
    for var Matrix := 0 to Count-1 do
    begin
      if Rows[Matrix,Column] <> 0.0 then
      begin
        Empty := false;
        Line := Line + Delim + FormatFloat(FloatFormat,Rows[Matrix,Column],TextFormatSettings);
      end else Line := Line + Delim + '0';
    end;
    if not Empty then
    begin
      StreamWriter.Write(CurrentRow+1);
      StreamWriter.Write(Delim);
      StreamWriter.Write(Column+1);
      StreamWriter.WriteLine(Line);
    end;
  end;
end;

Destructor TTextMatrixWriter.Destroy;
begin
  StreamWriter.Free;
  inherited Destroy;
end;

end.
