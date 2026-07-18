unit TestMatio.Reader.Text;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Tests for the text (tab-delimited) matrix reader.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  DUnitX.TestFramework, matio.matrix, TestMatio.Reader;

type
  [TestFixture]
  TTextReaderTests = class(TReaderTests)
  strict private
    FMatrices: TFloat64Matrices;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Metadata
    [Test] procedure Count_Is2;
    [Test] procedure Size_Is485;
    [Test] procedure MatrixLabel0_IVT;
    [Test] procedure MatrixLabel1_TRANSFERS;
    // Specific cells (row and column are 0-based; file uses 1-based zone numbers)
    // Row 1, Col 2: IVT=4.65, TRANSFERS=0
    [Test] procedure Row0Col1_IVT_Is4_65;
    [Test] procedure Row0Col1_Transfers_IsZero;
    // Row 1, Col 3: IVT=10.263
    [Test] procedure Row0Col2_IVT_Is10_263;
    // Diagonal (row==col) must be zero (absent from sparse file)
    [Test] procedure Diagonal_IsZero;
    // Zone 380 (index 379): value is 999999 in both matrices
    [Test] procedure Row0Col379_IVT_Is999999;
    // Sub-selection
    [Test] procedure SelectByIndex_SecondMatrix_CountIs1;
    [Test] procedure SelectByIndex_SecondMatrix_LabelIsTransfers;
    [Test] procedure SelectByIndex_SecondMatrix_ValueCorrect;
    [Test] procedure SelectByLabel_IVT_CountIs1;
    [Test] procedure SelectByLabel_IVT_LabelIsIVT;
    [Test] procedure SelectByLabel_IVT_ValueCorrect;
    // Setter-based reading
    [Test] procedure ReadBySetter_ValuesCorrect;
    [Test] procedure ReadBySetter_WithLabelSelection_ValuesCorrect;
    // Out-of-bounds forgiveness: excess cells in larger caller arrays are zeroed
    [Test] procedure ReadIntoLargerArrays_ExcessZeroed;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, KeyVal, matio, matio.reader, matio.formats;

const
  TolExact = 1e-9;

procedure TTextReaderTests.Setup;
begin
  FMatrices := ReadAll(MakeTxtProps(DataDir + 'example.txt', 'tab'), 2, 485);
end;

procedure TTextReaderTests.TearDown;
begin
  FMatrices.Free;
end;

procedure TTextReaderTests.Count_Is2;
begin
  Assert.AreEqual(2, FMatrices.Count);
end;

procedure TTextReaderTests.Size_Is485;
begin
  Assert.AreEqual(485, FMatrices.Size);
end;

procedure TTextReaderTests.MatrixLabel0_IVT;
begin
  Assert.AreEqual('IVT', FMatrices.MatrixLabels[0]);
end;

procedure TTextReaderTests.MatrixLabel1_TRANSFERS;
begin
  Assert.AreEqual('TRANSFERS', FMatrices.MatrixLabels[1]);
end;

procedure TTextReaderTests.Row0Col1_IVT_Is4_65;
begin
  Assert.AreEqual(4.65, FMatrices[0, 0, 1], TolExact);
end;

procedure TTextReaderTests.Row0Col1_Transfers_IsZero;
begin
  Assert.AreEqual(0.0, FMatrices[1, 0, 1], TolExact);
end;

procedure TTextReaderTests.Row0Col2_IVT_Is10_263;
begin
  Assert.AreEqual(10.263, FMatrices[0, 0, 2], TolExact);
end;

procedure TTextReaderTests.Diagonal_IsZero;
begin
  Assert.AreEqual(0.0, FMatrices[0, 0, 0], TolExact);
end;

procedure TTextReaderTests.Row0Col379_IVT_Is999999;
begin
  Assert.AreEqual(999999.0, FMatrices[0, 0, 379], TolExact);
end;

procedure TTextReaderTests.SelectByIndex_SecondMatrix_CountIs1;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props, [1]);
  try
    Assert.AreEqual(1, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TTextReaderTests.SelectByIndex_SecondMatrix_LabelIsTransfers;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props, [1]);
  try
    Assert.AreEqual('TRANSFERS', Reader.MatrixLabels[0]);
  finally
    Reader.Free;
  end;
