unit TestMatio.Formats;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the format registry (TMatrixFormats / TMatrixFormat descendants).
// No file I/O is performed except for format auto-detection via file header.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  System.Types, SysUtils, DUnitX.TestFramework, KeyVal, matio.reader, matio.formats, matio.hdf5;

type
  [TestFixture]
  TMatrixFormatsTests = class
  strict private
    function DataDir: string;
  public
    // Registered reader formats
    [Test]
    procedure RegisteredReaderFormats_ContainsTxt;
    [Test]
    procedure RegisteredReaderFormats_ContainsMtp;
    [Test]
    procedure RegisteredReaderFormats_ContainsGen4;
    [Test]
    procedure RegisteredReaderFormats_ContainsOmx;
    // Registered writer formats
    [Test]
    procedure RegisteredWriterFormats_ContainsTxt;
    [Test]
    procedure RegisteredWriterFormats_ContainsMtp;
    [Test]
    procedure RegisteredWriterFormats_ContainsGen4;
    [Test]
    procedure RegisteredWriterFormats_NoVisum;
    // Look up by format name
    [Test]
    procedure ReaderFormatByName_KnownReturnsNonNil;
    [Test]
    procedure ReaderFormatByName_UnknownReturnsNil;
    [Test]
    procedure WriterFormatByName_Gen4_NonNil;
    [Test]
    procedure WriterFormatByName_Visum_Nil;
    // Look up by file (extension / header bytes)
    [Test]
    procedure ReaderFormatByFile_4g_DetectsHeader;
    [Test]
    procedure ReaderFormatByFile_Bin_DetectsHeader;
    [Test]
    procedure ReaderFormatByFile_Omx_DetectsExtension;
    // FormatProperties
    [Test]
    procedure FormatProperties_Txt_HasFileKey;
    [Test]
    procedure FormatProperties_Txt_HasFormatKey;
    [Test]
    procedure FormatProperties_Txt_HasDelimKey;
    [Test]
    procedure FormatProperties_Txt_HasHeaderKey;
    // TidyProperties strips defaults
    [Test]
    procedure TidyProperties_RemovesDefaultDelim;
    // FileExists helper
    [Test]
    procedure FileExists_ReturnsTrueForExampleTxt;
    [Test]
    procedure FileExists_ReturnsFalseForMissing;
    // CreateReader returns nil for unknown format (no exception)
    [Test]
    procedure CreateReader_UnknownFormat_ReturnsNil;
  end;

  // ---------------------------------------------------------------------------
  // OMX format availability (controlled via the global Hdf5Dll variable)
  // Place hdf5.dll in Tests\Data\ to enable the "available" test.
  // ---------------------------------------------------------------------------
  [TestFixture]
  TOMXAvailabilityTests = class
  strict private
    FSavedDll: THdf5Dll;   // original Hdf5Dll value, restored in TearDown
    FDllPath:  string;     // full path to hdf5.dll in Tests\Data\
    function DataDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // hdf5.dll absent (or explicitly unloaded): Available must be False
    [Test]
    procedure OMX_NotAvailable_WhenDllNotLoaded;
    // hdf5.dll present in Tests\Data\: Available must be True
    // Skipped (Assert.Pass) when the file is not found
    [Test]
    procedure OMX_Available_WhenDllLoaded;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  matio;

function TMatrixFormatsTests.DataDir: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

////////////////////////////////////////////////////////////////////////////////
// Registered reader formats
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.RegisteredReaderFormats_ContainsTxt;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredReaderFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'txt') then Found := True;
  Assert.IsTrue(Found, 'txt not found in registered reader formats');
end;

procedure TMatrixFormatsTests.RegisteredReaderFormats_ContainsMtp;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredReaderFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'mtp') then Found := True;
  Assert.IsTrue(Found, 'mtp not found in registered reader formats');
end;

procedure TMatrixFormatsTests.RegisteredReaderFormats_ContainsGen4;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredReaderFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], '4g') then Found := True;
  Assert.IsTrue(Found, '4g not found in registered reader formats');
end;

procedure TMatrixFormatsTests.RegisteredReaderFormats_ContainsOmx;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredReaderFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'omx') then Found := True;
  Assert.IsTrue(Found, 'omx not found in registered reader formats');
end;

////////////////////////////////////////////////////////////////////////////////
// Registered writer formats
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.RegisteredWriterFormats_ContainsTxt;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredWriterFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'txt') then Found := True;
  Assert.IsTrue(Found, 'txt not found in registered writer formats');
