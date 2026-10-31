unit matio.reader.text;

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
  Classes, SysUtils, Types, Parse, matio, matio.row, matio.reader;

Type
  TTextMatrixReader = Class(TMatrixReader)
  private
    LineCount,NextRow,NextCol,NValues: Integer;
    Values: TArray<Float64>;
    Parser: TStringParser;
    TextFormatSettings: TFormatSettings;
    StreamReader: TStreamReader;
    Procedure CreateStreamReader(const Encoding: TEncoding);
    Procedure ReadHeader;
    Procedure ReadFirstLine(const Header: Boolean);
    Procedure SetNextRow(const Row: Integer);
    Procedure SetNextColumn(const Column: Integer);
    Procedure ParseLine;
    Procedure Proceed;
    Procedure NextLine;
    Procedure ZeroizeColumns(const Rows: TCustomMatrixRows; const FirstCol,LastCol: Integer);
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

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

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
  TextFormatSettings.DecimalSeparator := FormatSettings.DecimalSeparator;
  TextFormatSettings.ThousandSeparator := FormatSettings.ThousandSeparator;
  CreateStreamReader(Encoding);
  ReadFirstLine(Header);
end;

Procedure TTextMatrixReader.CreateStreamReader(const Encoding: TEncoding);
begin
  if Encoding <> nil then
    StreamReader := TStreamReader.Create(FileStream,Encoding,true,BufferSize)
  else
    StreamReader := TStreamReader.Create(FileStream,TEncoding.ASCII,true,BufferSize);
end;

Procedure TTextMatrixReader.ReadHeader;
begin
  Inc(LineCount);
  Parser.ReadLine(StreamReader);
  if Parser.Count > 2 then
  begin
    SetCount(Parser.Count-2);
    for var Matrix := 0 to Count-1 do SetMatrixLabels(Matrix,Parser[Matrix+2]);
    NextLine;
  end else
    raise Exception.Create('Missing matrix header(s)');
end;

Procedure TTextMatrixReader.ReadFirstLine(const Header: Boolean);
begin
  NextRow := -1;
  NextCol := -1;
  if Header then ReadHeader else
  begin
    Proceed;
    SetCount(Nvalues);
  end;
end;

Procedure TTextMatrixReader.SetNextRow(const Row: Integer);
begin
  if Row > Size then SetSize(Row);
  if Row > NextRow then NextCol := -1;
  if Row >= NextRow then NextRow := Row else
  raise Exception.Create('Invalid sorting at line ' + LineCount.ToString);
end;

Procedure TTextMatrixReader.SetNextColumn(const Column: Integer);
begin
  if Column > Size then SetSize(Column);
  if Column > NextCol then NextCol := Column else
  raise Exception.Create('Invalid sorting at line ' + LineCount.ToString);
end;

Procedure TTextMatrixReader.ParseLine;
begin
  NValues := Parser.Count-2;
  SetNextRow(Parser.Int[0]);
  SetNextColumn(Parser[1]);
  Values := Parser.ToFloatArray(TextFormatSettings,2,NValues);
end;

Procedure TTextMatrixReader.Proceed;
begin
  if not StreamReader.EndOfStream then
  begin
    Inc(LineCount);
    Parser.ReadLine(StreamReader);
    if Parser.Count > 2 then ParseLine else
    if (Parser.Count = 0) and StreamReader.EndOfStream then NValues := 0 else
    raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
  end else NValues := 0;
end;

Procedure TTextMatrixReader.NextLine;
// Proceeds to the next line and checks its number of values
begin
  Proceed;
  if (NValues <> 0) and (NValues <> Count) then
  raise Exception.Create('Invalid number of columns at line ' + LineCount.ToString);
end;

Procedure TTextMatrixReader.ZeroizeColumns(const Rows: TCustomMatrixRows; const FirstCol,LastCol: Integer);
begin
  for var Col := FirstCol to LastCol do
  for var Matrix := 0 to Count-1 do
  Rows[Matrix,Col] := 0;
end;

Procedure TTextMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
begin
  var LastCol := -1;
  while(NValues > 0) and (NextRow <= CurrentRow+1) do
  begin
    if NextRow = CurrentRow+1 then
    begin
      // Zeroize skipped matrix cells
      ZeroizeColumns(Rows,LastCol+1,NextCol-2);
      // Set matrix cells current line
      for var Matrix := 0 to Count-1 do Rows[Matrix,NextCol-1] := Values[Matrix];
      LastCol := NextCol-1;
    end;
    NextLine;
  end;
  // Zeroize skipped matrix cells
  ZeroizeColumns(Rows,LastCol+1,Size-1);
end;

Destructor TTextMatrixReader.Destroy;
begin
  StreamReader.Free;
  inherited Destroy;
end;

end.
