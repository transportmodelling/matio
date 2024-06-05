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
  public
    Function HasFormat(const FileExtension: String): Boolean; overload; virtual;
    Function HasFormat(const Header: TBytes): Boolean; overload; virtual;
  end;

  TIndexedMatrixReaderFormat = Class(TMatrixReaderFormat)
  // Matrices are accessed by their index.
  // Matrices may or may not be labeled, so access by label may or may not be possible.
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; virtual; abstract;
  end;

  TLabeledMatrixReaderFormat = Class(TMatrixReaderFormat)
  // Matrices are accessed by their label.
  // By providing a list of labels for the matrices that should be read, they are also accessible by (list) index.
  public
    Function CreateReader(const [ref] Properties: TPropertySet; const Selection: array of String): TMatrixReader; virtual; abstract;
  end;

  TMatrixWriterFormat = Class(TMatrixFormat)
  public
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; virtual; abstract;
  end;

  TMatrixFormats = record
  // The matrix readers created are always index based.
  // For label based formats, a list of labels for the matrices to be read must
  // be passed to the CreateReader-method, so the matrices can be accessed by their (list) index.
  // The record takes ownership of the registered matrix formats.
  private
    IndexedReaderFormats: TArray<TIndexedMatrixReaderFormat>;
    LabeledReaderFormats: TArray<TLabeledMatrixReaderFormat>;
    WriterFormats: TArray<TMatrixWriterFormat>;
  public
    Class Operator Finalize (var Formats: TMatrixFormats);
  public
    // Register format
    Procedure RegisterFormat(const Format: TIndexedMatrixReaderFormat); overload;
    Procedure RegisterFormat(const Format: TLabeledMatrixReaderFormat); overload;
    Procedure RegisterFormat(const Format: TMatrixWriterFormat); overload;
    // Query registered formats
    Function RegisteredReaderFormats(ByIndex,ByLabel: Boolean): TStringDynArray;
    Function ReaderFormat(const Format: string;
                          const IndexedFormats: Boolean = true;
                          const LabeledFormats: Boolean= true): TMatrixFormat; overload;
    Function ReaderFormat(const FileName: TFileName;
                          const IndexedFormats: Boolean = true;
                          const LabeledFormats: Boolean= true): TMatrixFormat; overload;
    Function ReaderFormat(const Header: TBytes;
                          const IndexedFormats: Boolean = true;
                          const LabeledFormats: Boolean= true): TMatrixFormat; overload;
    Function RegisteredWriterFormats: TStringDynArray;
    Function WriterFormat(const Format: string): TMatrixFormat;
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

////////////////////////////////////////////////////////////////////////////////

Class Operator TMatrixFormats.Finalize(var Formats: TMatrixFormats);
begin
  // Destroy indexed reader formats
  for var Format := low(Formats.IndexedReaderFormats) to high(Formats.IndexedReaderFormats) do
    Formats.IndexedReaderFormats[Format].Free;
  // Destroy labeled reader formats
  for var Format := low(Formats.LabeledReaderFormats) to high(Formats.LabeledReaderFormats) do
    Formats.LabeledReaderFormats[Format].Free;
  // Destroy writer formats
  for var Format := low(Formats.WriterFormats) to high(Formats.WriterFormats) do
    Formats.WriterFormats[Format].Free;
end;

Procedure TMatrixFormats.RegisterFormat(const Format: TIndexedMatrixReaderFormat);
begin
  var Count := Length(IndexedReaderFormats);
  SetLength(IndexedReaderFormats,Count+1);
  IndexedReaderFormats[Count] := Format;
end;

Procedure TMatrixFormats.RegisterFormat(const Format: TLabeledMatrixReaderFormat);
begin
  var Count := Length(LabeledReaderFormats);
  SetLength(LabeledReaderFormats,Count+1);
  LabeledReaderFormats[Count] := Format;
end;

Procedure TMatrixFormats.RegisterFormat(const Format: TMatrixWriterFormat);
begin
  var Count := Length(WriterFormats);
  SetLength(WriterFormats,Count+1);
  WriterFormats[Count] := Format;
end;

