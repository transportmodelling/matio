unit TestMatio.IO;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for TMatrixRowsReader, TMatrixReaderRows, TMemoryMatrixRowsReader
// and TMatrixRowsWriter.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, KeyVal, matio.reader, matio.matrix, matio.io;

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
  // TMatrixReaderRows: row storage over an existing, shared reader
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMatrixReaderRowsTests = class(TIOTests)
  strict private
    FTempFile: string;
    FReference: TFloat64Matrices;
    FReader: TMatrixReader;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure ReaderRows_ValuesPreserved;
    [Test] procedure ReaderRows_MatrixLabels_Preserved;
    [Test] procedure ReaderRows_PastEnd_Zeroes;
    [Test] procedure ReaderRows_ExplicitCountSize_Used;
    [Test] procedure ReaderRows_NilReader_Raises;
  end;

  // ---------------------------------------------------------------------------
  // TMemoryMatrixRowsReader: rows read in place from in-memory matrices
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMemoryMatrixRowsReaderTests = class(TIOTests)
  strict private
    FMatrices: TFloat64Matrices;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure MemoryRows_ValuesPreserved;
    [Test] procedure MemoryRows_Labels_Preserved;
    [Test] procedure MemoryRows_RowIndex_Advances;
    [Test] procedure MemoryRows_PastEnd_Zeroes;
    [Test] procedure MemoryRows_NoCopy_SeesLaterChanges;
    [Test] procedure MemoryRows_NilMatrices_Raises;
  end;

  // ---------------------------------------------------------------------------
  // TMemoryMatrixReader / TMemoryMatrixReaderRows: a shared reader hands out
  // each row once, to whichever rows object asks first
  // ---------------------------------------------------------------------------
  [TestFixture]
  TMemoryMatrixReaderRowsTests = class(TIOTests)
  strict private
    FMatrices: TFloat64Matrices;
    FReader: TMemoryMatrixReader;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure MemoryReaderRows_SharedReader_Alternate;
    [Test] procedure MemoryReaderRows_Threads_EachRowOnce;
    [Test] procedure MemoryReaderRows_NilReader_Raises;
    [Test] procedure MemoryReader_NilMatrices_Raises;
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
  Winapi.Windows, SysUtils, IOUtils, Math, System.Threading, matio, matio.formats;

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
// TMatrixReaderRowsTests
////////////////////////////////////////////////////////////////////////////////

procedure TMatrixReaderRowsTests.Setup;
begin
  FTempFile := TPath.Combine(TPath.GetTempPath,
    'matio_io_rr_' + IntToStr(GetCurrentThreadId) + '.txt');
  FReference := BuildTestMatrices;
  FReference.Save(MakeProps(FTempFile, 'txt'));
  // The reader is owned by the fixture, not by the rows objects that reference it
  FReader := MatrixFormats.CreateReader(MakeProps(FTempFile, 'txt'));
end;

procedure TMatrixReaderRowsTests.TearDown;
begin
  FReader.Free;
  FReader := nil;
  FReference.Free;
  FReference := nil;
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TMatrixReaderRowsTests.ReaderRows_ValuesPreserved;
var
  ReadValues: TFloat64Matrices;
  Rows: TMatrixReaderRows;
  Row, Matrix, Col: Integer;
  Mismatch: string;
begin
  ReadValues := TFloat64Matrices.Create(NMatrices, NZones);
  try
    // The text reader discovers its size while reading, so pass it explicitly
    Rows := TMatrixReaderRows.Create(FReader, NMatrices, NZones);
    try
      Assert.AreEqual(NMatrices, Rows.Count);
      Assert.AreEqual(NZones, Rows.Size);
      for Row := 0 to NZones - 1 do
      begin
        Rows.Read;
        for Matrix := 0 to NMatrices - 1 do
          for Col := 0 to NZones - 1 do
            ReadValues[Matrix, Row, Col] := Rows[Matrix, Col];
      end;
    finally
      Rows.Free;
    end;
    Mismatch := CompareAll(FReference, ReadValues, TolExact);
    Assert.IsEmpty(Mismatch, 'ReaderRows: ' + Mismatch);
  finally
    ReadValues.Free;
  end;
end;

procedure TMatrixReaderRowsTests.ReaderRows_MatrixLabels_Preserved;
var
  Rows: TMatrixReaderRows;
begin
  Rows := TMatrixReaderRows.Create(FReader, NMatrices, NZones);
  try
    Assert.AreEqual('MATRIX_A', Rows.MatrixLabels[0]);
    Assert.AreEqual('MATRIX_B', Rows.MatrixLabels[1]);
  finally
    Rows.Free;
  end;
