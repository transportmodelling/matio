unit TestMatio.Enum;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for TMatrixEnumReader and TMatrixEnumWriter.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, KeyVal, matio.matrix;

type
  // ---------------------------------------------------------------------------
  // Shared helpers for both enum test fixtures
  // ---------------------------------------------------------------------------
  TEnumTests = class
  protected
    function BuildTestMatrices: TFloat64Matrices;
    function MakeProps(const FileName, Format: string): TKeyValuePairs;
    function CompareAll(A, B: TFloat64Matrices; Tol: Double): string;
  end;

  // ---------------------------------------------------------------------------
  // TMatrixEnumWriter: write one matrix row at a time, flush with NextRow
  // ---------------------------------------------------------------------------
  [TestFixture]
  TEnumWriterTests = class(TEnumTests)
  strict private
    FTempFile: string;
    function MakeTempFile: string;
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure EnumWriter_Float64_ValuesPreserved;
    [Test] procedure EnumWriter_Float64_FixedRows_ValuesPreserved;
    [Test] procedure EnumWriter_MatrixLabelsPreserved;
    [Test] procedure EnumWriter_TooManyMatrices_Raises;
  end;

  // ---------------------------------------------------------------------------
  // TMatrixEnumReader: read one matrix row at a time, advance with NextRow
  // ---------------------------------------------------------------------------
  [TestFixture]
  TEnumReaderTests = class(TEnumTests)
  strict private
    FTempFile: string;
    function MakeTempFile: string;
    procedure WriteTestFile(const FileName: string);
  public
    [TearDown]
    procedure TearDown;
    [Test] procedure EnumReader_Float64_ValuesPreserved;
    [Test] procedure EnumReader_Float32_ValuesPreserved;
    [Test] procedure EnumReader_MixedFloatTypes_Raises;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  Winapi.Windows, SysUtils, IOUtils, Math, matio, matio.reader,
  matio.writer, matio.formats;

const
  NMatrices = 2;
  NZones    = 5;
  TolExact  = 1e-9;
  TolF32    = 1e-3;

////////////////////////////////////////////////////////////////////////////////
// TEnumTests
////////////////////////////////////////////////////////////////////////////////

function TEnumTests.BuildTestMatrices: TFloat64Matrices;
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

function TEnumTests.MakeProps(const FileName, Format: string): TKeyValuePairs;
begin
  // Result may alias the caller's destination variable; clear before appending
  Result.Clear;
  Result.Append('file', FileName);
  Result.Append('format', Format);
  if SameText(Format, 'txt') then
    Result.Append('delim', 'tab');
end;

function TEnumTests.CompareAll(A, B: TFloat64Matrices; Tol: Double): string;
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
// TEnumWriterTests
////////////////////////////////////////////////////////////////////////////////

function TEnumWriterTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'matio_enum_w_' + IntToStr(GetCurrentThreadId) + '.txt');
  FTempFile := Result;
end;

