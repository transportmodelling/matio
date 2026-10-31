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
  SysUtils, Classes, Types, KeyVal, ArrBld, matio, matio.reader, matio.writer;

Type
  TMatrixFormat = Class
  // A format names itself and describes its properties in its constructor.
  // A format with a parameterless constructor overrides Format and FormatName.
  private
    Type
      TFormatProperty = record
        Key,DefaultValue,Caption: String;
        PickList: TStringDynArray;
      end;
    Var
      FFormat,FFormatName: String;
      Properties: TArray<TFormatProperty>;
    Function FindProperty(const PropertyKey: string; out Found: TFormatProperty): Boolean;
    Procedure AppendTidyProperty(const [ref] Config: TKeyValuePairs; const Default: TKeyValuePair; var Tidied: TKeyValuePairs);
  strict protected
    Constructor Create(const Format,FormatName: String); overload;
    Procedure AddProperty(const Key,DefaultValue,Caption: String; const PickList: TStringDynArray = nil);
    Function OptionIndex(const PropertyValue: String; const Options: array of String;
                         const PropertyName: String; const MinIndex: Integer = 0): Integer;
    Function BoolPropertyValue(const PropertyValue,PropertyName: String): Boolean;
    Function ExtendProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
    Procedure CheckFormat(const [ref] Config: TKeyValuePairs);
  public
    Const
      FileProperty = 'file';
      FormatProperty = 'format';
    Class Function FileName(const [ref] Config: TKeyValuePairs; Expand: Boolean = true): String;
  public
    Function Format: String; virtual;
    Function FormatName: String; virtual;
    Function Available: Boolean; virtual;
    Function FormatProperties: TKeyValuePairs;
    Function PropertyLabel(const PropertyKey: string): String; virtual;
    Function PropertyPickList(const PropertyKey: string; out PickList: TStringDynArray): Boolean; virtual;
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

  TNewMatrixFile = record
    FileLabel: String;
    MatrixLabels: TArray<String>;
    Size: Integer;
  end;

  TCustomMatrixWriterFormat = Class(TMatrixWriterFormat)
  // Checks the format property of the configuration and gathers what describes
  // the new file, so that a format only has to create its writer.
  strict protected
    Function NewWriter(const [ref] Config: TKeyValuePairs; const NewFile: TNewMatrixFile): TMatrixWriter; virtual; abstract;
  public
    Function CreateWriter(const [ref] Config: TKeyValuePairs;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; override;
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
    Function FindReaderFormat(const Matches: TFunc<TMatrixReaderFormat,Boolean>): TMatrixReaderFormat;
    Function NamedReaderFormat(const Format: string): TMatrixReaderFormat;
    Function NamedWriterFormat(const Format: string): TMatrixWriterFormat;
    Function AvailableReaderFormat(const [ref] Config: TKeyValuePairs): TMatrixReaderFormat;
    Function AvailableWriterFormat(const [ref] Config: TKeyValuePairs): TMatrixWriterFormat;
    Function FileHeader(const FileName: TFileName): TBytes;
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

Constructor TMatrixFormat.Create(const Format,FormatName: String);
begin
  inherited Create;
  FFormat := Format;
  FFormatName := FormatName;
end;

Function TMatrixFormat.FindProperty(const PropertyKey: string; out Found: TFormatProperty): Boolean;
begin
  Result := false;
  for var Prop := low(Properties) to high(Properties) do
  if SameText(Properties[Prop].Key,PropertyKey) then
  begin
    Found := Properties[Prop];
    Exit(true);
  end;
end;

Procedure TMatrixFormat.AppendTidyProperty(const [ref] Config: TKeyValuePairs; const Default: TKeyValuePair; var Tidied: TKeyValuePairs);
// The file and format properties are always kept, other properties when they differ from their default
Var
  Value: String;
begin
  if SameText(Default.Key,FileProperty) or SameText(Default.Key,FormatProperty) then
    Tidied.Append(Default.Key,Config.Str(Default.Key))
  else
    if Config.Contains(Default.Key,Value) and not SameText(Default.Value,Value) then Tidied.Append(Default.Key,Value);
end;

Procedure TMatrixFormat.AddProperty(const Key,DefaultValue,Caption: String; const PickList: TStringDynArray = nil);
begin
  var Index := Length(Properties);
  SetLength(Properties,Index+1);
  Properties[Index].Key := Key;
  Properties[Index].DefaultValue := DefaultValue;
  Properties[Index].Caption := Caption;
  Properties[Index].PickList := PickList;
end;

Function TMatrixFormat.OptionIndex(const PropertyValue: String; const Options: array of String;
                                   const PropertyName: String; const MinIndex: Integer = 0): Integer;
// Returns the index of the option matching the property value, raising when
// there is no match or the option is not allowed for the property
begin
  for var Option := MinIndex to high(Options) do
  if SameText(Options[Option],PropertyValue) then Exit(Option);
  raise Exception.Create('Invalid ' + PropertyName);
end;

Function TMatrixFormat.BoolPropertyValue(const PropertyValue,PropertyName: String): Boolean;
begin
  Result := OptionIndex(PropertyValue,
                        [False.ToString(TUseBoolStrs.True),True.ToString(TUseBoolStrs.True)],
                        PropertyName) = 1;
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

Procedure TMatrixFormat.CheckFormat(const [ref] Config: TKeyValuePairs);
begin
  if not SameText(Config.Str(FormatProperty),Format) then raise Exception.Create('Invalid format-property');
end;

Function TMatrixFormat.Format: String;
begin
  Result := FFormat;
end;

Function TMatrixFormat.FormatName: String;
begin
  Result := FFormatName;
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
  for var Prop := low(Properties) to high(Properties) do
  Result.Append(Properties[Prop].Key,Properties[Prop].DefaultValue);
end;

Function TMatrixFormat.PropertyLabel(const PropertyKey: string): String;
// Returns the display label of a format property, or an empty string
// when the property is unknown to the format
Var
  Found: TFormatProperty;
begin
  if SameText(PropertyKey,FileProperty) then
    Result := 'File'
  else if SameText(PropertyKey,FormatProperty) then
    Result := 'Format'
  else if FindProperty(PropertyKey,Found) then
    Result := Found.Caption
  else
    Result := '';
end;

Function TMatrixFormat.PropertyPickList(const PropertyKey: string; out PickList: TStringDynArray): Boolean;
Var
  Found: TFormatProperty;
begin
  if PropertyKey = FormatProperty then
  begin
    Result := true;
    PickList := [Format];
  end else
  begin
    Result := FindProperty(PropertyKey,Found) and (Found.PickList <> nil);
    if Result then PickList := Copy(Found.PickList);
  end;
end;

Function TMatrixFormat.TidyProperties(const [ref] Config: TKeyValuePairs): TKeyValuePairs;
begin
  // Result is a managed type and may alias the caller's destination variable,
  // so it must be cleared before appending
  Result.Clear;
  CheckFormat(Config);
  var Defaults := FormatProperties;
  for var Prop := 0 to Defaults.Count-1 do AppendTidyProperty(Config,Defaults[Prop],Result);
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

Function TCustomMatrixWriterFormat.CreateWriter(const [ref] Config: TKeyValuePairs;
                                                const FileLabel: string;
                                                const MatrixLabels: array of String;
                                                const Size: Integer): TMatrixWriter;
Var
  NewFile: TNewMatrixFile;
begin
  CheckFormat(Config);
  NewFile.FileLabel := FileLabel;
  NewFile.MatrixLabels := TStringArrayBuilder.Create(MatrixLabels);
  NewFile.Size := Size;
  Result := NewWriter(Config,NewFile);
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

Function TMatrixFormats.FindReaderFormat(const Matches: TFunc<TMatrixReaderFormat,Boolean>): TMatrixReaderFormat;
// Returns the first registered reader format that matches, or nil
begin
  Result := nil;
  for var Index := low(ReaderFormats) to high(ReaderFormats) do
  if Matches(ReaderFormats[Index]) then Exit(ReaderFormats[Index]);
end;

Function TMatrixFormats.NamedReaderFormat(const Format: string): TMatrixReaderFormat;
begin
  Result := FindReaderFormat(Function(Candidate: TMatrixReaderFormat): Boolean
                             begin
                               Result := SameText(Candidate.Format,Format)
                             end);
end;

Function TMatrixFormats.NamedWriterFormat(const Format: string): TMatrixWriterFormat;
begin
  Result := nil;
  for var Index := low(WriterFormats) to high(WriterFormats) do
  if SameText(WriterFormats[Index].Format,Format) then Exit(WriterFormats[Index]);
end;

Function TMatrixFormats.AvailableReaderFormat(const [ref] Config: TKeyValuePairs): TMatrixReaderFormat;
begin
  Result := NamedReaderFormat(Config.Str(TMatrixFormat.FormatProperty));
  if (Result <> nil) and not Result.Available then Result := nil;
end;

Function TMatrixFormats.AvailableWriterFormat(const [ref] Config: TKeyValuePairs): TMatrixWriterFormat;
begin
  Result := NamedWriterFormat(Config.Str(TMatrixFormat.FormatProperty));
  if (Result <> nil) and not Result.Available then Result := nil;
end;

Function TMatrixFormats.FileHeader(const FileName: TFileName): TBytes;
begin
  var FileStream := TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result,HeaderSize);
    FileStream.Read(Result,HeaderSize)
  finally
    FileStream.Free;
  end;
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
  Result := NamedReaderFormat(Format);
