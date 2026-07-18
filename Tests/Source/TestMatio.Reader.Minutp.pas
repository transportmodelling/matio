unit TestMatio.Reader.Minutp;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the Minutp binary matrix reader.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  TMinutpReaderTests = class(TReaderTests)
  strict private
    FTxt: TFloat64Matrices;
    FBin: TFloat64Matrices;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure Bin_Count_Is2;
    [Test] procedure Bin_Size_Is485;
    [Test] procedure BinMatchesTxt_AllCells;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio.formats;

const
  TolMtp = 0.01;

procedure TMinutpReaderTests.Setup;
var
  Props: TKeyValuePairs;
begin
  FTxt := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
  Props := MakeProps(DataDir + 'example.bin', 'mtp');
  Props.Append('prec', '3');
  FBin := ReadAll(Props, 2, 485);
end;

procedure TMinutpReaderTests.TearDown;
begin
  FTxt.Free;
  FBin.Free;
end;

procedure TMinutpReaderTests.Bin_Count_Is2;
begin
  Assert.AreEqual(2, FBin.Count);
end;

procedure TMinutpReaderTests.Bin_Size_Is485;
begin
  Assert.AreEqual(485, FBin.Size);
end;

procedure TMinutpReaderTests.BinMatchesTxt_AllCells;
var
  Mismatch: string;
begin
  Mismatch := CompareMatrices(FTxt, FBin, TolMtp);
  Assert.IsEmpty(Mismatch, 'bin vs txt: ' + Mismatch);
end;

end.
