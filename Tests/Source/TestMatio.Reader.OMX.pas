unit TestMatio.Reader.OMX;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the OMX/HDF5 matrix reader.
// All tests are skipped gracefully when the HDF5 DLL is unavailable.
//
// The OMX format identifies matrices by name only and does not define a matrix
// order. example.omx contains 8 matrices; the txt reference file contains the
// IVT and TRANSFERS matrices, so those are selected by label for comparison.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  TOMXReaderTests = class(TReaderTests)
  strict private
    FTxt: TFloat64Matrices;
    FOMx: TFloat64Matrices;
    FAvailable: Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure OMX_Size_Is485;
    [Test] procedure OMXMatchesTxt_AllCells;
    [Test] procedure OMX_SelectByLabel_Transfers_CountIs1;
    [Test] procedure OMX_SelectByLabel_Transfers_LabelCorrect;
    // OMX identifies matrices by name only: the format is unordered
    [Test] procedure OMX_UnorderedReader_CountIs8;
    [Test] procedure OMX_UnorderedReader_LabelsAlphabetical;
    [Test] procedure OMX_SelectByIndex_Raises;
    [Test] procedure OMX_CreateReader_DefaultOrdered_Raises;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio.reader, matio.formats;

const
  // The txt reference file stores values rounded to 3 decimals; the omx file
  // holds the unrounded float32 values, so differences up to 5e-4 are expected
  TolOMX = 5e-4;

procedure TOMXReaderTests.Setup;
begin
  FAvailable := MatrixFormats.ReaderFormat('omx').Available;
  if not FAvailable then Exit;
  FTxt := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
  // Select the two reference matrices by label
  FOMx := TFloat64Matrices.Create(2, 485);
  FOMx.Read(MakeProps(DataDir + 'example.omx', 'omx'), ['IVT', 'TRANSFERS']);
end;

procedure TOMXReaderTests.TearDown;
begin
  FTxt.Free;
  FOMx.Free;
end;

procedure TOMXReaderTests.OMX_Size_Is485;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Assert.AreEqual(485, FOMx.Size);
end;

procedure TOMXReaderTests.OMXMatchesTxt_AllCells;
var
  Mismatch: string;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Mismatch := CompareMatrices(FTxt, FOMx, TolOMX);
  Assert.IsEmpty(Mismatch, 'omx vs txt: ' + Mismatch);
end;

procedure TOMXReaderTests.OMX_SelectByLabel_Transfers_CountIs1;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.omx', 'omx');
  Reader := MatrixFormats.CreateReader(Props, ['TRANSFERS']);
  try
    Assert.AreEqual(1, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TOMXReaderTests.OMX_SelectByLabel_Transfers_LabelCorrect;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.omx', 'omx');
  Reader := MatrixFormats.CreateReader(Props, ['TRANSFERS']);
  try
    Assert.AreEqual('TRANSFERS', Reader.MatrixLabels[0]);
  finally
    Reader.Free;
  end;
end;

procedure TOMXReaderTests.OMX_UnorderedReader_CountIs8;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.omx', 'omx');
  Reader := MatrixFormats.CreateReader(Props, {Ordered:}false);
  try
    Assert.AreEqual(8, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TOMXReaderTests.OMX_UnorderedReader_LabelsAlphabetical;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.omx', 'omx');
  Reader := MatrixFormats.CreateReader(Props, {Ordered:}false);
  try
    Assert.AreEqual('FARE',      Reader.MatrixLabels[0]);
    Assert.AreEqual('IVT',       Reader.MatrixLabels[1]);
    Assert.AreEqual('TRANSFERS', Reader.MatrixLabels[6]);
    Assert.AreEqual('TWT',       Reader.MatrixLabels[7]);
  finally
    Reader.Free;
  end;
end;

procedure TOMXReaderTests.OMX_SelectByIndex_Raises;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeProps(DataDir + 'example.omx', 'omx'), [0]);
      Reader.Free;
    end,
    Exception);
end;

procedure TOMXReaderTests.OMX_CreateReader_DefaultOrdered_Raises;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping OMX tests');
    Exit;
  end;
  // Reading all matrices requires the caller to acknowledge the missing
  // matrix order by passing Ordered=false
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeProps(DataDir + 'example.omx', 'omx'));
      Reader.Free;
    end,
    Exception);
end;

end.
