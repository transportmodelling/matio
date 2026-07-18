unit TestMatio.Matrix;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for TFloat64Matrices and TFloat32Matrices (matio.matrix.pas).
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix;

type
  // ---------------------------------------------------------------------------
  // TFloat64Matrices
  // ---------------------------------------------------------------------------
  [TestFixture]
  TFloat64MatricesTests = class
  strict private
    FMatrices: TFloat64Matrices;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Construction
    [Test] procedure Count_IsCorrect;
    [Test] procedure Size_IsCorrect;
    [Test] procedure DefaultValues_AreZero;
    // Value access
    [Test] procedure SetAndGet_RoundTrips;
    // Metadata
    [Test] procedure FileLabel_SetAndGet;
    [Test] procedure MatrixLabels_SetAndGet;
    // RowValues
    [Test] procedure RowValues_MatchSetValues;
    // Transpose
    [Test] procedure TransposeSingle_SwapsValues;
    [Test] procedure TransposeSingle_LeavesOtherMatrixUnchanged;
    [Test] procedure TransposeAll_SwapsAllMatrices;
    [Test] procedure TransposeTwice_RestoresOriginal;
  end;

  // ---------------------------------------------------------------------------
  // TFloat32Matrices
  // ---------------------------------------------------------------------------
  [TestFixture]
  TFloat32MatricesTests = class
  strict private
    FMatrices: TFloat32Matrices;
    FTempFile: string;
    function MakeTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Construction
    [Test] procedure Count_IsCorrect;
    [Test] procedure Size_IsCorrect;
    // Value access — float32 precision
    [Test] procedure SetAndGet_WithinFloat32Precision;
    // Metadata
    [Test] procedure MatrixLabels_SetAndGet;
    // RowValues
    [Test] procedure RowValues_MatchSetValues;
    // Save / Read round-trip
    [Test] procedure SaveAndRead_ValuesPreserved;
    [Test] procedure SaveAndRead_LabelsPreserved;
    // Selection
    [Test] procedure SaveAndRead_SelectByIndex_ReadsCorrectMatrix;
    [Test] procedure SaveAndRead_SelectByLabel_ReadsCorrectMatrix;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  Winapi.Windows, SysUtils, IOUtils, Math, matio, KeyVal, matio.formats;

const
  NMatrices = 2;
  NSize     = 4;
  TolExact  = 1e-9;
  TolF32    = 1e-5;  // float32 has ~7 significant digits; integer values are exact

////////////////////////////////////////////////////////////////////////////////
// TFloat64MatricesTests
////////////////////////////////////////////////////////////////////////////////

procedure TFloat64MatricesTests.Setup;
begin
  FMatrices := TFloat64Matrices.Create(NMatrices, NSize);
end;

procedure TFloat64MatricesTests.TearDown;
begin
  FMatrices.Free;
end;

procedure TFloat64MatricesTests.Count_IsCorrect;
begin
  Assert.AreEqual(NMatrices, FMatrices.Count);
end;

procedure TFloat64MatricesTests.Size_IsCorrect;
begin
  Assert.AreEqual(NSize, FMatrices.Size);
end;

procedure TFloat64MatricesTests.DefaultValues_AreZero;
var
  m, r, c: Integer;
begin
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        Assert.AreEqual(0.0, FMatrices[m, r, c], TolExact);
end;

procedure TFloat64MatricesTests.SetAndGet_RoundTrips;
begin
  FMatrices[0, 1, 2] := 3.14159;
  Assert.AreEqual(3.14159, FMatrices[0, 1, 2], TolExact);
end;

procedure TFloat64MatricesTests.FileLabel_SetAndGet;
begin
  FMatrices.FileLabel := 'MyLabel';
  Assert.AreEqual('MyLabel', FMatrices.FileLabel);
end;

procedure TFloat64MatricesTests.MatrixLabels_SetAndGet;
begin
  FMatrices.MatrixLabels[0] := 'ALPHA';
  FMatrices.MatrixLabels[1] := 'BETA';
  Assert.AreEqual('ALPHA', FMatrices.MatrixLabels[0]);
  Assert.AreEqual('BETA',  FMatrices.MatrixLabels[1]);
end;

procedure TFloat64MatricesTests.RowValues_MatchSetValues;
var
  Row: TFloat64MatrixRow;
  c: Integer;
