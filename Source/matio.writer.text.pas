unit matio.writer.text;

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
  Classes, SysUtils, Types, Parse, matio, matio.writer;

Type
  TTextMatrixWriterSettings = record
    FormatSettings: TFormatSettings;
    Header: Boolean;
    Delimiter: TDelimiter;
    Decimals: Integer;
    Encoding: TEncoding;
    WriteByteOrderMark: Boolean;
    Class Operator Initialize(out Settings: TTextMatrixWriterSettings);
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
    Procedure CreateStreamWriter(const Settings: TTextMatrixWriterSettings);
    Procedure SetFloatFormat(const Decimals: Integer);
    Procedure WriteHeader(const MatrixLabels: array of String);
    Function ColumnCells(const Rows: TVirtualMatrixRows; const Column: Integer; out Cells: String): Boolean;
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
                       const Size: Integer); overload;
    Constructor Create(const FileName: String;
                       const MatrixLabels: array of String;
                       const Size: Integer;
                       const Settings: TTextMatrixWriterSettings); overload;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  Delimiters: array[TDelimiter] of Char = (',',#9,';',#9);

Class Operator TTextMatrixWriterSettings.Initialize(out Settings: TTextMatrixWriterSettings);
begin
  Settings.FormatSettings := System.SysUtils.FormatSettings;
  Settings.Header := true;
  Settings.Delimiter := Tab;
  Settings.Decimals := 3;
  Settings.Encoding := nil;
  Settings.WriteByteOrderMark := false;
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
                                     const Size: Integer);
Var
  Settings: TTextMatrixWriterSettings;
begin
  Create(FileName,MatrixLabels,Size,Settings);
end;

Constructor TTextMatrixWriter.Create(const FileName: String;
                                     const MatrixLabels: array of String;
                                     const Size: Integer;
                                     const Settings: TTextMatrixWriterSettings);
begin
  inherited Create(FileName,Length(MatrixLabels),Size);
  CreateStreamWriter(Settings);
  TextFormatSettings.DecimalSeparator := Settings.FormatSettings.DecimalSeparator;
  TextFormatSettings.ThousandSeparator := Settings.FormatSettings.ThousandSeparator;
  Delim := Delimiters[Settings.Delimiter];
  SetFloatFormat(Settings.Decimals);
  if Settings.Header then WriteHeader(MatrixLabels);
end;

Procedure TTextMatrixWriter.CreateStreamWriter(const Settings: TTextMatrixWriterSettings);
begin
  if Settings.Encoding <> nil then
    StreamWriter := TStreamWriter.Create(FileStream,Settings.Encoding,BufferSize)
  else
    StreamWriter := TStreamWriter.Create(FileStream,TEncoding.ASCII,BufferSize);
  if not Settings.WriteByteOrderMark then FileStream.Size := 0;
  // The preamble has reached the stream, so the writer can buffer from here on
  StreamWriter.AutoFlush := false;
end;

Procedure TTextMatrixWriter.SetFloatFormat(const Decimals: Integer);
begin
  FloatFormat := '0';
  if Decimals > 0 then
  begin
    FloatFormat := FloatFormat + '.';
    for var Decimal := 1 to Decimals do FloatFormat := FloatFormat + '#';
  end;
end;

Procedure TTextMatrixWriter.WriteHeader(const MatrixLabels: array of String);
begin
  StreamWriter.Write(RowLabel);
  StreamWriter.Write(Delim+ColumnLabel);
  for var Matrix := low(MatrixLabels) to high(MatrixLabels) do StreamWriter.Write(Delim+MatrixLabels[Matrix]);
  StreamWriter.WriteLine;
end;

Function TTextMatrixWriter.ColumnCells(const Rows: TVirtualMatrixRows; const Column: Integer; out Cells: String): Boolean;
// Returns whether the column holds a value other than zero
begin
  Result := false;
  Cells := '';
  for var Matrix := 0 to Count-1 do
  begin
    if Rows[Matrix,Column] <> 0.0 then
    begin
      Result := true;
      Cells := Cells + Delim + FormatFloat(FloatFormat,Rows[Matrix,Column],TextFormatSettings);
    end else Cells := Cells + Delim + '0';
  end;
end;

Procedure TTextMatrixWriter.Write(const CurrentRow: Integer; const Rows: TVirtualMatrixRows);
Var
  Cells: String;
begin
  for var Column := 0 to Size-1 do
  if ColumnCells(Rows,Column,Cells) then
  StreamWriter.WriteLine(IntToStr(CurrentRow+1)+Delim+IntToStr(Column+1)+Cells);
end;

Destructor TTextMatrixWriter.Destroy;
begin
  StreamWriter.Free;
  inherited Destroy;
end;

end.
