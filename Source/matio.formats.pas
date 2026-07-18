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
  SysUtils, Classes, Types, KeyVal, matio, matio.reader, matio.writer;

Type
  TMatrixFormat = Class
  strict protected
    Procedure AppendFormatProperties(var Config: TKeyValuePairs); virtual;
  strict protected
    Function ExtendProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
  public
    Const
      FileProperty = 'file';
      FormatProperty = 'format';
    Class Function FileName(const [ref] Config: TKeyValuePairs; Expand: Boolean = true): String;
  public
    Function Format: String; virtual; abstract;
    Function Available: Boolean; virtual;
    Function FormatProperties: TKeyValuePairs;
    Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; virtual;
    Function TidyProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
  end;

  TMatrixReaderFormat = Class(TMatrixFormat)
  // When creating a matrix reader for a selection (by index or name) of matrices,
  // the index to use to access a specific matrix is its index in the selection array.
  public
    Class Function FileExists(const [ref] Config: TKeyValuePairs): Boolean;
  public
    Function HasFormat(const FileExtension: String): Boolean; overload; virtual;
    Function HasFormat(const Header: TBytes): Boolean; overload; virtual;
    Function CreateReader(const [ref] Config: TKeyValuePairs): TMatrixReader; overload; virtual; abstract;
    Function CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of Integer): TMatrixReader; overload; virtual;
    Function CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader; overload; virtual;
  end;

  TMatrixWriterFormat = Class(TMatrixFormat)
  public
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
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
    Function IndexLabels(Count: Integer): TArray<String>;
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
    Function CreateReader(const [ref] Config: TKeyValuePairs; Ordered: Boolean = true): TMatrixReader; overload;
    Function CreateReader(const [ref] Config: TKeyValuePairs;
                          const Selection: array of Integer): TMatrixReader; overload;
    Function CreateReader(const [ref] Config: TKeyValuePairs;
                          const Selection: array of String): TMatrixReader; overload;
    Function CreateEnumReader(const [ref] Config: TKeyValuePairs; Count,Size: Integer; Ordered: Boolean = true): TMatrixEnumReader;
    // Create matrix writer
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
                          const FileLabel: string;
                          const Count,Size: Integer): TMatrixWriter; overload;
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; overload;
    Function CreateEnumWriter(const [ref] Config: TKeyValuePairs;
                              const FileLabel: string;
                              const Count,Size: Integer;
                              FixedRows: Boolean = false): TMatrixEnumWriter; overload;
    Function CreateEnumWriter(const [ref] Config: TKeyValuePairs;
                              const FileLabel: string;
                              const MatrixLabels: array of String;
                              const Size: Integer;
                              FixedRows: Boolean = false): TMatrixEnumWriter; overload;
  end;

Var
  MatrixFormats: TMatrixFormats;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Uses
  matio.formats.text, matio.formats.gen4, matio.formats.minutp, matio.formats.visum,
  matio.formats.omx, matio.formats.cube;

Class Function TMatrixFormat.FileName(const [ref] Config: TKeyValuePairs; Expand: Boolean = true): String;
begin
  if Expand then
    Result := Config.Path(FileProperty)
  else
    Result := Config.Str(FileProperty);
end;

Procedure TMatrixFormat.AppendFormatProperties(var Config: TKeyValuePairs);
begin
end;

Function TMatrixFormat.ExtendProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
Var
  Value: String;
begin
  Result := FormatProperties;
  for var Prop := 0 to Result.Count-1 do
  begin
    if Config.Contains(Result[Prop].Key,Value) then
      Result[Prop] := TKeyValuePair.Create(Result[Prop].Key,Value);
  end;
end;

Function TMatrixFormat.Available: Boolean;
begin
  Result := true;
end;

Function TMatrixFormat.FormatProperties: TKeyValuePairs;
begin
  // Result is a managed type and may alias the caller's destination variable,
  // so it must be cleared before appending
  Result.Clear;
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

Function TMatrixFormat.TidyProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
Var
  Value: String;
begin
  // Result is a managed type and may alias the caller's destination variable,
  // so it must be cleared before appending
  Result.Clear;
  if SameText(Config.Str(FormatProperty),Format) then
  begin
    var Defaults := FormatProperties;
    for var Prop := 0 to Defaults.Count-1 do
    begin
      var Name := Defaults[Prop].Key;
      if SameText(Name,FileProperty) or SameText(Name,FormatProperty) then
        Result.Append(Name,Config.Str(Name))
      else
        if Config.Contains(Name,Value) then
        if not SameText(Defaults[Prop].Value,Value) then
        Result.Append(Name,Value)
    end;
  end else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TMatrixReaderFormat.FileExists(const [ref] Config: TKeyValuePairs): Boolean;
