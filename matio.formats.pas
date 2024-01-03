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
  SysUtils, Types, PropSet, matio;

Type
  TMatrixFormat = Class
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); virtual;
  strict protected
    Function ExtendProperties(const [ref] Properties: TPropertySet): TPropertySet;
  public
    Const
      FileProperty = 'file';
      FormatProperty = 'format';
    Class Function Format: String; virtual; abstract;
    Class Function Available: Boolean; virtual;
    Class Function FormatProperties(ReadOnly: Boolean = true): TPropertySet;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; virtual;
    Class Function TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
  end;

  TMatrixReaderFormat = Class(TMatrixFormat)
  public
    Class Function HasFormat(const Header: TBytes): Boolean; virtual;
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; virtual; abstract;
  end;

  TMatrixWriterFormat = Class(TMatrixFormat)
  public
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; virtual; abstract;
  end;

  TMatrixFormats = record
  // The record takes ownership of the registered matrix formats
  private
    ReaderFormats: TArray<TMatrixReaderFormat>;
    WriterFormats: TArray<TMatrixWriterFormat>;
  public
    Class Operator Finalize (var Formats: TMatrixFormats);
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
    Function CreateReader(const [ref] Properties: TPropertySet;
                          const Selection: array of Integer): TMatrixReader; overload;
    Function CreateReader(const [ref] Properties: TPropertySet;
                          const Selection: array of String): TMatrixReader; overload;
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
  matio.formats.text, matio.formats.gen4, matio.formats.minutp, matio.formats.omx;

Class Procedure TMatrixFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
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

Class Function TMatrixFormat.Available: Boolean;
begin
  Result := true;
end;

Class Function TMatrixFormat.FormatProperties(ReadOnly: Boolean = true): TPropertySet;
begin
  Result := TPropertySet.Create(ReadOnly);
  Result.Append(FileProperty,'');
  Result.Append(FormatProperty,Format);
  AppendFormatProperties(Result);
end;

Class Function TMatrixFormat.PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean;
begin
  if PropertyName = FormatProperty then
  begin
    Result := true;
    PickList := [Format];
  end else
    Result := false;
end;

Class Function TMatrixFormat.TidyProperties(const [ref] Properties: TPropertySet; ReadOnly: Boolean = true): TPropertySet;
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

Class Function TMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := false;
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
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
  begin
    Result := ReaderFormats[ReaderFormat].CreateReader(Properties);
    Break;
  end else
    raise Exception.Create(Format+'-format unavailable');
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet;
                                     const Selection: array of Integer): TMatrixReader;
begin
  var Reader := CreateReader(Properties);
  if Reader <> nil then
    Result := TMaskedMatrixReader.Create(Reader,Selection)
  else
    Result := nil;
end;

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet;
                                     const Selection: array of String): TMatrixReader;
begin
  var Reader := CreateReader(Properties);
  if Reader <> nil then
    Result := TMaskedMatrixReader.Create(Reader,Selection)
  else
    Result := nil;
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
  begin
    Result := WriterFormats[WriterFormat].CreateWriter(Properties,FileLabel,MatrixLabels,Size);
    Break;
  end else
    raise Exception.Create(Format+'-format unavailable');
end;

Initialization
  MatrixFormats.RegisterFormat(TTextMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TTextMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TMinutpMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TMinutpMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(T4GMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(T4GMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TOMXMatrixWriterFormat.Create);
end.
