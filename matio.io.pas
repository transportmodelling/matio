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
  SysUtils,PropSet,matio,matio.formats;

Type
  TMatrixRowsReader = Class(TFloat64MatrixRows)
  private
    CurrentRow: Integer;
    Reader: TMatrixReader;
    Function GetFileLabel: String;
    Function GetMatrixLabels(Matrix: Integer): String;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const Count,Size: Integer); overload;
    Constructor Create(const [ref] Properties: TPropertySet;
                       const Selection: array of Integer;
                       const Size: Integer); overload;
    Constructor Create(const [ref] Properties: TPropertySet;
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
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer);
    Procedure Write;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRowsReader.Create(const [ref] Properties: TPropertySet;
                                     const Count,Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Properties);
  if Reader <> nil then
    Allocate(Count,Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Properties: TPropertySet;
                                     const Selection: array of Integer;
                                     const Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Properties,Selection);
  if Reader <> nil then
    Allocate(Length(Selection),Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Constructor TMatrixRowsReader.Create(const [ref] Properties: TPropertySet;
                                     const Selection: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Properties,Selection);
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

Constructor TMatrixRowsWriter.Create(const [ref] Properties: TPropertySet;
                                     const FileLabel: string;
                                     const MatrixLabels: array of String;
                                     const Size: Integer);
begin
  inherited Create;
  Writer := MatrixFormats.CreateWriter(Properties,FileLabel,MatrixLabels,Size);
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
