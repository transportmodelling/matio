unit matio.formats;

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
  SysUtils, Types, PropSet, matio, matio.text, matio.gen4, matio.minutp, matio.hdf5.omx;

Type
  TMatrixReaderFormat = Class of TMatrixReader;
  TMatrixWriterFormat = Class of TMatrixWriter;

  TMatrixFormats = record
  private
    ReaderFormats: TArray<TMatrixReaderFormat>;
    WriterFormats: TArray<TMatrixWriterFormat>;
  public
    // Register format
    Procedure RegisterFormat(const Format: TMatrixReaderFormat); overload;
    Procedure RegisterFormat(const Format: TMatrixWriterFormat); overload;
    // Query registered formats
    Function RegisteredReaderFormats: TStringDynArray;
    Function ReaderFormat(const Format: string): TMatrixReaderFormat; overload;
    Function ReaderFormat(const Header: TBytes): TMatrixReaderFormat; overload;
    Function RegisteredWriterFormats: TStringDynArray;
    Function WriterFormat(const Format: string): TMatrixWriterFormat;
    // Create matrix reader/writer
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; overload;
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; overload;
  end;

Var
  MatrixFormats: TMatrixFormats;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TMatrixFormats.RegisterFormat(const Format: TMatrixReaderFormat);
begin
  var Count := Length(ReaderFormats);
  SetLength(ReaderFormats,Count+1);
  ReaderFormats[Count] := Format;
end;

Procedure TMatrixFormats.RegisterFormat(const Format: TMatrixWriterFormat);
begin
  var Count := Length(WriterFormats);
  SetLength(WriterFormats,Count+1);
  WriterFormats[Count] := Format;
end;

Function TMatrixFormats.RegisteredReaderFormats: TStringDynArray;
begin
  SetLength(Result,Length(ReaderFormats));
  for var Format := low(ReaderFormats) to high(ReaderFormats) do
  Result[Format] := ReaderFormats[Format].Format;
end;

Function TMatrixFormats.ReaderFormat(const Format: string): TMatrixReaderFormat;
begin
  Result := nil;
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  begin
    Result := ReaderFormats[ReaderFormat];
    Break;
  end;
end;

Function TMatrixFormats.ReaderFormat(const Header: TBytes): TMatrixReaderFormat;
begin
  Result := nil;
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if ReaderFormats[ReaderFormat].HasFormat(Header) then
  begin
    Result := ReaderFormats[ReaderFormat];
    Break;
  end;
end;

Function TMatrixFormats.RegisteredWriterFormats: TStringDynArray;
begin
  SetLength(Result,Length(WriterFormats));
  for var Format := low(WriterFormats) to high(WriterFormats) do
  Result[Format] := WriterFormats[Format].Format;
end;

Function TMatrixFormats.WriterFormat(const Format: string): TMatrixWriterFormat;
begin
  Result := nil;
  for var WriterFormat := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[WriterFormat].Format,Format) then
  begin
    Result := WriterFormats[WriterFormat];
    Break;
  end;
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
begin
  Result := nil;
  var Format := Properties[TMatrixFiler.FormatProperty];
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
  begin
    Result := ReaderFormats[ReaderFormat].Create(Properties);
    Break;
  end else
    raise Exception.Create(Format+'-format unavailable');
end;

Function TMatrixFormats.CreateWriter(const [ref] Properties: TPropertySet;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer): TMatrixWriter;
begin
  Result := nil;
  var Format := Properties[TMatrixFiler.FormatProperty];
  for var WriterFormat := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[WriterFormat].Format,Format) then
  if WriterFormats[WriterFormat].Available then
  begin
    Result := WriterFormats[WriterFormat].Create(Properties,FileLabel,MatrixLabels,Size);
    Break;
  end else
    raise Exception.Create(Format+'-format unavailable');
end;

Initialization
  MatrixFormats.RegisterFormat(TTextMatrixReader);
  MatrixFormats.RegisterFormat(TTextMatrixWriter);
  MatrixFormats.RegisterFormat(TMinutpMatrixReader);
  MatrixFormats.RegisterFormat(TMinutpMatrixWriter);
  MatrixFormats.RegisterFormat(T4GMatrixReader);
  MatrixFormats.RegisterFormat(T4GMatrixWriter);
  MatrixFormats.RegisterFormat(TOMXMatrixWriter);
end.
