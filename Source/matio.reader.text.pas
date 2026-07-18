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

end.