begin
  // Set known values in matrix 1, row 2
  for c := 0 to NSize - 1 do
    FMatrices[1, 2, c] := (c + 1) * 7.0;
  // Read back via RowValues
  SetLength(Row, NSize);
  FMatrices.RowValues(1, 2).AssignTo(Row);
  for c := 0 to NSize - 1 do
    Assert.AreEqual((c + 1) * 7.0, Row[c], TolExact);
end;

procedure TFloat64MatricesTests.TransposeSingle_SwapsValues;
var
  r, c: Integer;
begin
  // Fill matrix 0 with non-symmetric values: [r,c] = r*10 + c + 1
  for r := 0 to NSize - 1 do
    for c := 0 to NSize - 1 do
      FMatrices[0, r, c] := r * 10.0 + c + 1;
  FMatrices.Transpose(0);
  // After transpose: [r,c] should equal original [c,r] = c*10 + r + 1
  for r := 0 to NSize - 1 do
    for c := 0 to NSize - 1 do
      Assert.AreEqual(c * 10.0 + r + 1, FMatrices[0, r, c], TolExact);
end;

procedure TFloat64MatricesTests.TransposeSingle_LeavesOtherMatrixUnchanged;
var
  r, c: Integer;
begin
  // Fill matrix 0; leave matrix 1 at zero
  for r := 0 to NSize - 1 do
    for c := 0 to NSize - 1 do
      FMatrices[0, r, c] := r * 10.0 + c + 1;
  FMatrices.Transpose(0);
  // Matrix 1 must remain zero
  for r := 0 to NSize - 1 do
    for c := 0 to NSize - 1 do
      Assert.AreEqual(0.0, FMatrices[1, r, c], TolExact);
end;

procedure TFloat64MatricesTests.TransposeAll_SwapsAllMatrices;
var
  m, r, c: Integer;
begin
  // Fill both matrices with non-symmetric values: [m,r,c] = m*100 + r*10 + c + 1
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        FMatrices[m, r, c] := m * 100.0 + r * 10.0 + c + 1;
  FMatrices.Transpose;
  // After transpose: [m,r,c] = original [m,c,r] = m*100 + c*10 + r + 1
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        Assert.AreEqual(m * 100.0 + c * 10.0 + r + 1, FMatrices[m, r, c], TolExact);
end;

procedure TFloat64MatricesTests.TransposeTwice_RestoresOriginal;
var
  m, r, c: Integer;
begin
  // Fill with non-symmetric values
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        FMatrices[m, r, c] := m * 100.0 + r * 10.0 + c + 1;
  FMatrices.Transpose;
  FMatrices.Transpose;
  // Values must be back to the original
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        Assert.AreEqual(m * 100.0 + r * 10.0 + c + 1, FMatrices[m, r, c], TolExact);
end;

////////////////////////////////////////////////////////////////////////////////
// TFloat32MatricesTests
////////////////////////////////////////////////////////////////////////////////

function TFloat32MatricesTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'matio_matrix_f32_' + IntToStr(GetCurrentThreadId) + '.txt');
  FTempFile := Result;
end;

procedure TFloat32MatricesTests.Setup;
begin
  FMatrices := TFloat32Matrices.Create(NMatrices, NSize);
end;

procedure TFloat32MatricesTests.TearDown;
begin
  FMatrices.Free;
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TFloat32MatricesTests.Count_IsCorrect;
begin
  Assert.AreEqual(NMatrices, FMatrices.Count);
end;

procedure TFloat32MatricesTests.Size_IsCorrect;
begin
  Assert.AreEqual(NSize, FMatrices.Size);
end;

procedure TFloat32MatricesTests.SetAndGet_WithinFloat32Precision;
begin
  // Use an integer value exactly representable in float32 (< 2^24)
  FMatrices[0, 1, 2] := 123456.0;
  Assert.AreEqual(123456.0, FMatrices[0, 1, 2], TolF32);
end;

procedure TFloat32MatricesTests.MatrixLabels_SetAndGet;
begin
  FMatrices.MatrixLabels[0] := 'ALPHA';
  FMatrices.MatrixLabels[1] := 'BETA';
  Assert.AreEqual('ALPHA', FMatrices.MatrixLabels[0]);
  Assert.AreEqual('BETA',  FMatrices.MatrixLabels[1]);
end;

procedure TFloat32MatricesTests.RowValues_MatchSetValues;
var
  Row: TFloat32MatrixRow;
  c: Integer;