procedure TEnumWriterTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TEnumWriterTests.EnumWriter_Float64_ValuesPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  EnumWriter: TMatrixEnumWriter;
  RowData: TFloat64MatrixRow;
  Labels: TArray<string>;
  Row, Col, Matrix: Integer;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    SetLength(Labels, NMatrices);
    for Matrix := 0 to NMatrices - 1 do Labels[Matrix] := Written.MatrixLabels[Matrix];
    EnumWriter := MatrixFormats.CreateEnumWriter(MakeProps(TempFile, 'txt'),
                                                 Written.FileLabel, Labels, NZones);
    try
      SetLength(RowData, NZones);
      for Row := 0 to NZones - 1 do
      begin
        for Matrix := 0 to NMatrices - 1 do
        begin
          for Col := 0 to NZones - 1 do
            RowData[Col] := Written[Matrix, Row, Col];
          EnumWriter.Write(RowData);
        end;
        EnumWriter.NextRow;
      end;
    finally
      EnumWriter.Free;
    end;
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeProps(TempFile, 'txt'));
      Mismatch := CompareAll(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'EnumWriter float64: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TEnumWriterTests.EnumWriter_Float64_FixedRows_ValuesPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  EnumWriter: TMatrixEnumWriter;
  RowData: TFloat64MatrixRow;
  Labels: TArray<string>;
  Row, Col, Matrix: Integer;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    SetLength(Labels, NMatrices);
    for Matrix := 0 to NMatrices - 1 do Labels[Matrix] := Written.MatrixLabels[Matrix];
    EnumWriter := MatrixFormats.CreateEnumWriter(MakeProps(TempFile, 'txt'),
                                                 Written.FileLabel, Labels, NZones,
                                                 {FixedRows=}true);
    try
      for Row := 0 to NZones - 1 do
      begin
        for Matrix := 0 to NMatrices - 1 do
        begin
          // Fresh array per call — caller guarantees not to modify it after Write
          SetLength(RowData, NZones);
          for Col := 0 to NZones - 1 do
            RowData[Col] := Written[Matrix, Row, Col];
          EnumWriter.Write(RowData);
        end;
        EnumWriter.NextRow;
      end;
    finally
      EnumWriter.Free;
    end;
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeProps(TempFile, 'txt'));
      Mismatch := CompareAll(Written, ReadBack, TolExact);
      Assert.IsEmpty(Mismatch, 'EnumWriter FixedRows float64: ' + Mismatch);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TEnumWriterTests.EnumWriter_MatrixLabelsPreserved;
var
  TempFile: string;
  Written, ReadBack: TFloat64Matrices;
  EnumWriter: TMatrixEnumWriter;
  RowData: TFloat64MatrixRow;
  Labels: TArray<string>;
  Row, Col, Matrix: Integer;
begin
  TempFile := MakeTempFile;
  Written := BuildTestMatrices;
  try
    SetLength(Labels, NMatrices);
    for Matrix := 0 to NMatrices - 1 do Labels[Matrix] := Written.MatrixLabels[Matrix];
    EnumWriter := MatrixFormats.CreateEnumWriter(MakeProps(TempFile, 'txt'),
                                                 Written.FileLabel, Labels, NZones);
    try
      SetLength(RowData, NZones);
      for Row := 0 to NZones - 1 do
      begin
        for Matrix := 0 to NMatrices - 1 do
        begin
          for Col := 0 to NZones - 1 do
            RowData[Col] := Written[Matrix, Row, Col];
          EnumWriter.Write(RowData);
        end;
        EnumWriter.NextRow;
      end;
    finally
      EnumWriter.Free;
    end;
    ReadBack := TFloat64Matrices.Create(NMatrices, NZones);
    try
      ReadBack.Read(MakeProps(TempFile, 'txt'));
      Assert.AreEqual('MATRIX_A', ReadBack.MatrixLabels[0]);
      Assert.AreEqual('MATRIX_B', ReadBack.MatrixLabels[1]);
    finally
      ReadBack.Free;
    end;
  finally
    Written.Free;
  end;
end;

procedure TEnumWriterTests.EnumWriter_TooManyMatrices_Raises;
var
  TempFile: string;
  EnumWriter: TMatrixEnumWriter;
  RowData: TFloat64MatrixRow;
begin
  TempFile := MakeTempFile;
  EnumWriter := MatrixFormats.CreateEnumWriter(MakeProps(TempFile, 'txt'),
                                               '', NMatrices, NZones);
  try
    SetLength(RowData, NZones);
    // Write exactly NMatrices rows (fills the per-row buffer)
    for var Matrix := 0 to NMatrices - 1 do
      EnumWriter.Write(RowData);
    // One more write before NextRow must raise
    Assert.WillRaise(
      procedure begin EnumWriter.Write(RowData); end,
      Exception);
  finally
    EnumWriter.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TEnumReaderTests
