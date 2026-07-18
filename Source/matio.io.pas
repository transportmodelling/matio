unit matio.io;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/matio
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, KeyVal, matio, matio.row, matio.reader, matio.writer, matio.formats;

Type
  TMatrixRowsReader = Class(TFloat64MatrixRows)
  // Combines row and reader functionality in a single class.
  // Suitable for applications that process all rows on the same thread.
  private
    CurrentRow: Integer;
    Reader: TMatrixReader;
    Function GetFileLabel: String;
    Function GetMatrixLabels(Matrix: Integer): String;
  public
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Count,Size: Integer); overload;
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Selection: array of Integer;
                       const Size: Integer); overload;
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const Selection: array of String;
                       const Size: Integer); overload;
    Procedure Read;
    Destructor Destroy; override;
  public
    Property FileLabel: String read GetFileLabel;
    Property MatrixLabels[Matrix: Integer]: String read GetMatrixLabels;
  end;

  TMatrixRowsWriter = Class(TFloat64MatrixRows)
  private
    Writer: TMatrixWriter;
  public
    Constructor Create(const [ref] Config: TKeyValuePairs;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer);
    Procedure Write;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Count,Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Config);
  if Reader <> nil then
    Allocate(Count,Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of Integer;
                                     const Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Config,Selection);
  if Reader <> nil then
    Allocate(Length(Selection),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Config: TKeyValuePairs;
                                     const Selection: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Config,Selection);
  if Reader <> nil then
    Allocate(Length(Selection),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Function TMatrixRowsReader.GetFileLabel: String;
begin
  Result := Reader.FileLabel;
end;

Function TMatrixRowsReader.GetMatrixLabels(Matrix: Integer): String;
begin
  Result := Reader.MatrixLabels[Matrix];
end;

Procedure TMatrixRowsReader.Read;
begin
  if CurrentRow < Reader.Size then Reader.Read(Self) else Initialize;
  Inc(CurrentRow);
end;

Destructor TMatrixRowsReader.Destroy;
begin
  Reader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRowsWriter.Create(const [ref] Config: TKeyValuePairs;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  Writer := MatrixFormats.CreateWriter(Config,FileLabel,MatrixLabels,Size);
  if Writer <> nil then
    Allocate(Length(MatrixLabels),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Procedure TMatrixRowsWriter.Write;
begin
  Writer.Write(Self);
end;

Destructor TMatrixRowsWriter.Destroy;
begin
  Writer.Free;
  inherited Destroy;
end;

end.
