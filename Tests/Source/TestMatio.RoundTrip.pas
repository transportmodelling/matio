unit TestMatio.RoundTrip;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Round-trip tests: write a matrix file then read it back and verify that the
// values, labels and metadata are preserved.
//
// A small synthetic matrix (2 matrices, 5x5) is used for all round-trip tests
// to keep test execution fast.  Values are chosen to be distinct enough to
// catch row/column transpositions and off-by-one indexing errors.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework;

type
  // ---------------------------------------------------------------------------
  // Text format round-trips
  // ---------------------------------------------------------------------------
  [TestFixture]
  TTxtRoundTripTests = class
  strict private
    FTempFile: string;
    function MakeTempFile(const Extension: string): string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure Txt_Tab_ValuesPreserved;
    [Test] procedure Txt_Tab_MatrixLabelsPreserved;
    [Test] procedure Txt_Comma_ValuesPreserved;
    [Test] procedure Txt_NoHeader_ValuesPreserved;
    [Test] procedure Txt_Decimals2_ValuesWithinTolerance;
    [Test] procedure Txt_ZeroRow_RemainsZero;
    // Out-of-bounds forgiveness: writing fewer/shorter rows than declared
    // pads the remaining cells with zeros
    [Test] procedure Txt_PartialRows_PaddedWithZeros;
    // Calculated matrices: write values computed by a TMatrixGetter
    [Test] procedure Txt_WriteByGetter_ValuesPreserved;
  end;

  // ---------------------------------------------------------------------------
  // 4G format round-trips
  // ---------------------------------------------------------------------------
  [TestFixture]
  T4GRoundTripTests = class
  strict private
    FTempFile: string;
    function MakeTempFile: string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure Gen4_Float32_ValuesPreserved;
    [Test] procedure Gen4_Float64_ValuesPreserved;
    [Test] procedure Gen4_NoCompression_ValuesPreserved;
    [Test] procedure Gen4_GzipCompression_ValuesPreserved;
    [Test] procedure Gen4_MatrixLabelsPreserved;
    [Test] procedure Gen4_FileLabelPreserved;
  end;

  // ---------------------------------------------------------------------------
  // Minutp format round-trips
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMinutpRoundTripTests = class
  strict private
    FTempFile: string;
    function MakeTempFile: string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure Mtp_ValuesPreserved;
    [Test] procedure Mtp_MatrixCountPreserved;
    [Test] procedure Mtp_SizePreserved;
    [Test] procedure Mtp_FileLabelPreserved;
  end;

  // ---------------------------------------------------------------------------
  // OMX format round-trips (skipped if HDF5 DLL is absent)
  // ---------------------------------------------------------------------------
  [TestFixture]
  TOMXRoundTripTests = class
  strict private
    FTempFile: string;
    FAvailable: Boolean;
    function MakeTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure OMX_ValuesPreserved;
    [Test] procedure OMX_MatrixLabelsPreserved;
    [Test] procedure OMX_FileLabelPreserved;
  end;

  // ---------------------------------------------------------------------------
  // Cube format round-trips (skipped if HDF5 DLL is absent)
  // ---------------------------------------------------------------------------
  [TestFixture]
  TCubeRoundTripTests = class
  strict private
    FTempFile: string;
    FAvailable: Boolean;
    function MakeTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure Cube_ValuesPreserved;
    [Test] procedure Cube_MatrixLabelsPreserved;
    [Test] procedure Cube_FileLabelPreserved;
  end;

  // ---------------------------------------------------------------------------
  // High-level TFloat64Matrices.Save / Read API
  // ---------------------------------------------------------------------------
  [TestFixture]
  THighLevelRoundTripTests = class
  strict private
    FTempFile: string;
    function MakeTempFile(const Extension: string): string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure HighLevel_Txt_Save_Read;
    [Test] procedure HighLevel_4G_Save_Read;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  Winapi.Windows, SysUtils, IOUtils, Math, KeyVal, matio, matio.writer, matio.formats, matio.matrix;

const
  NMatrices = 2;
  NZones    = 5;
  // Tolerance per format
  TolExact  = 1e-9;
  Tol4GF32  = 1e-3;   // float32 epsilon for small integers like these
  TolMtp    = 0.01;
  TolOMX    = 1e-6;
  Tol2Dec   = 0.01;

// ---------------------------------------------------------------------------
// Build a predictable NMatrices x NZones x NZones test matrix.
// Values: M[m, r, c] = (m+1)*100 + (r+1)*10 + (c+1)   (all non-zero)
// ---------------------------------------------------------------------------
function BuildTestMatrices: TFloat64Matrices;
var
  m, r, c: Integer;
