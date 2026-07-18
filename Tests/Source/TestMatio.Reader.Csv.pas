unit TestMatio.Reader.Csv;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the CSV (comma-delimited) matrix reader.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  TCsvReaderTests = class(TReaderTests)
  strict private
    FTxt: TFloat64Matrices;
    FCsv: TFloat64Matrices;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure CsvMatchesTxt_Count;
    [Test] procedure CsvMatchesTxt_Size;
    [Test] procedure CsvMatchesTxt_AllCells;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio.formats;

const
  TolExact = 1e-9;

procedure TCsvReaderTests.Setup;
begin
  FTxt := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
  FCsv := ReadAll(MakeTxtProps(DataDir + 'example.csv', 'comma'), 2, 485);
end;

procedure TCsvReaderTests.TearDown;
begin
  FTxt.Free;
  FCsv.Free;
end;

procedure TCsvReaderTests.CsvMatchesTxt_Count;
begin
  Assert.AreEqual(FTxt.Count, FCsv.Count);
end;

procedure TCsvReaderTests.CsvMatchesTxt_Size;
begin
  Assert.AreEqual(FTxt.Size, FCsv.Size);
end;

procedure TCsvReaderTests.CsvMatchesTxt_AllCells;
var
  Mismatch: string;
begin
  Mismatch := CompareMatrices(FTxt, FCsv, TolExact);
  Assert.IsEmpty(Mismatch, 'csv vs txt: ' + Mismatch);
end;

end.
