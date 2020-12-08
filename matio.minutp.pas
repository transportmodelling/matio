unit matio.minutp;

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
   System.Classes,System.SysUtils,propSet,matio;

Type
  TMinutpMatrixReader = Class(TMatrixReader)
  private
    Type
      TMatrixRecordHeader = record
        Row,LastColumn: UInt16;
        Matrix: Byte;
      end;
    Const
      PrecisionProperty = 'prec';
    Var
      EOF: Boolean;
      Next: TMatrixRecordHeader;
      ScalingFactor: Real;
  strict protected
    Procedure Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows); override;
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
    Class Function HasFormat(const Header: TBytes): Boolean; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet); overload; override;
    Constructor Create(Const FileName: TFileName; Const Precision: Byte = 0); overload;
  end;

  TMinutpMatrixWriter = Class(TMatrixWriter)
  private
    Const
      Max13Bit = 256*32-1;
      PrecisionProperty = 'prec';
    Var
      ScalingFactor: Real;
      IntValues: array of Integer;
    Function GetValueSize(Item: Int32): Byte;
    Procedure WriteToFile(Value,NBytes: Integer);
    Procedure Write(const CurrentMatrix,CurrentRow,LastColumn: Integer; const Row: array of Integer); overload;
  strict protected
    Procedure Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows); overload; override;
    Class Procedure AppendFormatProperties(const [ref] Properties: TPropertySet); override;
  public
    Class Function Format: String; override;
  public
    Constructor Create(const [ref] Properties: TPropertySet;
                       const FileLabel: string;
                       const MatrixLabels: array of String;
                       const Size: Integer); overload; override;
    Constructor Create(Const FileName,FileLabel: String;
                       Const Count,Size: Integer;
                       Const Precision: Byte = 0); overload;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Class Function TMinutpMatrixReader.Format: String;
begin
  Result := 'mtp';
end;

Class Function TMinutpMatrixReader.HasFormat(const Header: TBytes): Boolean;
begin
  if Length(Header) >= 74 then
  begin
    if TEncoding.ASCII.GetString(Copy(Header,66,7)) = ' MATRIX' then
      if Header[73] = 45 then
        Result := true
      else
        Result := false
    else
      Result := false;
  end else
    Result := false;
end;

Class Procedure TMinutpMatrixReader.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,'0');
end;