begin
  Result := TFloat64Matrices.Create(NMatrices, NZones);
  Result.FileLabel := 'TestFile';
  Result.MatrixLabels[0] := 'MATRIX_A';
  Result.MatrixLabels[1] := 'MATRIX_B';
  for m := 0 to NMatrices - 1 do
    for r := 0 to NZones - 1 do
      for c := 0 to NZones - 1 do
        Result[m, r, c] := (m + 1) * 100.0 + (r + 1) * 10.0 + (c + 1);
end;

// ---------------------------------------------------------------------------
// Compare two NMatrices x NZones x NZones matrices within tolerance.
// Returns empty string on success.
// ---------------------------------------------------------------------------
function CompareRoundTrip(Written, Read: TFloat64Matrices; Tol: Double): string;
var
  m, r, c: Integer;
begin
  Result := '';
  for m := 0 to NMatrices - 1 do
    for r := 0 to NZones - 1 do
      for c := 0 to NZones - 1 do
        if Abs(Written[m, r, c] - Read[m, r, c]) > Tol then
        begin
          Result := Format('matrix %d row %d col %d: wrote %.6f read %.6f',
                           [m, r, c, Written[m, r, c], Read[m, r, c]]);
          Exit;
        end;
end;

// ---------------------------------------------------------------------------
// Build a minimal TKeyValuePairs config for writing/reading
// ---------------------------------------------------------------------------
function MakeWriteProps(const FileName, Format: string): TKeyValuePairs;
begin
  // Result may alias the caller's destination variable; clear before appending
  Result.Clear;
  Result.Append('file', FileName);
  Result.Append('format', Format);
end;

function MakeReadProps(const FileName, Format: string): TKeyValuePairs;
begin
  Result := MakeWriteProps(FileName, Format);
end;

////////////////////////////////////////////////////////////////////////////////
// TTxtRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function TTxtRoundTripTests.MakeTempFile(const Extension: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + Extension);
  FTempFile := Result;
end;

procedure TTxtRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TTxtRoundTripTests.Txt_Tab_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    // Write
    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    Written.Save(Props);
    // Read back
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'tab');
      ReadBack.Read(Props);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'Txt tab round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_Tab_MatrixLabelsPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'tab');
      ReadBack.Read(Props);
      Assert.AreEqual('MATRIX_A', ReadBack.MatrixLabels[0]);
      Assert.AreEqual('MATRIX_B', ReadBack.MatrixLabels[1]);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_Comma_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.csv');
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'comma');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'comma');
      ReadBack.Read(Props);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'Txt comma round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_NoHeader_ValuesPreserved;
var
  TempFile: string;
  WProps, RProps: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    WProps := MakeWriteProps(TempFile, 'txt');
    WProps.Append('delim', 'tab');
    WProps.Append('header', 'false');
    Written.Save(WProps);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      RProps := MakeReadProps(TempFile, 'txt');
      RProps.Append('delim', 'tab');
      RProps.Append('header', 'false');
      ReadBack.Read(RProps);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'Txt no-header round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_Decimals2_ValuesWithinTolerance;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    Props.Append('decimals', '2');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'tab');
      ReadBack.Read(Props);
      // With 2 decimal places the round-trip error must be <= 0.01
      Mismatch := CompareRoundTrip(Written, ReadBack, Tol2Dec);
      Assert.IsEmpty(Mismatch, 'Txt decimals=2 round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_ZeroRow_RemainsZero;
// A matrix where row 2 (index 1) is entirely zero: after a txt round-trip
// those cells must still be zero (the sparse format omits all-zero rows).
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  c: Integer;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    // Zero out row index 1 in both matrices
    for c := 0 to NZones - 1 do
    begin
      Written[0, 1, c] := 0.0;
      Written[1, 1, c] := 0.0;
    end;

    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'tab');
      ReadBack.Read(Props);
      for c := 0 to NZones - 1 do
      begin
        Assert.AreEqual(0.0, ReadBack[0, 1, c], TolExact,
          Format('Matrix 0, row 1, col %d should be zero', [c]));
        Assert.AreEqual(0.0, ReadBack[1, 1, c], TolExact,
          Format('Matrix 1, row 1, col %d should be zero', [c]));
      end;
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_PartialRows_PaddedWithZeros;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Writer: TMatrixWriter;
  ShortRow: TFloat64MatrixRow;
  ReadBack: TFloat64Matrices;
  Row, c: Integer;