begin
  // Set known integer values in matrix 0, row 3
  for c := 0 to NSize - 1 do
    FMatrices[0, 3, c] := (c + 1) * 5.0;
  // Read back via RowValues
  SetLength(Row, NSize);
  FMatrices.RowValues(0, 3).AssignTo(Row);
  for c := 0 to NSize - 1 do
    Assert.AreEqual(Single((c + 1) * 5.0), Row[c], Single(TolF32));
end;

procedure TFloat32MatricesTests.SaveAndRead_ValuesPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Loaded: TFloat32Matrices;
  m, r, c: Integer;
begin
  TempFile := MakeTempFile;
  // Fill with integer values exactly representable in float32
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        FMatrices[m, r, c] := (m + 1) * 100.0 + (r + 1) * 10.0 + (c + 1);
  Props.Clear;
  Props.Append('file', TempFile);
  Props.Append('format', 'txt');
  Props.Append('delim', 'tab');
  FMatrices.Save(Props);
  Loaded := TFloat32Matrices.Create(NMatrices, NSize);
  try
    Loaded.Read(Props);
    for m := 0 to NMatrices - 1 do
      for r := 0 to NSize - 1 do
        for c := 0 to NSize - 1 do
          Assert.AreEqual(FMatrices[m, r, c], Loaded[m, r, c], TolF32);
  finally
    Loaded.Free;
  end;
end;

procedure TFloat32MatricesTests.SaveAndRead_SelectByIndex_ReadsCorrectMatrix;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Loaded: TFloat32Matrices;
  m, r, c: Integer;
begin
  TempFile := MakeTempFile;
  // Fill matrices with distinct values: matrix m has base value (m+1)*1000
  for m := 0 to NMatrices - 1 do
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        FMatrices[m, r, c] := (m + 1) * 1000.0 + r * 10.0 + c + 1;
  Props.Clear;
  Props.Append('file', TempFile);
  Props.Append('format', 'txt');
  Props.Append('delim', 'tab');
  FMatrices.Save(Props);
  // Read back only matrix 1 (second matrix)
  Loaded := TFloat32Matrices.Create(1, NSize);
  try
    Loaded.Read(Props, [1]);
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        Assert.AreEqual(FMatrices[1, r, c], Loaded[0, r, c], TolF32);
  finally
    Loaded.Free;
  end;
end;

procedure TFloat32MatricesTests.SaveAndRead_SelectByLabel_ReadsCorrectMatrix;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Loaded: TFloat32Matrices;
  r, c: Integer;
begin
  TempFile := MakeTempFile;
  FMatrices.MatrixLabels[0] := 'ALPHA';
  FMatrices.MatrixLabels[1] := 'BETA';
  // Fill matrix 0 (ALPHA) with distinct values
  for r := 0 to NSize - 1 do
    for c := 0 to NSize - 1 do
      FMatrices[0, r, c] := r * 10.0 + c + 1;
  Props.Clear;
  Props.Append('file', TempFile);
  Props.Append('format', 'txt');
  Props.Append('delim', 'tab');
  FMatrices.Save(Props);
  // Read back only ALPHA by label
  Loaded := TFloat32Matrices.Create(1, NSize);
  try
    Loaded.Read(Props, ['ALPHA']);
    Assert.AreEqual('ALPHA', Loaded.MatrixLabels[0]);
    for r := 0 to NSize - 1 do
      for c := 0 to NSize - 1 do
        Assert.AreEqual(FMatrices[0, r, c], Loaded[0, r, c], TolF32);
  finally
    Loaded.Free;
  end;
end;

procedure TFloat32MatricesTests.SaveAndRead_LabelsPreserved;
var
  TempFile: string;
  Props: TKeyValuePairs;
  Loaded: TFloat32Matrices;
begin
  TempFile := MakeTempFile;
  FMatrices.MatrixLabels[0] := 'ALPHA';
  FMatrices.MatrixLabels[1] := 'BETA';
  Props.Clear;
  Props.Append('file', TempFile);
  Props.Append('format', 'txt');
  Props.Append('delim', 'tab');
  FMatrices.Save(Props);
  Loaded := TFloat32Matrices.Create(NMatrices, NSize);
  try
    Loaded.Read(Props);
    Assert.AreEqual('ALPHA', Loaded.MatrixLabels[0]);
    Assert.AreEqual('BETA',  Loaded.MatrixLabels[1]);
  finally
    Loaded.Free;
  end;
end;

end.
