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
    Reader: TMatrixReader;
  public
    Constructor Create(const [ref] Properties: TPropertySet; Count,Size: Integer);
    Procedure Read;
    Destructor Destroy; override;
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

Constructor TMatrixRowsReader.Create(const [ref] Properties: TPropertySet; Count,Size: Integer);
begin
  inherited Create;
  Reader := MatrixFormats.CreateReader(Properties);
  if Reader <> nil then
    Allocate(Count,Size)
  else
    raise Exception.Create('Error opening matrix file');
end;

Procedure TMatrixRowsReader.Read;
begin
  Reader.Read(Self);
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