begin
  TempFile := MakeTempFile('.txt');
  // Writer declared for 2 matrices of NZones columns; each row supplies only
  // 1 matrix with 3 columns — the remaining cells must end up as zeros
  Props := MakeWriteProps(TempFile, 'txt');
  Props.Append('delim', 'tab');
  Writer := MatrixFormats.CreateWriter(Props, '', NMatrices, NZones);
  try
    for Row := 0 to NZones - 1 do
    begin
      SetLength(ShortRow, 3);
      for c := 0 to 2 do ShortRow[c] := (Row + 1) * 10.0 + (c + 1);
      Writer.Write([ShortRow]);
    end;
  finally
    Writer.Free;
  end;
  ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
  try
    Props := MakeReadProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    ReadBack.Read(Props);
    // Supplied cells are preserved
    Assert.AreEqual(11.0, ReadBack[0, 0, 0], TolExact);
    Assert.AreEqual(53.0, ReadBack[0, 4, 2], TolExact);
    // Columns beyond the supplied row size are zero
    for Row := 0 to NZones - 1 do
      for c := 3 to NZones - 1 do
        Assert.AreEqual(0.0, ReadBack[0, Row, c], TolExact,
          Format('Matrix 0, row %d, col %d should be zero', [Row, c]));
    // The matrix that was never written is entirely zero
    for Row := 0 to NZones - 1 do
      for c := 0 to NZones - 1 do
        Assert.AreEqual(0.0, ReadBack[1, Row, c], TolExact,
          Format('Matrix 1, row %d, col %d should be zero', [Row, c]));
  finally
    ReadBack.Free;
  end;
end;

procedure TTxtRoundTripTests.Txt_WriteByGetter_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Writer: TMatrixWriter;
  ReadBack: TFloat64Matrices;
  Row, m, c: Integer;
begin
  TempFile := MakeTempFile('.txt');
  // Write values computed on the fly, without allocating row buffers
  Props := MakeWriteProps(TempFile, 'txt');
  Props.Append('delim', 'tab');
  Writer := MatrixFormats.CreateWriter(Props, '', NMatrices, NZones);
  try
    for Row := 0 to NZones - 1 do
    begin
      var CurrentRow := Row;
      Writer.Write(function(Matrix, Column: Integer): Float64
                   begin
                     Result := (Matrix + 1) * 100.0 + (CurrentRow + 1) * 10.0 + (Column + 1)
                   end);
    end;
  finally
    Writer.Free;
  end;
  ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
  try
    Props := MakeReadProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    ReadBack.Read(Props);
    for m := 0 to NMatrices - 1 do
      for Row := 0 to NZones - 1 do
        for c := 0 to NZones - 1 do
          Assert.AreEqual((m + 1) * 100.0 + (Row + 1) * 10.0 + (c + 1),
                          ReadBack[m, Row, c], TolExact,
            Format('Matrix %d, row %d, col %d', [m, Row, c]));
  finally
    ReadBack.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// T4GRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function T4GRoundTripTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + '.4g');
  FTempFile := Result;
end;

procedure T4GRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure T4GRoundTripTests.Gen4_Float32_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float32');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Mismatch := CompareRoundTrip(Written, ReadBack, Tol4GF32);
      Assert.IsEmpty(Mismatch, '4g float32 round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure T4GRoundTripTests.Gen4_Float64_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float64');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, '4g float64 round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure T4GRoundTripTests.Gen4_NoCompression_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float32');
    Props.Append('compress', 'none');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Mismatch := CompareRoundTrip(Written, ReadBack, Tol4GF32);
      Assert.IsEmpty(Mismatch, '4g no-compression round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure T4GRoundTripTests.Gen4_GzipCompression_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float32');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Mismatch := CompareRoundTrip(Written, ReadBack, Tol4GF32);
      Assert.IsEmpty(Mismatch, '4g gzip round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure T4GRoundTripTests.Gen4_MatrixLabelsPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float32');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Assert.AreEqual('MATRIX_A', ReadBack.MatrixLabels[0]);
      Assert.AreEqual('MATRIX_B', ReadBack.MatrixLabels[1]);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure T4GRoundTripTests.Gen4_FileLabelPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float32');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Assert.AreEqual('TestFile', ReadBack.FileLabel);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TMinutpRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function TMinutpRoundTripTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + '.bin');
  FTempFile := Result;
end;