begin
  Result := SysUtils.FileExists(FileName(Config));
end;

Function TMatrixReaderFormat.HasFormat(const FileExtension: String): Boolean;
begin
  Result := false;
end;

Function TMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  Result := false;
end;

Function TMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of Integer): TMatrixReader;
begin
  var Reader := CreateReader(Config);
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

Function TMatrixReaderFormat.CreateReader(const [ref] Config: TKeyValuePairs; const Selection: array of String): TMatrixReader;
begin
  var Reader := CreateReader(Config);
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

Function TMatrixFormats.IndexLabels(Count: Integer): TArray<String>;
begin
  SetLength(Result,Count);
  for var Index := 0 to Count-1 do Result[Index] := (Index+1).ToString;
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

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs; Ordered: Boolean = true): TMatrixReader;
begin
  Result := nil;
  var Format := Config.Str(TMatrixFormat.FormatProperty);
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
  begin
    Result := ReaderFormats[ReaderFormat].CreateReader(Config);
    if Ordered and (not Result.Ordered) then
    begin
      FreeAndNil(Result);
      raise Exception.Create('Matrix indices within file undefined');
    end;
  end else
    Break;
end;

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of Integer): TMatrixReader;
begin
  Result := nil;
  var Format := Config.Str(TMatrixFormat.FormatProperty);
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
    Exit(ReaderFormats[ReaderFormat].CreateReader(Config,Selection))
  else
    Break;
end;

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of String): TMatrixReader;
begin
  Result := nil;
  var Format := Config.Str(TMatrixFormat.FormatProperty);
  for var ReaderFormat := low(ReaderFormats) to high(ReaderFormats) do
  if SameText(ReaderFormats[ReaderFormat].Format,Format) then
  if ReaderFormats[ReaderFormat].Available then
    Exit(ReaderFormats[ReaderFormat].CreateReader(Config,Selection))
  else
    Break;
end;

Function TMatrixFormats.CreateEnumReader(const [ref] Config: TKeyValuePairs; Count,Size: Integer; Ordered: Boolean = true): TMatrixEnumReader;
begin
  var Reader := CreateReader(Config,Ordered);
  if Reader <> nil then
    Result := TMatrixEnumReader.Create(Reader,Count,Size,true)
  else
    raise Exception.Create('Error creating matrix reader');
end;

Function TMatrixFormats.CreateWriter(const [ref] Config: TKeyValuePairs;
                                     const FileLabel: string;
                                     const Count,Size: Integer): TMatrixWriter;
begin
  Result := CreateWriter(Config,FileLabel,IndexLabels(Count),Size);
end;

Function TMatrixFormats.CreateWriter(const [ref] Config: TKeyValuePairs;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer): TMatrixWriter;
begin
  Result := nil;
  var Format := Config.Str(TMatrixFormat.FormatProperty);
  for var WriterFormat := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[WriterFormat].Format,Format) then
  if WriterFormats[WriterFormat].Available then
    Exit(WriterFormats[WriterFormat].CreateWriter(Config,FileLabel,MatrixLabels,Size))
  else
    Break;
end;

Function TMatrixFormats.CreateEnumWriter(const [ref] Config: TKeyValuePairs;
                                         const FileLabel: string;
                                         const Count,Size: Integer;
                                         FixedRows: Boolean = false): TMatrixEnumWriter;
begin
  Result := CreateEnumWriter(Config,FileLabel,IndexLabels(Count),Size,FixedRows);
end;

Function TMatrixFormats.CreateEnumWriter(const [ref] Config: TKeyValuePairs;
                                         const FileLabel: string;
                                         const MatrixLabels: array of String;
                                         const Size: Integer;
                                         FixedRows: Boolean = false): TMatrixEnumWriter;
begin
  var Writer := CreateWriter(Config,FileLabel,MatrixLabels,Size);
  if Writer <> nil then
    Result := TMatrixEnumWriter.Create(Writer,FixedRows,true)
  else
    raise Exception.Create('Error creating matrix writer');
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
  MatrixFormats.RegisterFormat(TCubeMatrixReaderFormat.Create);
  MatrixFormats.RegisterFormat(TCubeMatrixWriterFormat.Create);
  MatrixFormats.RegisterFormat(TVisumMatrixReaderFormat.Create);
end.