Function TMatrixFormats.RegisteredReaderFormats(ByIndex,ByLabel: Boolean): TStringDynArray;
begin
  Result := [];
  // Add index matrix formats
  if ByIndex then
  for var Format := low(IndexedReaderFormats) to high(IndexedReaderFormats) do
  Result := Result + [IndexedReaderFormats[Format].Format];
  // Add labeled matrix formats
  if ByLabel then
  for var Format := low(LabeledReaderFormats) to high(LabeledReaderFormats) do
  Result := Result + [LabeledReaderFormats[Format].Format];
end;

Function TMatrixFormats.ReaderFormat(const Format: string;
                                     const IndexedFormats: Boolean = true;
                                     const LabeledFormats: Boolean= true): TMatrixFormat;
begin
  Result := nil;
  // Indexed reader formats
  if IndexedFormats then
  for var ReaderFormat := low(IndexedReaderFormats) to high(IndexedReaderFormats) do
  if SameText(IndexedReaderFormats[ReaderFormat].Format,Format) then
  Exit(IndexedReaderFormats[ReaderFormat]);
  // Labeled reader formats
  if LabeledFormats then
  for var ReaderFormat := low(LabeledReaderFormats) to high(LabeledReaderFormats) do
  if SameText(LabeledReaderFormats[ReaderFormat].Format,Format) then
  Exit(LabeledReaderFormats[ReaderFormat]);
end;

Function TMatrixFormats.ReaderFormat(const FileName: TFileName;
                                     const IndexedFormats: Boolean = true;
                                     const LabeledFormats: Boolean= true): TMatrixFormat;
begin
  Result := nil;
  // Get file extension
  var FileExtension := ExtractFileExt(FileName);
  // Indexed reader formats
  if IndexedFormats then
  for var ReaderFormat := low(IndexedReaderFormats) to high(IndexedReaderFormats) do
  if IndexedReaderFormats[ReaderFormat].HasFormat(FileExtension) then
  Exit(IndexedReaderFormats[ReaderFormat]);
  // Labeled reader formats
  if LabeledFormats then
  for var ReaderFormat := low(LabeledReaderFormats) to high(LabeledReaderFormats) do
  if LabeledReaderFormats[ReaderFormat].HasFormat(FileExtension) then
  Exit(LabeledReaderFormats[ReaderFormat]);
end;

Function TMatrixFormats.ReaderFormat(const Header: TBytes;
                                     const IndexedFormats: Boolean = true;
                                     const LabeledFormats: Boolean= true): TMatrixFormat;
begin
  Result := nil;
  // Indexed reader formats
  if IndexedFormats then
  for var ReaderFormat := low(IndexedReaderFormats) to high(IndexedReaderFormats) do
  if IndexedReaderFormats[ReaderFormat].HasFormat(Header) then
  Exit(IndexedReaderFormats[ReaderFormat]);
  // Labeled reader formats
  if LabeledFormats then
  for var ReaderFormat := low(LabeledReaderFormats) to high(LabeledReaderFormats) do
  if LabeledReaderFormats[ReaderFormat].HasFormat(Header) then
  Exit(LabeledReaderFormats[ReaderFormat]);
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

Function TMatrixFormats.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
begin
  Result := nil;
  var Format := Properties[TMatrixFormat.FormatProperty];
  for var ReaderFormat := low(IndexedReaderFormats) to high(IndexedReaderFormats) do
  if SameText(IndexedReaderFormats[ReaderFormat].Format,Format) then
  if IndexedReaderFormats[ReaderFormat].Available then
    Exit(IndexedReaderFormats[ReaderFormat].CreateReader(Properties))
  else
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
  if Reader = nil then
  begin
    Result := nil;
    // Create labeled matrix reader
    var Format := Properties[TMatrixFormat.FormatProperty];
    for var ReaderFormat := low(LabeledReaderFormats) to high(LabeledReaderFormats) do
    if SameText(LabeledReaderFormats[ReaderFormat].Format,Format) then
    if LabeledReaderFormats[ReaderFormat].Available then
      Exit(LabeledReaderFormats[ReaderFormat].CreateReader(Properties,Selection))
    else
      raise Exception.Create(Format+'-format unavailable');
  end else
    Result := TMaskedMatrixReader.Create(Reader,Selection);
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