procedure TMinutpRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TMinutpRoundTripTests.Mtp_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    // Precision=1 means 1 decimal place (values like 111.1 stored as integers)
    Props := MakeWriteProps(TempFile, 'mtp');
    Props.Append('prec', '1');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'mtp');
      Props.Append('prec', '1');
      ReadBack.Read(Props);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolMtp);
      Assert.IsEmpty(Mismatch, 'mtp round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TMinutpRoundTripTests.Mtp_MatrixCountPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'mtp');
    Props.Append('prec', '0');
    Written.Save(Props);
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'mtp');
      Props.Append('prec', '0');
      ReadBack.Read(Props);
      Assert.AreEqual(NMatrices, ReadBack.Count);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TMinutpRoundTripTests.Mtp_SizePreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'mtp');
    Props.Append('prec', '0');
    Written.Save(Props);
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'mtp');
      Props.Append('prec', '0');
      ReadBack.Read(Props);
      Assert.AreEqual(NZones, ReadBack.Size);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TMinutpRoundTripTests.Mtp_FileLabelPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'mtp');
    Props.Append('prec', '0');
    Written.Save(Props);
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'mtp');
      Props.Append('prec', '0');
      ReadBack.Read(Props);
      Assert.AreEqual('TestFile', ReadBack.FileLabel);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TOMXRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function TOMXRoundTripTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + '.omx');
  FTempFile := Result;
end;

procedure TOMXRoundTripTests.Setup;
begin
  FAvailable := MatrixFormats.WriterFormat('omx').Available;
end;

procedure TOMXRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TOMXRoundTripTests.OMX_ValuesPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'omx'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, 'omx'), {Ordered:}false);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolOMX);
      Assert.IsEmpty(Mismatch, 'omx round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TOMXRoundTripTests.OMX_MatrixLabelsPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'omx'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, 'omx'), {Ordered:}false);
      Assert.AreEqual('MATRIX_A', ReadBack.MatrixLabels[0]);
      Assert.AreEqual('MATRIX_B', ReadBack.MatrixLabels[1]);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TOMXRoundTripTests.OMX_FileLabelPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'omx'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, 'omx'), {Ordered:}false);
      Assert.AreEqual('TestFile', ReadBack.FileLabel);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TCubeRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function TCubeRoundTripTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + '.cube-matrix');
  FTempFile := Result;
end;

procedure TCubeRoundTripTests.Setup;
begin
  FAvailable := MatrixFormats.WriterFormat('cube').Available;
end;

procedure TCubeRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TCubeRoundTripTests.Cube_ValuesPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'cube'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, 'cube'), {Ordered:}false);
      Mismatch := CompareRoundTrip(Written, ReadBack, TolOMX);
      Assert.IsEmpty(Mismatch, 'cube round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TCubeRoundTripTests.Cube_MatrixLabelsPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'cube'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      // Matrices are enumerated alphabetically: MATRIX_A, MATRIX_B
      ReadBack.Read(MakeReadProps(TempFile, 'cube'), {Ordered:}false);
      Assert.AreEqual('MATRIX_A', ReadBack.MatrixLabels[0]);
      Assert.AreEqual('MATRIX_B', ReadBack.MatrixLabels[1]);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TCubeRoundTripTests.Cube_FileLabelPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube round-trip test');
    Exit;
  end;
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    Written.Save(MakeWriteProps(TempFile, 'cube'));
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, 'cube'), {Ordered:}false);
      Assert.AreEqual('TestFile', ReadBack.FileLabel);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// THighLevelRoundTripTests
////////////////////////////////////////////////////////////////////////////////

function THighLevelRoundTripTests.MakeTempFile(const Extension: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'matio_test_' + IntToStr(GetCurrentThreadId) + Extension);
  FTempFile := Result;
end;

procedure THighLevelRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure THighLevelRoundTripTests.HighLevel_Txt_Save_Read;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.txt');
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, 'txt');
    Props.Append('delim', 'tab');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      Props := MakeReadProps(TempFile, 'txt');
      Props.Append('delim', 'tab');
      ReadBack.Read(Props);
      Assert.AreEqual(NMatrices, ReadBack.Count, 'Count');
      Assert.AreEqual(NZones, ReadBack.Size, 'Size');
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'HighLevel txt round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure THighLevelRoundTripTests.HighLevel_4G_Save_Read;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Written, ReadBack: TFloat64Matrices;
  Mismatch: string;
begin
  TempFile := MakeTempFile('.4g');
  Written := BuildTestMatrices;
  try
    Props := MakeWriteProps(TempFile, '4g');
    Props.Append('prec', 'float64');
    Props.Append('compress', 'gzip');
    Written.Save(Props);

    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeReadProps(TempFile, '4g'));
      Assert.AreEqual(NMatrices, ReadBack.Count, 'Count');
      Assert.AreEqual(NZones, ReadBack.Size, 'Size');
      Mismatch := CompareRoundTrip(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'HighLevel 4g round-trip: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

end.
