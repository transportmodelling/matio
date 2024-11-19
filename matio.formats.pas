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
  SysUtils, Classes, Types, PropSet, matio;

Type
  TMatrixFormat = Class
  strict protected
    Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); virtual;
  strict protected
    Function ExtendProperties(const [ref] Properties: TPropertySet): TPropertySet;
  public
    Const
      FileProperty = 'file';
      FormatProperty = 'format';
    Function Format: String; virtual; abstract;
    Function Available: Boolean; virtual;
    Function FormatProperties(ReadOnly: Boolean = true): TPropertySet;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; virtual;
    Function TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
  end;

  TMatrixReaderFormat = Class(TMatrixFormat)
  // When creating a matrix reader for a selection (by index or name) of matrices,
  // the index to use to access a specific matrix is its index in the selection array.
  public
    Function HasFormat(const FileExtension: String): Boolean; overload; virtual;
    Function HasFormat(const Header: TBytes): Boolean; overload; virtual;
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; overload; virtual; abstract;
    Function CreateReader(const [ref] Properties: TPropertySet; const Selection: array of Integer): TMatrixReader; overload; virtual;
    Function CreateReader(const [ref] Properties: TPropertySet; const Selection: array of String): TMatrixReader; overload; virtual;
  end;

  TMatrixWriterFormat = Class(TMatrixFormat)
  public
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; virtual; abstract;
  end;

  TMatrixFormats = record
  // The record takes ownership of the registered matrix formats.
  private
    Const
      HeaderSize = 75;
    Var
      ReaderFormats: TArray<TMatrixReaderFormat>;
      WriterFormats: TArray<TMatrixWriterFormat>;
  public
    Class Operator Finalize (var Formats: TMatrixFormats);
  public
    // Register format
    Procedure RegisterFormat(const Format: TMatrixReaderFormat); overload;
    Procedure RegisterFormat(const Format: TMatrixWriterFormat); overload;
    // Query registered reader formats
    Function RegisteredReaderFormats: TStringDynArray;
    Function ReaderFormat(const Format: string): TMatrixFormat; overload;
    Function ReaderFormat(const FileName: TFileName): TMatrixFormat; overload;
    Function ReaderFormat(const Header: TBytes): TMatrixFormat; overload;
    // Query registered writer formats
    Function RegisteredWriterFormats: TStringDynArray;
    Function WriterFormat(const Format: string): TMatrixFormat;
    // Create matrix reader
    Function CreateReader(const [ref] Properties: TPropertySet; Ordered: Boolean = true): TMatrixReader; overload;
    Function CreateReader(const [ref] Properties: TPropertySet;
                          const Selection: array of Integer): TMatrixReader; overload;
    Function CreateReader(const [ref] Properties: TPropertySet;
                          const Selection: array of String): TMatrixReader; overload;
    // Create matrix writer
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter;
  end;

Var
  MatrixFormats: TMatrixFormats;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Uses
  matio.formats.text, matio.formats.gen4, matio.formats.minutp, matio.formats.visum, matio.formats.omx;

Procedure TMatrixFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
end;

Function TMatrixFormat.ExtendProperties(const [ref] Properties: TPropertySet): TPropertySet;
Var
  Value: String;
begin
  Result := FormatProperties(false);
  for var Prop := 0 to Result.Count-1 do
  begin
    if Properties.Contains(Result.Names[Prop],Value) then
    Result.ValueFromIndex[Prop] := Value;
  end;
end;

Function TMatrixFormat.Available: Boolean;
begin
  Result := true;
end;

Function TMatrixFormat.FormatProperties(ReadOnly: Boolean = true): TPropertySet;
begin
  Result := TPropertySet.Create(ReadOnly);
  Result.Append(FileProperty,'');
  Result.Append(FormatProperty,Format);
  AppendFormatProperties(Result);
end;

Function TMatrixFormat.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if PropertyName = FormatProperty then
  begin
    Result := true;
    PickList := [Format];
  end else
    Result := false;
end;

Function TMatrixFormat.TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
Var
  Value: String;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var Defaults := FormatProperties;
    Result := TPropertySet.Create(ReadOnly);
    for var Prop := 0 to Defaults.Count-1 do
    begin
      var Name := Defaults.Names[Prop];
      if SameText(Name,FileProperty) or SameText(Name,FormatProperty) then
        Result.Append(Name,Properties[Name])
      else
        if Properties.Contains(Name,Value) then
        if not SameText(Defaults.ValueFromIndex[Prop],Value) then
        Result.Append(Name,Value)
    end;
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Function TMatrixReaderFormat.HasFormat(const FileExtension: String): Boolean;
begin
  Result := false;
