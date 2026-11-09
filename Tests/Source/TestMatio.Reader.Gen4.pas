unit TestMatio.Reader.Gen4;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the 4G binary matrix reader.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  T4GReaderTests = class(TReaderTests)
  strict private
    FTxt: TFloat64Matrices;
    F4G: TFloat64Matrices;
    Procedure CopyWithDamagedChecksum(const Source,Target: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test] procedure Gen4_Count_Is2;
    [Test] procedure Gen4_Size_Is485;
    [Test] procedure Gen4MatchesTxt_AllCells;
    [Test] procedure Gen4_SelectByIndex_FirstMatrix_CountIs1;
    [Test] procedure Gen4_SelectByIndex_FirstMatrix_LabelIsIVT;
    [Test] Procedure Gen4_DamagedChecksum_ReportsDamagedData;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, IOUtils, KeyVal, matio.reader, matio.formats;

const
  Tol4G = 0.1;

Procedure T4GReaderTests.CopyWithDamagedChecksum(const Source,Target: String);
// A GZip stream ends with the CRC32 over the uncompressed data and their length.
// Flipping a bit of the CRC32 leaves a stream that decodes in full and fails its check.
begin
  var Bytes := TFile.ReadAllBytes(Source);
  var Checksum := Length(Bytes)-8;
  Bytes[Checksum] := Bytes[Checksum] xor 1;
  TFile.WriteAllBytes(Target,Bytes);
end;

procedure T4GReaderTests.Setup;
begin
  FTxt := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
  F4G  := ReadAll(MakeProps(DataDir + 'example.4g', '4g'), 2, 485);
end;

procedure T4GReaderTests.TearDown;
begin
  FTxt.Free;
  F4G.Free;
end;

procedure T4GReaderTests.Gen4_Count_Is2;
begin
  Assert.AreEqual(2, F4G.Count);
end;

procedure T4GReaderTests.Gen4_Size_Is485;
begin
  Assert.AreEqual(485, F4G.Size);
end;

procedure T4GReaderTests.Gen4MatchesTxt_AllCells;
var
  Mismatch: string;
begin
  Mismatch := CompareMatrices(FTxt, F4G, Tol4G);
  Assert.IsEmpty(Mismatch, '4g vs txt: ' + Mismatch);
end;

procedure T4GReaderTests.Gen4_SelectByIndex_FirstMatrix_CountIs1;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeProps(DataDir + 'example.4g', '4g');
  Reader := MatrixFormats.CreateReader(Props, [0]);
  try
    Assert.AreEqual(1, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure T4GReaderTests.Gen4_SelectByIndex_FirstMatrix_LabelIsIVT;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeProps(DataDir + 'example.4g', '4g');
  Reader := MatrixFormats.CreateReader(Props, [0]);
  try
    Assert.AreEqual('IVT', Reader.MatrixLabels[0]);
  finally
    Reader.Free;
  end;
end;

Procedure T4GReaderTests.Gen4_DamagedChecksum_ReportsDamagedData;
begin
  var FileName := TPath.Combine(TPath.GetTempPath,'matio_test_damaged.4g');
  CopyWithDamagedChecksum(DataDir + 'example.4g',FileName);
  var Matrices := TFloat64Matrices.Create(2,485);
  try
    Assert.WillRaiseWithMessage(
      Procedure
      begin
        Matrices.Read(MakeProps(FileName,'4g'));
      end,
      Exception,'Error (damaged compressed data) reading row 485 in ' + FileName);
  finally
    Matrices.Free;
    TFile.Delete(FileName);
  end;
end;

end.