end;

procedure TTextReaderTests.SelectByIndex_SecondMatrix_ValueCorrect;
var
  Props: TKeyValuePairs;
  Selected: TFloat64Matrices;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Selected := TFloat64Matrices.Create(1, 485);
  try
    Selected.Read(Props, [1]);
    // Row 1, Col 3: TRANSFERS = 0.025
    Assert.AreEqual(0.025, Selected[0, 0, 2], TolExact);
  finally
    Selected.Free;
  end;
end;

procedure TTextReaderTests.SelectByLabel_IVT_CountIs1;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props, ['IVT']);
  try
    Assert.AreEqual(1, Reader.Count);
  finally
    Reader.Free;
  end;
end;

procedure TTextReaderTests.SelectByLabel_IVT_LabelIsIVT;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props, ['IVT']);
  try
    Assert.AreEqual('IVT', Reader.MatrixLabels[0]);
  finally
    Reader.Free;
  end;
end;

procedure TTextReaderTests.SelectByLabel_IVT_ValueCorrect;
var
  Props: TKeyValuePairs;
  Selected: TFloat64Matrices;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Selected := TFloat64Matrices.Create(1, 485);
  try
    Selected.Read(Props, ['IVT']);
    Assert.AreEqual(4.65, Selected[0, 0, 1], TolExact);
  finally
    Selected.Free;
  end;
end;

procedure TTextReaderTests.ReadBySetter_ValuesCorrect;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
  Values: TFloat64Matrices;
  Row: Integer;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props);
  Values := TFloat64Matrices.Create(2, 485);
  try
    for Row := 0 to 484 do
    begin
      var CurrentRow := Row;
      Reader.Read(procedure(Matrix, Column: Integer; Value: Float64)
                  begin
                    Values[Matrix, CurrentRow, Column] := Value
                  end);
    end;
    // Cross-check against the reference values read via the object API in Setup
    Assert.AreEqual(4.65,   Values[0, 0, 1], TolExact);
    Assert.AreEqual(10.263, Values[0, 0, 2], TolExact);
    Assert.AreEqual(0.025,  Values[1, 0, 2], TolExact);
  finally
    Values.Free;
    Reader.Free;
  end;
end;

procedure TTextReaderTests.ReadBySetter_WithLabelSelection_ValuesCorrect;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
  Values: TFloat64Matrices;
  Row: Integer;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props, ['TRANSFERS']);
  Values := TFloat64Matrices.Create(1, 485);
  try
    Assert.AreEqual(1, Reader.Count);
    for Row := 0 to 484 do
    begin
      var CurrentRow := Row;
      Reader.Read(procedure(Matrix, Column: Integer; Value: Float64)
                  begin
                    Values[Matrix, CurrentRow, Column] := Value
                  end);
    end;
    Assert.AreEqual(0.025, Values[0, 0, 2], TolExact);
  finally
    Values.Free;
    Reader.Free;
  end;
end;

procedure TTextReaderTests.ReadIntoLargerArrays_ExcessZeroed;
var
  Props: TKeyValuePairs;
  Reader: TMatrixReader;
  Rows: array[0..2] of TFloat64MatrixRow; // 3 matrices, file has 2
  Matrix, Column: Integer;
begin
  Props := MakeTxtProps(DataDir + 'example.txt', 'tab');
  Reader := MatrixFormats.CreateReader(Props);
  try
    // Prefill with a sentinel value so zeroing is observable
    for Matrix := 0 to 2 do
    begin
      SetLength(Rows[Matrix], 495); // 10 columns beyond the file size
      for Column := 0 to 494 do Rows[Matrix][Column] := 99.0;
    end;
    Reader.Read(Rows); // first row
    // Values within file bounds are read
    Assert.AreEqual(4.65, Rows[0][1], TolExact);
    // Columns beyond the file size must be zeroed
    Assert.AreEqual(0.0, Rows[0][490], TolExact);
    // Matrices beyond the file count must be zeroed
    Assert.AreEqual(0.0, Rows[2][0], TolExact);
    Assert.AreEqual(0.0, Rows[2][490], TolExact);
  finally
    Reader.Free;
  end;
end;

end.
