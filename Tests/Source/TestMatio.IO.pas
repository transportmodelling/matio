unit TestMatio.IO;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for TMatrixRowsReader and TMatrixRowsWriter.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, KeyVal, matio.matrix, matio.io;

type
  // ---------------------------------------------------------------------------
  // Shared helpers for both IO test fixtures
  // ---------------------------------------------------------------------------
  TIOTests = class
  protected
    function BuildTestMatrices: TFloat64Matrices;
    function MakeProps(const FileName, Format: string): TKeyValuePairs;
    function CompareAll(A, B: TFloat64Matrices; Tol: Double): string;
  end;

  // ---------------------------------------------------------------------------
  // TMatrixRowsReader: row-by-row reading combined with row storage
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMatrixRowsReaderTests = class(TIOTests)
  strict private
    FTempFile: string;
    FReference: TFloat64Matrices;
    FReadValues: TFloat64Matrices;
    FRowsReader: TMatrixRowsReader;
    FMtpFile: string;
    function MakeTempFile: string;
    procedure WriteTestFile(const FileName: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure RowsReader_Float64_ValuesPreserved;
    [Test] procedure RowsReader_FileLabel_Preserved;
    [Test] procedure RowsReader_MatrixLabels_Preserved;
    [Test] procedure RowsReader_SelectByIndex_CountIs1;
    [Test] procedure RowsReader_SelectByLabel_LabelCorrect;
    [Test] procedure RowsReader_PastEnd_Zeroes;
  end;

  // ---------------------------------------------------------------------------
  // TMatrixRowsWriter: row-by-row writing combined with row storage
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMatrixRowsWriterTests = class(TIOTests)
  strict private
    FTempFile: string;
    function MakeTempFile: string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure RowsWriter_Float64_ValuesPreserved;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  Winapi.Windows, SysUtils, IOUtils, Math, matio, matio.formats;

const
  NMatrices = 2;
  NZones    = 5;
  TolExact  = 1e-9;

////////////////////////////////////////////////////////////////////////////////
// TIOTests
////////////////////////////////////////////////////////////////////////////////

function TIOTests.BuildTestMatrices: TFloat64Matrices;
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

function TIOTests.MakeProps(const FileName, Format: string): TKeyValuePairs;
begin
  // Result may alias the caller's destination variable; clear before appending
  Result.Clear;
  Result.Append('file', FileName);
  Result.Append('format', Format);
  if SameText(Format, 'txt') then
    Result.Append('delim', 'tab');
end;

function TIOTests.CompareAll(A, B: TFloat64Matrices; Tol: Double): string;
var
  m, r, c: Integer;
begin
  Result := '';
  for m := 0 to NMatrices - 1 do
    for r := 0 to NZones - 1 do
      for c := 0 to NZones - 1 do
        if Abs(A[m, r, c] - B[m, r, c]) > Tol then
        begin
          Result := Format('matrix %d row %d col %d: %.6f vs %.6f',
                           [m, r, c, A[m, r, c], B[m, r, c]]);
          Exit;
        end;
end;

////////////////////////////////////////////////////////////////////////////////
// TMatrixRowsReaderTests
////////////////////////////////////////////////////////////////////////////////

function TMatrixRowsReaderTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'matio_io_r_' + IntToStr(GetCurrentThreadId) + '.txt');
  FTempFile := Result;
end;

procedure TMatrixRowsReaderTests.WriteTestFile(const FileName: string);
var
  Written: TFloat64Matrices;
begin
  Written := BuildTestMatrices;
  try
    Written.Save(MakeProps(FileName, 'txt'));
  finally
    Written.Free;
  end;
end;

procedure TMatrixRowsReaderTests.Setup;
var
  Props: TKeyValuePairs;
  Written: TFloat64Matrices;
  Row, Matrix, Col: Integer;
begin
  FTempFile := MakeTempFile;
  WriteTestFile(FTempFile);
  // Write a second temp file in Minutp format for the file-label test
  FMtpFile := TPath.Combine(TPath.GetTempPath,
    'matio_io_rl_' + IntToStr(GetCurrentThreadId) + '.bin');
  Written := BuildTestMatrices;
  try
    Props := MakeProps(FMtpFile, 'mtp');
    Props.Append('prec', '0');
    Written.Save(Props);
  finally
    Written.Free;
  end;
  FReference := BuildTestMatrices;
  FReadValues := TFloat64Matrices.Create(NMatrices, NZones);
  FRowsReader := TMatrixRowsReader.Create(MakeProps(FTempFile, 'txt'), NMatrices, NZones);
  for Row := 0 to NZones - 1 do
  begin
    FRowsReader.Read;
    for Matrix := 0 to NMatrices - 1 do
      for Col := 0 to NZones - 1 do
        FReadValues[Matrix, Row, Col] := FRowsReader[Matrix, Col];
  end;