end;

procedure TMatrixReaderRowsTests.ReaderRows_PastEnd_Zeroes;
var
  Rows: TMatrixReaderRows;
  Col: Integer;
begin
  Rows := TMatrixReaderRows.Create(FReader, NMatrices, NZones);
  try
    for var Row := 0 to NZones - 1 do
      Rows.Read;
    // One read past the last row must zero all values
    Rows.Read;
    for Col := 0 to NZones - 1 do
    begin
      Assert.AreEqual(0.0, Rows[0, Col], TolExact);
      Assert.AreEqual(0.0, Rows[1, Col], TolExact);
    end;
  finally
    Rows.Free;
  end;
end;

procedure TMatrixReaderRowsTests.ReaderRows_ExplicitCountSize_Used;
var
  Rows: TMatrixReaderRows;
  Col: Integer;
begin
  // One extra matrix and one extra column: the surplus must read as zero
  Rows := TMatrixReaderRows.Create(FReader, NMatrices + 1, NZones + 1);
  try
    Assert.AreEqual(NMatrices + 1, Rows.Count);
    Assert.AreEqual(NZones + 1, Rows.Size);
    Rows.Read;
    for Col := 0 to NZones - 1 do
      Assert.AreEqual(FReference[0, 0, Col], Rows[0, Col], TolExact);
    Assert.AreEqual(0.0, Rows[0, NZones], TolExact);
    for Col := 0 to NZones do
      Assert.AreEqual(0.0, Rows[NMatrices, Col], TolExact);
  finally
    Rows.Free;
  end;
end;

procedure TMatrixReaderRowsTests.ReaderRows_NilReader_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMatrixReaderRows.Create(nil).Free;
    end,
    Exception);
end;

////////////////////////////////////////////////////////////////////////////////
// TMemoryMatrixRowsReaderTests
////////////////////////////////////////////////////////////////////////////////

procedure TMemoryMatrixRowsReaderTests.Setup;
begin
  FMatrices := BuildTestMatrices;
end;

procedure TMemoryMatrixRowsReaderTests.TearDown;
begin
  FMatrices.Free;
  FMatrices := nil;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_ValuesPreserved;
var
  ReadValues: TFloat64Matrices;
  Rows: TMemoryMatrixRowsReader;
  Row, Matrix, Col: Integer;
  Mismatch: string;
begin
  ReadValues := TFloat64Matrices.Create(NMatrices, NZones);
  try
    Rows := TMemoryMatrixRowsReader.Create(FMatrices);
    try
      Assert.AreEqual(NMatrices, Rows.Count);
      Assert.AreEqual(NZones, Rows.Size);
      for Row := 0 to NZones - 1 do
      begin
        Rows.Read;
        for Matrix := 0 to NMatrices - 1 do
          for Col := 0 to NZones - 1 do
            ReadValues[Matrix, Row, Col] := Rows[Matrix, Col];
      end;
    finally
      Rows.Free;
    end;
    Mismatch := CompareAll(FMatrices, ReadValues, TolExact);
    Assert.IsEmpty(Mismatch, 'MemoryRows: ' + Mismatch);
  finally
    ReadValues.Free;
  end;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_Labels_Preserved;
var
  Rows: TMemoryMatrixRowsReader;
begin
  Rows := TMemoryMatrixRowsReader.Create(FMatrices);
  try
    Assert.AreEqual('TestFile', Rows.FileLabel);
    Assert.AreEqual('MATRIX_A', Rows.MatrixLabels[0]);
    Assert.AreEqual('MATRIX_B', Rows.MatrixLabels[1]);
  finally
    Rows.Free;
  end;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_PastEnd_Zeroes;
var
  Rows: TMemoryMatrixRowsReader;
  Col: Integer;
begin
  Rows := TMemoryMatrixRowsReader.Create(FMatrices);
  try
    for var Row := 0 to NZones - 1 do
      Rows.Read;
    // One read past the last row must yield zeroes
    Rows.Read;
    for Col := 0 to NZones - 1 do
    begin
      Assert.AreEqual(0.0, Rows[0, Col], TolExact);
      Assert.AreEqual(0.0, Rows[1, Col], TolExact);
    end;
  finally
    Rows.Free;
  end;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_NoCopy_SeesLaterChanges;
var
  Rows: TMemoryMatrixRowsReader;
begin
  Rows := TMemoryMatrixRowsReader.Create(FMatrices);
  try
    Rows.Read;
    Assert.AreEqual(FMatrices[1, 0, 2], Rows[1, 2], TolExact);
    // A change to the matrices after Read must be visible, as no values are copied
    FMatrices[1, 0, 2] := -1.5;
    Assert.AreEqual(-1.5, Rows[1, 2], TolExact);
  finally
    Rows.Free;
  end;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_RowIndex_Advances;