end;

procedure TMatrixFormatsTests.RegisteredWriterFormats_ContainsMtp;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredWriterFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'mtp') then Found := True;
  Assert.IsTrue(Found, 'mtp not found in registered writer formats');
end;

procedure TMatrixFormatsTests.RegisteredWriterFormats_ContainsGen4;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredWriterFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], '4g') then Found := True;
  Assert.IsTrue(Found, '4g not found in registered writer formats');
end;

procedure TMatrixFormatsTests.RegisteredWriterFormats_NoVisum;
var
  Formats: TStringDynArray;
  Found: Boolean;
  i: Integer;
begin
  Formats := MatrixFormats.RegisteredWriterFormats;
  Found := False;
  for i := Low(Formats) to High(Formats) do
    if SameText(Formats[i], 'visum') then Found := True;
  Assert.IsFalse(Found, 'visum should not be in registered writer formats');
end;

////////////////////////////////////////////////////////////////////////////////
// Look up by format name
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.ReaderFormatByName_KnownReturnsNonNil;
begin
  Assert.IsNotNull(MatrixFormats.ReaderFormat('txt'), 'ReaderFormat(txt) returned nil');
end;

procedure TMatrixFormatsTests.ReaderFormatByName_UnknownReturnsNil;
begin
  Assert.IsNull(MatrixFormats.ReaderFormat('xyz'), 'ReaderFormat(xyz) should return nil');
end;

procedure TMatrixFormatsTests.WriterFormatByName_Gen4_NonNil;
begin
  Assert.IsNotNull(MatrixFormats.WriterFormat('4g'), 'WriterFormat(4g) returned nil');
end;

procedure TMatrixFormatsTests.WriterFormatByName_Visum_Nil;
begin
  Assert.IsNull(MatrixFormats.WriterFormat('visum'), 'WriterFormat(visum) should return nil');
end;

////////////////////////////////////////////////////////////////////////////////
// Look up by file
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.ReaderFormatByFile_4g_DetectsHeader;
var
  Fmt: TMatrixFormat;
begin
  Fmt := MatrixFormats.ReaderFormat(TFileName(DataDir + 'example.4g'));
  Assert.IsNotNull(Fmt, 'ReaderFormat returned nil for example.4g');
  Assert.AreEqual('4g', Fmt.Format, 'example.4g should be detected as 4g format');
end;

procedure TMatrixFormatsTests.ReaderFormatByFile_Bin_DetectsHeader;
var
  Fmt: TMatrixFormat;
begin
  Fmt := MatrixFormats.ReaderFormat(TFileName(DataDir + 'example.bin'));
  Assert.IsNotNull(Fmt, 'ReaderFormat returned nil for example.bin');
  Assert.AreEqual('mtp', Fmt.Format, 'example.bin should be detected as mtp format');
end;

procedure TMatrixFormatsTests.ReaderFormatByFile_Omx_DetectsExtension;
var
  Fmt: TMatrixFormat;
begin
  Fmt := MatrixFormats.ReaderFormat(TFileName(DataDir + 'example.omx'));
  Assert.IsNotNull(Fmt, 'ReaderFormat returned nil for example.omx');
  Assert.AreEqual('omx', Fmt.Format, 'example.omx should be detected as omx format');
end;

////////////////////////////////////////////////////////////////////////////////
// FormatProperties
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.FormatProperties_Txt_HasFileKey;
var
  Props: TKeyValuePairs;
begin
  Props := MatrixFormats.ReaderFormat('txt').FormatProperties;
  Assert.IsTrue(Props.Contains('file'), 'txt FormatProperties should contain ''file'' key');
end;

procedure TMatrixFormatsTests.FormatProperties_Txt_HasFormatKey;
var
  Props: TKeyValuePairs;
begin
  Props := MatrixFormats.ReaderFormat('txt').FormatProperties;
  Assert.IsTrue(Props.Contains('format'), 'txt FormatProperties should contain ''format'' key');
end;

procedure TMatrixFormatsTests.FormatProperties_Txt_HasDelimKey;
var
  Props: TKeyValuePairs;
begin
  Props := MatrixFormats.ReaderFormat('txt').FormatProperties;
  Assert.IsTrue(Props.Contains('delim'), 'txt FormatProperties should contain ''delim'' key');
end;