end;

Function TMatrixFormats.ReaderFormat(const FileName: TFileName): TMatrixFormat;
// Determines the file format based on the file extension, then on the file header
begin
  var FileExtension := ExtractFileExt(FileName);
  Result := FindReaderFormat(Function(Candidate: TMatrixReaderFormat): Boolean
                             begin
                               Result := Candidate.HasFormat(FileExtension)
                             end);
  if (Result = nil) and FileExists(FileName) then Result := ReaderFormat(FileHeader(FileName));
end;

Function TMatrixFormats.ReaderFormat(const Header: TBytes): TMatrixFormat;
begin
  Result := FindReaderFormat(Function(Candidate: TMatrixReaderFormat): Boolean
                             begin
                               Result := Candidate.HasFormat(Header)
                             end);
end;

Function TMatrixFormats.RegisteredWriterFormats: TStringDynArray;
begin
  Result := [];
  for var Format := low(WriterFormats) to high(WriterFormats) do
  Result := Result + [WriterFormats[Format].Format];
end;

Function TMatrixFormats.WriterFormat(const Format: string): TMatrixFormat;
begin
  Result := NamedWriterFormat(Format);
end;

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs; Ordered: Boolean = true): TMatrixReader;
begin
  Result := nil;
  var Format := AvailableReaderFormat(Config);
  if Format <> nil then
  begin
    Result := Format.CreateReader(Config);
    if Ordered and (not Result.Ordered) then
    begin
      FreeAndNil(Result);
      raise Exception.Create('Matrix indices within file undefined');
    end;
  end;
end;

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of Integer): TMatrixReader;
begin
  var Format := AvailableReaderFormat(Config);
  if Format <> nil then Result := Format.CreateReader(Config,Selection) else Result := nil;
end;

Function TMatrixFormats.CreateReader(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of String): TMatrixReader;
begin
  var Format := AvailableReaderFormat(Config);
  if Format <> nil then Result := Format.CreateReader(Config,Selection) else Result := nil;
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
  var Format := AvailableWriterFormat(Config);
  if Format <> nil then Result := Format.CreateWriter(Config,FileLabel,MatrixLabels,Size) else Result := nil;
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