end;

Function TMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := false;
end;

Function TMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet; const Selection: array of Integer): TMatrixReader;
begin
  var Reader := CreateReader(Properties);
  if Reader <> nil then
    if Reader.Ordered then
      Result := TMaskedMatrixReader.Create(Reader,Selection)
    else
      begin
        Result := nil;
        Reader.Free;
        raise Exception.Create('Matrix indices within file undefined')
      end
  else
    Result := nil;
end;

Function TMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet; const Selection: array of String): TMatrixReader;
begin
  var Reader := CreateReader(Properties);
  if Reader <> nil then
    Result := TMaskedMatrixReader.Create(Reader,Selection)
  else
    Result := nil;
end;

////////////////////////////////////////////////////////////////////////////////

Class Operator TMatrixFormats.Finalize(var Formats: TMatrixFormats);
begin
  // Destroy reader formats
  for var Format := low(Formats.ReaderFormats) to high(Formats.ReaderFormats) do
    Formats.ReaderFormats[Format].Free;
  // Destroy writer formats
  for var Format := low(Formats.WriterFormats) to high(Formats.WriterFormats) do
    Formats.WriterFormats[Format].Free;
end;

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
  Result := [];
  for var Format := low(ReaderFormats) to high(ReaderFormats) do
  Result := Result + [ReaderFormats[Format].Format];
end;

Function TMatrixFormats.ReaderFormat(const Format: string): TMatrixFormat;
begin
  Result := nil;
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  Exit(ReaderFormats[ReaderFormat]);
end;

Function TMatrixFormats.ReaderFormat(const FileName: TFileName): TMatrixFormat;
Var
  Header: TBytes;
begin
  Result := nil;
  // Determine file format based on file extension
  var FileExtension := ExtractFileExt(FileName);
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if ReaderFormats[ReaderFormat].HasFormat(FileExtension) then
  Exit(ReaderFormats[ReaderFormat]);
  // Determine file format based on file header
  if FileExists(FileName) then
  begin
    var FileStream := TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Header,HeaderSize);
      FileStream.Read(Header,HeaderSize)
    finally
      FileStream.Free;
    end;
    Result := ReaderFormat(Header);
  end;
end;

Function TMatrixFormats.ReaderFormat(const Header: TBytes): TMatrixFormat;
begin
  Result := nil;
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if ReaderFormats[ReaderFormat].HasFormat(Header) then
  Exit(ReaderFormats[ReaderFormat]);
end;

Function TMatrixFormats.RegisteredWriterFormats: TStringDynArray;
begin
  Result := [];
  for var Format := low(WriterFormats) to high(WriterFormats) do
  Result := Result + [WriterFormats[Format].Format];
end;

Function TMatrixFormats.WriterFormat(const Format: string): TMatrixFormat;
begin
  Result := nil;
  for var WriterFormat := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[WriterFormat].Format,Format) then
  Exit(WriterFormats[WriterFormat]);
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet; Ordered: Boolean = true): TMatrixReader;
begin
  Result := nil;
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
  begin
    Result := ReaderFormats[ReaderFormat].CreateReader(Properties);
    if Ordered and (not Result.Ordered) then
    begin
      FreeAndNil(Result);
      raise Exception.Create('Matrix indices within file undefined');
    end;
  end else
    raise Exception.Create(Format+'-format unavailable');
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet;
                                     const Selection: array of Integer): TMatrixReader;
begin
  Result := nil;
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
    Exit(ReaderFormats[ReaderFormat].CreateReader(Properties,Selection))
  else
    raise Exception.Create(Format+'-format unavailable');
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet;
                                     const Selection: array of String): TMatrixReader;
begin
  Result := nil;
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
    Exit(ReaderFormats[ReaderFormat].CreateReader(Properties,Selection))
  else
    raise Exception.Create(Format+'-format unavailable');
end;

Function TMatrixFormats.CreateWriter(const [ref] Properties: TPropertySet;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer): TMatrixWriter;
begin
  Result := nil;
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var WriterFormat := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[WriterFormat].Format,Format) then
  if WriterFormats[WriterFormat].Available then
    Exit(WriterFormats[WriterFormat].CreateWriter(Properties,FileLabel,MatrixLabels,Size))
  else
    raise Exception.Create(Format+'-format unavailable');
end;

Initialization
  MatrixFormats.RegisterFormat(TTextMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TTextMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TMinutpMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TMinutpMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(T4GMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(T4GMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TOMXMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TOMXMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TVisumMatrixReaderFormat.Create);
end.