procedure TMatrixFormatsTests.FormatProperties_Txt_HasHeaderKey;
var
  Props: TKeyValuePairs;
begin
  Props := MatrixFormats.ReaderFormat('txt').FormatProperties;
  Assert.IsTrue(Props.Contains('header'), 'txt FormatProperties should contain ''header'' key');
end;

////////////////////////////////////////////////////////////////////////////////
// TidyProperties
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.TidyProperties_RemovesDefaultDelim;
var
  // Build a config that has format=txt and delim at its default (tab)
  // TidyProperties should omit delim since it equals the default.
  Full, Tidy: TKeyValuePairs;
  Fmt: TMatrixFormat;
begin
  Fmt := MatrixFormats.ReaderFormat('txt');
  Full := Fmt.FormatProperties;
  Full.Delete('file');
  Full.Append('file', 'test.txt');
  Tidy := Fmt.TidyProperties(Full);
  // 'delim' at its default value must not appear in the tidy set
  Assert.IsFalse(Tidy.Contains('delim'),
    'TidyProperties should remove the ''delim'' key when it equals the default');
end;

////////////////////////////////////////////////////////////////////////////////
// FileExists helper
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.FileExists_ReturnsTrueForExampleTxt;
var
  Config: TKeyValuePairs;
begin
  Config.Append('file', DataDir + 'example.txt');
  Config.Append('format', 'txt');
  Assert.IsTrue(TMatrixReaderFormat.FileExists(Config), 'FileExists should return true for example.txt');
end;

procedure TMatrixFormatsTests.FileExists_ReturnsFalseForMissing;
var
  Config: TKeyValuePairs;
begin
  Config.Append('file', DataDir + 'does_not_exist.txt');
  Config.Append('format', 'txt');
  Assert.IsFalse(TMatrixReaderFormat.FileExists(Config), 'FileExists should return false for missing file');
end;

////////////////////////////////////////////////////////////////////////////////
// CreateReader with unknown format
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixFormatsTests.CreateReader_UnknownFormat_ReturnsNil;
var
  Config: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Config.Append('file', 'dummy.xyz');
  Config.Append('format', 'xyz');
  Reader := MatrixFormats.CreateReader(Config);
  Assert.IsNull(Reader, 'CreateReader should return nil for unknown format ''xyz''');
end;

////////////////////////////////////////////////////////////////////////////////
// TOMXAvailabilityTests
////////////////////////////////////////////////////////////////////////////////

function TOMXAvailabilityTests.DataDir: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

procedure TOMXAvailabilityTests.Setup;
begin
  // Save whatever the initialization block left in the global (nil when
  // hdf5.dll is absent from Tests\Source\, non-nil when it is present).
  FSavedDll := Hdf5Dll;
  FDllPath  := DataDir + 'hdf5.dll';
end;

procedure TOMXAvailabilityTests.TearDown;
begin
  // Restore the original global so subsequent fixtures see the same state
  // they would have seen without these tests.
  if Hdf5Dll <> FSavedDll then
  begin
    Hdf5Dll.Free;
    Hdf5Dll := FSavedDll;
  end;
end;

procedure TOMXAvailabilityTests.OMX_NotAvailable_WhenDllNotLoaded;
var
  SavedDll: THdf5Dll;
begin
  // Temporarily set the global to nil regardless of the exe-dir DLL state,
  // assert, then restore — TearDown will reconcile FSavedDll afterwards.
  SavedDll := Hdf5Dll;
  Hdf5Dll  := nil;
  try
    Assert.IsFalse(MatrixFormats.ReaderFormat('omx').Available,
      'OMX format should report unavailable when Hdf5Dll is nil');
  finally
    Hdf5Dll := SavedDll;
  end;
end;

procedure TOMXAvailabilityTests.OMX_Available_WhenDllLoaded;
begin
  if not FileExists(FDllPath) then
  begin
    Assert.Pass('hdf5.dll not found in Tests\Data\ — skipping OMX availability test');
    Exit;
  end;
  // Free any DLL already loaded (e.g. from Tests\Source\) and load the
  // one from Tests\Data\ so the test is self-contained.
  Hdf5Dll.Free;
  Hdf5Dll := THdf5Dll.Create(FDllPath);
  Assert.IsTrue(MatrixFormats.ReaderFormat('omx').Available,
    'OMX format should report available after loading hdf5.dll from Tests\Data\');
end;

end.
