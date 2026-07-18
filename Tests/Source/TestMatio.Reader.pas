unit TestMatio.Reader;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/matio
//
// Shared base class and helpers for all reader test fixtures.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

uses
  KeyVal, matio.matrix;

type
  TReaderTests = class
  protected
    function DataDir: string;
    function MakeProps(const FileName, Format: string): TKeyValuePairs;
    function MakeTxtProps(const FileName, Delimiter: string): TKeyValuePairs;
    function ReadAll(const [ref] Props: TKeyValuePairs; Count, Size: Integer;
                     Ordered: Boolean = true): TFloat64Matrices;
    function CompareMatrices(A, B: TFloat64Matrices; Tol: Double): string;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

uses
  SysUtils, Math, matio, matio.formats;

function TReaderTests.DataDir: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Data\');
end;

function TReaderTests.MakeProps(const FileName, Format: string): TKeyValuePairs;
begin
  // Result may alias the caller's destination variable; clear before appending
  Result.Clear;
  Result.Append('file', FileName);
  Result.Append('format', Format);
end;

function TReaderTests.MakeTxtProps(const FileName, Delimiter: string): TKeyValuePairs;
begin
  Result := MakeProps(FileName, 'txt');
  Result.Append('delim', Delimiter);
end;

function TReaderTests.ReadAll(const [ref] Props: TKeyValuePairs; Count, Size: Integer;
                              Ordered: Boolean = true): TFloat64Matrices;
begin
  Result := TFloat64Matrices.Create(Count, Size);
  Result.Read(Props, Ordered);
end;

function TReaderTests.CompareMatrices(A, B: TFloat64Matrices; Tol: Double): string;
var
  m, r, c: Integer;
begin
  Result := '';
  if A.Count <> B.Count then
  begin
    Result := Format('Count mismatch: %d vs %d', [A.Count, B.Count]);
    Exit;
  end;
  if A.Size <> B.Size then
  begin
    Result := Format('Size mismatch: %d vs %d', [A.Size, B.Size]);
    Exit;
  end;
  for m := 0 to A.Count - 1 do
    for r := 0 to A.Size - 1 do
      for c := 0 to A.Size - 1 do
        if Abs(A[m, r, c] - B[m, r, c]) > Tol then
        begin
          Result := Format('Mismatch at matrix %d row %d col %d: %.6f vs %.6f',
                           [m, r, c, A[m, r, c], B[m, r, c]]);
          Exit;
        end;
end;

end.
