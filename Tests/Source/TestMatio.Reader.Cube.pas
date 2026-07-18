unit TestMatio.Reader.Cube;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the Bentley OpenPaths CUBE matrix reader.
// All tests are skipped gracefully when the HDF5 DLL is unavailable.
//
// Like OMX, the Cube matrix format is HDF5 based and identifies matrices by
// name only. example.cube-matrix contains 8 matrices; the txt reference file
// contains the IVT and TRANSFERS matrices, so those are selected by label.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  TCubeReaderTests = class(TReaderTests)
  strict private
    FTxt: TFloat64Matrices;
    FCube: TFloat64Matrices;
    FAvailable: Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure Cube_Size_Is485;
    [Test] procedure CubeMatchesTxt_AllCells;
    [Test] procedure Cube_SelectByLabel_Transfers_CountIs1;
    [Test] procedure Cube_SelectByLabel_Transfers_LabelCorrect;
    // Cube matrix files identify matrices by name only: the format is unordered
    [Test] procedure Cube_UnorderedReader_CountIs8;
    [Test] procedure Cube_SelectByIndex_Raises;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio.reader, matio.formats;

const
  // The txt reference file stores values rounded to 3 decimals; the cube file
  // holds the unrounded float32 values, so differences up to 5e-4 are expected
  TolCube = 5e-4;

procedure TCubeReaderTests.Setup;
begin
  FAvailable := MatrixFormats.ReaderFormat('cube').Available;
  if not FAvailable then Exit;
  FTxt := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
  // Select the two reference matrices by label
  FCube := TFloat64Matrices.Create(2, 485);
  FCube.Read(MakeProps(DataDir + 'example.cube-matrix', 'cube'), ['IVT', 'TRANSFERS']);
end;

procedure TCubeReaderTests.TearDown;
begin
  FTxt.Free;
  FCube.Free;
end;

procedure TCubeReaderTests.Cube_Size_Is485;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Assert.AreEqual(485, FCube.Size);
end;

procedure TCubeReaderTests.CubeMatchesTxt_AllCells;
var
  Mismatch: string;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Mismatch := CompareMatrices(FTxt, FCube, TolCube);
  Assert.IsEmpty(Mismatch, 'cube vs txt: ' + Mismatch);
end;

procedure TCubeReaderTests.Cube_SelectByLabel_Transfers_CountIs1;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.cube-matrix', 'cube');
  Reader := MatrixFormats.CreateReader(Props, ['TRANSFERS']);
  try
    Assert.AreEqual(1, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TCubeReaderTests.Cube_SelectByLabel_Transfers_LabelCorrect;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.cube-matrix', 'cube');
  Reader := MatrixFormats.CreateReader(Props, ['TRANSFERS']);
  try
    Assert.AreEqual('TRANSFERS', Reader.MatrixLabels[0]);
  finally
    Reader.Free;
  end;
end;

procedure TCubeReaderTests.Cube_UnorderedReader_CountIs8;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Props := MakeProps(DataDir + 'example.cube-matrix', 'cube');
  Reader := MatrixFormats.CreateReader(Props, {Ordered:}false);
  try
    Assert.AreEqual(8, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TCubeReaderTests.Cube_SelectByIndex_Raises;
begin
  if not FAvailable then
  begin
    Assert.Pass('HDF5 DLL not available — skipping Cube tests');
    Exit;
  end;
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeProps(DataDir + 'example.cube-matrix', 'cube'), [0]);
      Reader.Free;
    end,
    Exception);
end;

end.
