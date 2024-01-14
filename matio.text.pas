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
  Classes, SysUtils, Math, Types, Parse, ArrayBld, matio;

Type
  TTextMatrixReader = Class(TMatrixReader)
  private
    LineCount,NextRow,NextCol,NValues: Integer;
    Values: TArray<Float64>;
    Parser: TStringParser;
    TextFormatSettings: TFormatSettings;
    StreamReader: TStreamReader;
    Procedure Proceed;
  protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
  public
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
    Procedure Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows); override;
  public
    Class Constructor Create;
  public
    Class Property RowLabel: String read FRowLabel write SetRowLabel;
    Class Property ColumnLabel: String read FColumnLabel write SetColumnLabel;
  public
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
  Delimiters: array[TDelimiter] of Char = (',',#9,';',#9);

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

Procedure TTextMatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
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
