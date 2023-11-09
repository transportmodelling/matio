unit matio.formats.gen4;

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
  SysUtils, Types, Propset, ArrayBld, matio, matio.formats, matio.gen4;

Type
  T4GMatrixReaderFormat = Class(TMatrixReaderFormat)
  public
    Class Function Format: String; override;
    Class Function HasFormat(const Header: TBytes): Boolean; override;
  public
    Function CreateReader(const [ref] Properties: TPropertySet): TMatrixReader; override;
  end;

  T4GMatrixWriterFormat = Class(TMatrixWriterFormat)
  private
    Const
      PrecisionProperty = 'prec';
      CompressionProperty = 'compress';
      CompressionOptions: array[T4GCompression] of String = ('none','gzip');
  strict protected
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function PropertyPickList(const PropertyName: string; out PickList: TStringDynArray): Boolean; override;
  public
    Function CreateWriter(const [ref] Properties: TPropertySet;
                          const FileLabel: string;
                          const MatrixLabels: array of String;
                          const Size: Integer): TMatrixWriter; overload; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function T4GMatrixReaderFormat.Format: String;
begin
  Result := '4g';
end;

Class Function T4GMatrixReaderFormat.HasFormat(const Header: TBytes): Boolean;
begin
  if Length(Header) >= 4 then
    if TEncoding.ASCII.GetString(Copy(Header,0,2)) = '4G' then
      if (Header[2] = 20) and (Header[3] = 1) then
        Result := true
      else
        Result := false
    else
      Result := false
  else
    Result := false;
end;

Function T4GMatrixReaderFormat.CreateReader(const [ref] Properties: TPropertySet): TMatrixReader;
begin
  if SameText(Properties[FormatProperty],Format) then
    Result := T4GMatrixReader.Create(Properties.ToPath(FileProperty))
  else
    raise Exception.Create('Invalid format-property');
end;

////////////////////////////////////////////////////////////////////////////////

Class Function T4GMatrixWriterFormat.Format: String;
begin
  Result := '4g';
end;

Class Procedure T4GMatrixWriterFormat.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,PrecisionLabels[ftFloat32]);
  Properties.Append(CompressionProperty,CompressionOptions[cpGZip]);
end;

Class Function T4GMatrixWriterFormat.PropertyPickList(const PropertyName: string;
                                                      out PickList: TStringDynArray): Boolean;
begin
  if not inherited PropertyPickList(PropertyName,PickList) then
  if SameText(PropertyName,PrecisionProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(PrecisionLabels);
  end else
  if SameText(PropertyName,CompressionProperty) then
  begin
    Result := true;
    PickList := TStringArrayBuilder.Create(CompressionOptions);
  end else
    Result := false;
end;

Function T4GMatrixWriterFormat.CreateWriter(const [ref] Properties: TPropertySet;
                                            const FileLabel: string;
                                            const MatrixLabels: array of String;
                                            const Size: Integer): TMatrixWriter;
Var
  Precision: TFloatType;
  Compression: T4GCompression;
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    // Set precision
    var ValidPrecision := false;
    var PrecisionPropertyValue := ExtendedProperties[PrecisionProperty];
    for var Prec := low(PrecisionLabels) to high(PrecisionLabels) do
    if SameText(PrecisionLabels[Prec],PrecisionPropertyValue) then
    begin
      Precision := Prec;
      ValidPrecision := true;
      Break;
    end;
    if not ValidPrecision then raise Exception.Create('Invalid precision');
    // Set compression
    var ValidCompression := false;
    var CompressionProprtyValue := ExtendedProperties[CompressionProperty];
    for var Compress := low(CompressionOptions) to high(CompressionOptions) do
    if SameText(CompressionOptions[Compress],CompressionProprtyValue) then
    begin
      Compression := Compress;
      ValidCompression := true;
      Break;
    end;
    if not ValidCompression then raise Exception.Create('Invalid compression');
    // Create writer
    Result := T4GMatrixWriter.Create(ExtendedProperties.ToPath(FileProperty),FileLabel,MatrixLabels,Size,Precision,Compression);
  end else
    raise Exception.Create('Invalid format-property');
end;

end.