end;

procedure TMatrixRowsReaderTests.TearDown;
begin
  FRowsReader.Free;
  FRowsReader := nil;
  FReadValues.Free;
  FReadValues := nil;
  FReference.Free;
  FReference := nil;
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
  if (FMtpFile <> '') and TFile.Exists(FMtpFile) then
    TFile.Delete(FMtpFile);
  FMtpFile := '';
end;

procedure TMatrixRowsReaderTests.RowsReader_Float64_ValuesPreserved;
var
  Mismatch: string;
begin
  Mismatch := CompareAll(FReference, FReadValues, TolExact);
  Assert.IsEmpty(Mismatch, 'RowsReader float64: ' + Mismatch);
end;

procedure TMatrixRowsReaderTests.RowsReader_FileLabel_Preserved;
var
  Props: TKeyValuePairs;
  RowsReader: TMatrixRowsReader;
begin
  // txt does not store a file label; use the Minutp file written in Setup
  Props := MakeProps(FMtpFile, 'mtp');
  Props.Append('prec', '0');
  RowsReader := TMatrixRowsReader.Create(Props, NMatrices, NZones);
  try
    Assert.AreEqual('TestFile', RowsReader.FileLabel);
  finally
    RowsReader.Free;
  end;
end;

procedure TMatrixRowsReaderTests.RowsReader_MatrixLabels_Preserved;
begin
  Assert.AreEqual('MATRIX_A', FRowsReader.MatrixLabels[0]);
  Assert.AreEqual('MATRIX_B', FRowsReader.MatrixLabels[1]);
end;

procedure TMatrixRowsReaderTests.RowsReader_SelectByIndex_CountIs1;
var
  RowsReader: TMatrixRowsReader;
begin
  RowsReader := TMatrixRowsReader.Create(MakeProps(FTempFile, 'txt'), [1], NZones);
  try
    Assert.AreEqual(1, RowsReader.Count);
  finally
    RowsReader.Free;
  end;
end;

procedure TMatrixRowsReaderTests.RowsReader_SelectByLabel_LabelCorrect;
var
  RowsReader: TMatrixRowsReader;
begin
  RowsReader := TMatrixRowsReader.Create(MakeProps(FTempFile, 'txt'), ['MATRIX_A'], NZones);
  try
    Assert.AreEqual('MATRIX_A', RowsReader.MatrixLabels[0]);
  finally
    RowsReader.Free;
  end;
end;

procedure TMatrixRowsReaderTests.RowsReader_PastEnd_Zeroes;
var
  RowsReader: TMatrixRowsReader;
  Col: Integer;
begin
  RowsReader := TMatrixRowsReader.Create(MakeProps(FTempFile, 'txt'), NMatrices, NZones);
  try
    for var Row := 0 to NZones - 1 do
      RowsReader.Read;
    // One read past the last row must zero all values
    RowsReader.Read;
    for Col := 0 to NZones - 1 do
    begin
      Assert.AreEqual(0.0, RowsReader[0, Col], TolExact);
      Assert.AreEqual(0.0, RowsReader[1, Col], TolExact);
    end;
  finally
    RowsReader.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TMatrixRowsWriterTests
////////////////////////////////////////////////////////////////////////////////

function TMatrixRowsWriterTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'matio_io_w_' + IntToStr(GetCurrentThreadId) + '.txt');
  FTempFile := Result;
end;

procedure TMatrixRowsWriterTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TMatrixRowsWriterTests.RowsWriter_Float64_ValuesPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  RowsWriter: TMatrixRowsWriter;
  Labels: TArray<string>;
  Row, Matrix, Col: Integer;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    SetLength(Labels, NMatrices);
    for Matrix := 0 to NMatrices - 1 do Labels[Matrix] := Written.MatrixLabels[Matrix];
    RowsWriter := TMatrixRowsWriter.Create(MakeProps(TempFile, 'txt'),
                                           Written.FileLabel, Labels, NZones);
    try
      for Row := 0 to NZones - 1 do
      begin
        for Matrix := 0 to NMatrices - 1 do
          for Col := 0 to NZones - 1 do
            RowsWriter[Matrix, Col] := Written[Matrix, Row, Col];
        RowsWriter.Write;
      end;
    finally
      RowsWriter.Free;
    end;
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeProps(TempFile, 'txt'));
      Mismatch := CompareAll(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'RowsWriter float64: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

end.