////////////////////////////////////////////////////////////////////////////////

procedure TEnumReaderTests.WriteTestFile(const FileName: string);
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

function TEnumReaderTests.MakeTempFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    'matio_enum_r_' + IntToStr(GetCurrentThreadId) + '.txt');
  FTempFile := Result;
end;

procedure TEnumReaderTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TEnumReaderTests.EnumReader_Float64_ValuesPreserved;
var
  TempFile: string;
  Reference, ReadValues: TFloat64Matrices;
  EnumReader: TMatrixEnumReader;
  RowData: TFloat64MatrixRow;
  Row, Col, Matrix: Integer;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  WriteTestFile(TempFile);
  Reference := BuildTestMatrices;
  try
    EnumReader := MatrixFormats.CreateEnumReader(MakeProps(TempFile, 'txt'),
                                                 NMatrices, NZones);
    try
      ReadValues := TFloat64Matrices.Create(NMatrices, NZones);
      try
        SetLength(RowData, NZones);
        for Row := 0 to NZones - 1 do
        begin
          for Matrix := 0 to NMatrices - 1 do
          begin
            EnumReader.Read(RowData);
            for Col := 0 to NZones - 1 do
              ReadValues[Matrix, Row, Col] := RowData[Col];
          end;
          EnumReader.NextRow;
        end;
        Mismatch := CompareAll(Reference, ReadValues, TolExact);
        Assert.IsEmpty(Mismatch, 'EnumReader float64: ' + Mismatch);
      finally
        ReadValues.Free;
      end;
    finally
      EnumReader.Free;
    end;
  finally
    Reference.Free;
  end;
end;

procedure TEnumReaderTests.EnumReader_Float32_ValuesPreserved;
var
  TempFile: string;
  Reference, ReadValues: TFloat64Matrices;
  EnumReader: TMatrixEnumReader;
  RowF32: TFloat32MatrixRow;
  Row, Col, Matrix: Integer;
  Mismatch: string;
begin
  TempFile := MakeTempFile;
  WriteTestFile(TempFile);
  Reference := BuildTestMatrices;
  try
    EnumReader := MatrixFormats.CreateEnumReader(MakeProps(TempFile, 'txt'),
                                                 NMatrices, NZones);
    try
      ReadValues := TFloat64Matrices.Create(NMatrices, NZones);
      try
        SetLength(RowF32, NZones);
        for Row := 0 to NZones - 1 do
        begin
          for Matrix := 0 to NMatrices - 1 do
          begin
            EnumReader.Read(RowF32);
            for Col := 0 to NZones - 1 do
              ReadValues[Matrix, Row, Col] := RowF32[Col];
          end;
          EnumReader.NextRow;
        end;
        Mismatch := CompareAll(Reference, ReadValues, TolF32);
        Assert.IsEmpty(Mismatch, 'EnumReader float32: ' + Mismatch);
      finally
        ReadValues.Free;
      end;
    finally
      EnumReader.Free;
    end;
  finally
    Reference.Free;
  end;
end;

procedure TEnumReaderTests.EnumReader_MixedFloatTypes_Raises;
var
  TempFile: string;
  EnumReader: TMatrixEnumReader;
  RowF64: TFloat64MatrixRow;
  RowF32: TFloat32MatrixRow;
begin
  TempFile := MakeTempFile;
  WriteTestFile(TempFile);
  EnumReader := MatrixFormats.CreateEnumReader(MakeProps(TempFile, 'txt'),
                                               NMatrices, NZones);
  try
    SetLength(RowF64, NZones);
    SetLength(RowF32, NZones);
    // First call sets FloatType to ftFloat64 and reads all matrices for this row
    EnumReader.Read(RowF64);
    // Switching to float32 mid-row must raise 'Inconsistent row type'
    Assert.WillRaise(
      procedure begin EnumReader.Read(RowF32); end,
      Exception);
  finally
    EnumReader.Free;
  end;
end;

end.