Constructor TMinutpMatrixReader.Create(const [ref] Properties: TPropertySet);
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    Create(ExtendedProperties.ToPath(FileProperty),ExtendedProperties.ToInt(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

Constructor TMinutpMatrixReader.Create(Const FileName: TFileName; Const Precision: Byte = 0);
begin
  inherited Create(FileName);
  // Set ScalingFactor
  ScalingFactor := 1;
  for var Cnt := 1 to Precision do ScalingFactor := ScalingFactor/10;
  // Read file header
  var Reader := TBinaryReader.Create(FileStream,TEncoding.ASCII);
  try
    SetSize(Reader.ReadUInt16);
    SetCount(Reader.ReadUInt16);
    if Reader.ReadUInt16 <> Size then raise Exception.Create('square matrices expected');
    var ID := '';
    for var Cnt := 1 to 60 do ID := ID + Reader.ReadChar;
    SetFileLabel(ID);
    for var Cnt := 1 to 7 do Reader.ReadChar;
    Reader.ReadByte;
  finally
    Reader.Free;
  end;
  // Read first header record
  EOF := (FileStream.read(Next.Row,2) = 0);
  if not EOF then
  begin
    FileStream.read(Next.Matrix,1);
    FileStream.read(Next.LastColumn,2);
  end;
end;

Procedure TMinutpMatrixReader.Read(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  ValueSize: Byte;
  Column: Integer;
  Key,NValues: Word;
  NextValue,RepliData: LongInt;
begin
  var LastMatrix := -1;
  // Read records
  while (not EOF) and (Next.Row = CurrentRow+1) do
  begin
    // Zeroize missing matrices
    for var Matrix := LastMatrix+1 to Next.Matrix-2 do
    for Column := 0 to Size-1 do
    Rows[Matrix,Column] := 0.0;
    // Read record
    Column := 0;
    LastMatrix := Next.Matrix-1;
    while Column < Next.LastColumn do
    begin
      if FileStream.Read(Key,2) <> 2 then
        raise Exception.Create('Error reading Minutp-file');
      ValueSize:= (Key shr 13);  // bit 1-3
      Nvalues:= (Key and 8191);  // bit 4-16
      case ValueSize of
          0: // Fill with Nvalues zeros
             for var Cnt := 1 to Nvalues do
             begin
               Rows[Next.Matrix-1,Column] := 0.0;
               Inc(Column);
             end;
       1..4: // Read Nvalues vars with size 1..4
             for var Cnt := 1 to Nvalues do
             begin
               NextValue := 0;
               if FileStream.Read(NextValue,ValueSize) <> ValueSize then
                 raise Exception.Create('Error reading Minutp-file');
               Rows[Next.Matrix-1,Column] := ScalingFactor*NextValue;
               Inc(Column);
             end;
          7: // Read Next byte=size; Read var with this Size; fill with Nvalues vars
             begin
               if FileStream.read(ValueSize,1) <> 1 then
                 raise Exception.Create('Error reading Minutp-file');
               RepliData:=0;
               if FileStream.Read(RepliData,ValueSize) <> ValueSize then
                 raise Exception.Create('Error reading Minutp-file');
               for var Cnt := 1 to Nvalues do
               begin
                 Rows[Next.Matrix-1,Column] := ScalingFactor*RepliData;
                 Inc(Column);
               end;
             end;
        else raise exception.create('Error reading Minutp-file!');
      end;
    end;
    // Zeroize missing columns
    if Next.LastColumn-1 < Size-1 then
    for Column := Next.LastColumn to Size-1 do
    Rows[Next.Matrix-1,Column] := 0.0;
    // Read next header record
    EOF := (FileStream.read(Next.Row,2) = 0);
    if not EOF then
    begin
      if (FileStream.read(Next.Matrix,1) <> 1)
      or  (FileStream.read(Next.LastColumn,2) <> 2) then
        raise Exception.Create('Error reading Minutp-file');
      if (Next.Row <= CurrentRow)
      or ((Next.Row = CurrentRow+1) and (Next.Matrix-1 <= LastMatrix)) then
        raise Exception.Create('Error while reading mtp-file!');
    end;
  end;
  // Zeroize missing matrices
  if LastMatrix < Count-1 then
  for var Matrix := LastMatrix+1 to Count-1 do
  for Column := 0 to Size-1 do
  Rows[Matrix,Column] := 0.0;
end;

////////////////////////////////////////////////////////////////////////////////

Class Function TMinutpMatrixWriter.Format: String;
begin
  Result := 'mtp';
end;

Class Procedure TMinutpMatrixWriter.AppendFormatProperties(const [ref] Properties: TPropertySet);
begin
  Properties.Append(PrecisionProperty,'');
end;

Constructor TMinutpMatrixWriter.Create(const [ref] Properties: TPropertySet;
                                       const FileLabel: string;
                                       const MatrixLabels: array of String;
                                       const Size: Integer);
begin
  if SameText(Properties[FormatProperty],Format) then
  begin
    var ExtendedProperties := ExtendProperties(Properties);
    Create(ExtendedProperties.ToPath(FileProperty),FileLabel,Length(MatrixLabels),
           Size,ExtendedProperties.ToInt(PrecisionProperty));
  end else
    raise Exception.Create('Invalid format-property');
end;

Constructor TMinutpMatrixWriter.Create(Const FileName,FileLabel: String;
                                       Const Count,Size: Integer;
                                       const Precision: Byte = 0);
begin
  inherited Create(FileName,Count,Size);
  // Set ScalingFactor
  ScalingFactor := 1;
  for var Cnt := 1 to Precision do ScalingFactor := ScalingFactor*10;
  // write file header
  var FormatIndicator := 45;
  var Writer := TBinaryWriter.Create(FileStream,TEncoding.ASCII);
  try
    FileStream.Write(Size,2);
    FileStream.Write(Count,2);
    FileStream.Write(Size,2);
    if Length(FileLabel) < 60 then
    begin
      Writer.Write(FileLabel.ToCharArray);
      for var Space := Length(FileLabel)+1 to 60 do Writer.Write(' ');
    end else Writer.Write(Copy(FileLabel,1,60).ToCharArray);
    Writer.Write(' MATRIX'.ToCharArray);
    FileStream.write(FormatIndicator,1);
  finally
    Writer.Free;
  end;
  // Allocate IntValues
  SetLength(IntValues,Size);
end;

Function TMinutpMatrixWriter.GetValueSize(Item: Int32): Byte;
Const
  MaxByte=256-1;
  MaxWord=256*256-1;
  Max3Byte=256*256*256-1;
begin
  if Item < 0 then Result := 4 else
  if Item<=MaxByte then Result:=1 else
  if Item<=MaxWord then Result:=2 else
  if Item<=Max3Byte then Result:=3 else
  Result:=4;
end;

Procedure TMinutpMatrixWriter.WriteToFile(Value,NBytes: Integer);
begin
  FileStream.Write(Value,NBytes)
end;

Procedure TMinutpMatrixWriter.Write(const CurrentMatrix,CurrentRow,LastColumn: Integer; const Row: array of Integer);
Const
  RepliKey: Word = 7 shl 13;
Var
  Key: Word;
begin
  // Write matrix record header
  WriteToFile(CurrentRow+1,2);
  WriteToFile(CurrentMatrix+1,1);
  WriteToFile(LastColumn+1,2);
  // Write cells
  var Last := -1;
  while Last < LastColumn do
  begin
    // Determine range with same value size
    Inc(Last);
    var Column := Last;
    var ValueSize := GetValueSize(IntValues[Last]);
    var BeneficialRepliRange := 5 div ValueSize; // Beneficial if 5+ValueSize < (Last-Column+1)*ValueSize
    var Repli := true;
    var RepliCount := 0;
    while (Last < LastColumn) and (Last-Column < Max13Bit) and  // valid range
          (GetValueSize(IntValues[Last+1]) = ValueSize) and // same value size
          ((not Repli) or (IntValues[Column] = IntValues[Last+1]) or ((Last-Column) < BeneficialRepliRange)) and // not breaking long repli sequence
          (Repli or (RepliCount < BeneficialRepliRange)) do // not preventing long repli sequence
    begin
      Inc(Last);
      if IntValues[Last] = IntValues[Last-1] then Inc(RepliCount) else RepliCount := 0;
      Repli := Repli and (IntValues[Column] = IntValues[Last]);
    end;
    if (not Repli) and (RepliCount >= BeneficialRepliRange) then Last := Last-RepliCount-1;
    // write range to file
    if Repli and (Last > Column) then
    begin
      if IntValues[Column] = 0 then
      begin
        Key:=Last-Column+1;
        WriteToFile(Key,2);
      end else
      begin
        Key:= RepliKey + Last-Column+1;
        WriteToFile(Key,2);
        WriteToFile(ValueSize,1);
        WriteToFile(IntValues[Column],ValueSize);
      end
    end else
    begin
      Key:=(ValueSize shl 13) + Last-Column+1;
      WriteToFile(Key,2);
      while Column <= Last do
      begin
        WriteToFile(IntValues[Column],ValueSize);
        Inc(Column);
      end;
    end;
  end;
end;

Procedure TMinutpMatrixWriter.Write(const CurrentRow: Integer; const Rows: TCustomMatrixRows);
Var
  IntValue: Int32;
begin
  for var Matrix := 0 to Count-1 do
  begin
    // Set integer values
    for var Column := 0 to Size-1 do
    begin
      var ScaledValue := ScalingFactor*Rows[Matrix,Column];
      if ScaledValue < 0 then
        if ScaledValue >= -MaxInt-1 then IntValue := Round(ScaledValue) else IntValue := -MaxInt-1
      else
        if ScaledValue <= MaxInt then IntValue := Round(ScaledValue) else IntValue := MaxInt;
      IntValues[Column] := IntValue;
    end;
    Write(Matrix,CurrentRow,Size-1,IntValues);
  end;
end;

end.
