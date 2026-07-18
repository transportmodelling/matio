unit TestMatio.Reader.Masked;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for TMaskedMatrixReader (matrix sub-selection by index or label).
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, TestMatio.Reader;

type
  [TestFixture]
  TMaskedReaderTests = class(TReaderTests)
  public
    // Multi-item selection by index (reversed order)
    [Test] procedure MultiIndex_Count_Is2;
    [Test] procedure MultiIndex_Labels_AreInSelectionOrder;
    [Test] procedure MultiIndex_Values_AreInSelectionOrder;
    // Error conditions
    [Test] procedure DuplicateIndex_Raises;
    [Test] procedure OutOfRangeIndex_Raises;
    [Test] procedure UnknownLabel_Raises;
    [Test] procedure EmptyIndexSelection_Raises;
    [Test] procedure EmptyLabelSelection_Raises;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio.reader, matio.matrix, matio.formats;

const
  TolExact = 1e-9;

procedure TMaskedReaderTests.MultiIndex_Count_Is2;
var
  Reader: TMatrixReader;
begin
  // Select TRANSFERS (1) then IVT (0) — reversed order
  Reader := MatrixFormats.CreateReader(MakeTxtProps(DataDir + 'example.txt', 'tab'), [1, 0]);
  try
    Assert.AreEqual(2, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TMaskedReaderTests.MultiIndex_Labels_AreInSelectionOrder;
var
  Reader: TMatrixReader;
begin
  Reader := MatrixFormats.CreateReader(MakeTxtProps(DataDir + 'example.txt', 'tab'), [1, 0]);
  try
    Assert.AreEqual('TRANSFERS', Reader.MatrixLabels[0]);
    Assert.AreEqual('IVT',       Reader.MatrixLabels[1]);
  finally
    Reader.Free;
  end;
end;

procedure TMaskedReaderTests.MultiIndex_Values_AreInSelectionOrder;
var
  Selected: TFloat64Matrices;
begin
  Selected := TFloat64Matrices.Create(2, 485);
  try
    Selected.Read(MakeTxtProps(DataDir + 'example.txt', 'tab'), [1, 0]);
    // Selection index 0 = file matrix 1 (TRANSFERS): row 1 col 3 = 0.025
    Assert.AreEqual(0.025, Selected[0, 0, 2], TolExact);
    // Selection index 1 = file matrix 0 (IVT): row 1 col 2 = 4.65
    Assert.AreEqual(4.65,  Selected[1, 0, 1], TolExact);
  finally
    Selected.Free;
  end;
end;

procedure TMaskedReaderTests.DuplicateIndex_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeTxtProps(DataDir + 'example.txt', 'tab'), [0, 0]);
      Reader.Free;
    end,
    Exception);
end;

procedure TMaskedReaderTests.OutOfRangeIndex_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeTxtProps(DataDir + 'example.txt', 'tab'), [99]);
      Reader.Free;
    end,
    Exception);
end;

procedure TMaskedReaderTests.UnknownLabel_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
    begin
      Reader := MatrixFormats.CreateReader(
        MakeTxtProps(DataDir + 'example.txt', 'tab'), ['NONEXISTENT']);
      Reader.Free;
    end,
    Exception);
end;

procedure TMaskedReaderTests.EmptyIndexSelection_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
      Empty: TArray<Integer>;
    begin
      SetLength(Empty, 0);
      Reader := MatrixFormats.CreateReader(
        MakeTxtProps(DataDir + 'example.txt', 'tab'), Empty);
      Reader.Free;
    end,
    Exception);
end;

procedure TMaskedReaderTests.EmptyLabelSelection_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      Reader: TMatrixReader;
      Empty: TArray<string>;
    begin
      SetLength(Empty, 0);
      Reader := MatrixFormats.CreateReader(
        MakeTxtProps(DataDir + 'example.txt', 'tab'), Empty);
      Reader.Free;
    end,
    Exception);
end;

end.