var
  Rows: TMemoryMatrixRowsReader;
  Row: Integer;
begin
  Rows := TMemoryMatrixRowsReader.Create(FMatrices);
  try
    for Row := 0 to NZones - 1 do
    begin
      Rows.Read;
      Assert.AreEqual(Row, Rows.Row);
    end;
    Rows.Read;
    Assert.IsTrue(Rows.Row >= Rows.Size, 'Row past end must be >= Size');
  finally
    Rows.Free;
  end;
end;

procedure TMemoryMatrixRowsReaderTests.MemoryRows_NilMatrices_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMemoryMatrixRowsReader.Create(nil).Free;
    end,
    Exception);
end;

////////////////////////////////////////////////////////////////////////////////
// TMemoryMatrixReaderRowsTests
////////////////////////////////////////////////////////////////////////////////

procedure TMemoryMatrixReaderRowsTests.Setup;
begin
  FMatrices := BuildTestMatrices;
  // The reader is owned by the fixture, not by the rows objects that reference it
  FReader := TMemoryMatrixReader.Create(FMatrices);
end;

procedure TMemoryMatrixReaderRowsTests.TearDown;
begin
  FReader.Free;
  FReader := nil;
  FMatrices.Free;
  FMatrices := nil;
end;

procedure TMemoryMatrixReaderRowsTests.MemoryReaderRows_SharedReader_Alternate;
var
  RowsA, RowsB: TMemoryMatrixReaderRows;
  Col: Integer;
begin
  RowsA := TMemoryMatrixReaderRows.Create(FReader);
  RowsB := TMemoryMatrixReaderRows.Create(FReader);
  try
    // Two rows objects on one reader obtain consecutive rows, not the same row
    RowsA.Read;
    RowsB.Read;
    Assert.AreEqual(0, RowsA.Row);
    Assert.AreEqual(1, RowsB.Row);
    for Col := 0 to NZones - 1 do
    begin
      Assert.AreEqual(FMatrices[1, 0, Col], RowsA[1, Col], TolExact);
      Assert.AreEqual(FMatrices[1, 1, Col], RowsB[1, Col], TolExact);
    end;
    RowsA.Read;
    Assert.AreEqual(2, RowsA.Row);
    Assert.AreEqual(FMatrices[0, 2, 3], RowsA[0, 3], TolExact);
  finally
    RowsB.Free;
    RowsA.Free;
  end;
end;

procedure TMemoryMatrixReaderRowsTests.MemoryReaderRows_Threads_EachRowOnce;
const
  NThreads = 4;
var
  Reader: TMemoryMatrixReader;
  Seen: TArray<Integer>;   // Number of times each row was handed out
  Totals: TArray<Double>;  // Total of matrix 1 as seen by the thread that handled the row
  Tasks: TArray<ITask>;
  Row, Col: Integer;
  Expected: Double;
begin
  Reader := FReader;
  SetLength(Seen, NZones);
  SetLength(Totals, NZones);
  SetLength(Tasks, NThreads);
  for var T := 0 to NThreads - 1 do
    Tasks[T] := TTask.Run(
      procedure
      var
        Rows: TMemoryMatrixReaderRows;
      begin
        Rows := TMemoryMatrixReaderRows.Create(Reader);
        try
          repeat
            // Readers are not thread safe: the caller serializes the calls to Read
            TMonitor.Enter(Reader);
            try
              Rows.Read;
            finally
              TMonitor.Exit(Reader);
            end;
            if Rows.Row >= NZones then Break;
            AtomicIncrement(Seen[Rows.Row]);
            Totals[Rows.Row] := Rows.Total(1);
          until False;
        finally
          Rows.Free;
        end;
      end);
  TTask.WaitForAll(Tasks);
  for Row := 0 to NZones - 1 do
  begin
    Assert.AreEqual(1, Seen[Row], 'row ' + IntToStr(Row) + ' handed out once');
    Expected := 0.0;
    for Col := 0 to NZones - 1 do Expected := Expected + FMatrices[1, Row, Col];
    Assert.AreEqual(Expected, Totals[Row], TolExact, 'row ' + IntToStr(Row) + ' total');
  end;
end;

procedure TMemoryMatrixReaderRowsTests.MemoryReaderRows_NilReader_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMemoryMatrixReaderRows.Create(nil).Free;
    end,
    Exception);
end;

procedure TMemoryMatrixReaderRowsTests.MemoryReader_NilMatrices_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TMemoryMatrixReader.Create(nil).Free;
    end,
    Exception);
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
