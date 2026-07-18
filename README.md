# Objective

The matio-library aims to facilitate the reading and writing of matrix files in transport models, in a way that makes it easy to switch between matrix formats. The abstract base classes `TMatrixReader`/`TMatrixWriter` are the ancestor classes for the format specific readers/writers. They are intended to read/write matrix files that may contain multiple matrices. The `TMatrixReader.Read`/`TMatrixWriter.Write` methods read/write a single row of each matrix in the matrix file. This makes it possible to apply a transport model zone by zone for the successive model zones, without having to store the complete matrices in memory.

# Library structure

The `Source` folder is organised in layers:

 - `matio` — core types and the abstract base classes for matrix rows and matrix filers
 - `matio.row` — in-memory matrix row storage (`TFloat32MatrixRows`/`TFloat64MatrixRows`) and callback-backed rows (`TGetterMatrixRows`/`TSetterMatrixRows`)
 - `matio.reader` / `matio.writer` — the abstract `TMatrixReader`/`TMatrixWriter` classes plus the enumeration and masking wrappers
 - `matio.reader.*` / `matio.writer.*` — the format specific reader and writer implementations
 - `matio.formats` and `matio.formats.*` — the format registry that creates readers and writers from a `TKeyValuePairs` configuration
 - `matio.io` — combined row storage and I/O (`TMatrixRowsReader`/`TMatrixRowsWriter`)
 - `matio.matrix` — complete in-memory matrices (`TFloat32Matrices`/`TFloat64Matrices`)

# Matrix ordering

Within the library, matrices are always accessed by index — their zero-based position in the reader. What a matrix file itself provides to establish that index differs per format:

- Some formats store their matrices in a well-defined order, but without names. The Minutp and Visum formats belong to this category: their matrices can only be accessed by index.
- Some formats identify their matrices by name only and do not define a matrix order. The HDF5-based OMX and Cube formats belong to this category: their matrices can only be accessed by label.
- Some formats store both an order and names. The text format (with header) and the 4G format belong to this category: their matrices can be accessed by index as well as by label.

Label access is turned into index access by passing a list of labels to `CreateReader`: the index of a matrix is the position of its label in the list. This works for every format that stores matrix names, and it is the only way to obtain indexed access to an unordered format. For ordered formats a list of indices can be passed instead. Either kind of list also selects a subset of the matrices in the file: only the listed matrices are read, in the order of the list.

Attempting index-based selection on an unordered format raises an exception. When all matrices of an unordered file are read without a selection, they are enumerated in alphabetical order — the same order other HDF5 tools display — and the caller must acknowledge the missing file order by passing false for the `Ordered` argument of `CreateReader` or `Read`. If no selection list is provided for an ordered format, all matrices are included in the order they appear in the file.

# Readers and Writers

The MatrixReader and MatrixWriter-objects are instantiated by providing a `TKeyValuePairs` configuration (from the [Utils](https://github.com/transportmodelling/Utils) repository) that specifies the [desired format and other (format specific) properties](https://github.com/transportmodelling/matio/wiki/File-specification). The configuration can be built up pair by pair:

```delphi
var Config: TKeyValuePairs;
Config.Append('file','matrix.dat');
Config.Append('format','txt');
Config.Append('delim','comma');
var Reader := MatrixFormats.CreateReader(Config);
```

will create a MatrixReader-object that reads matrices from a comma-separated text file named 'matrix.dat'. Alternatively, the configuration can be parsed from a key-value string:

```delphi
var Config := TKeyValuePairs.Create('file=los.omx; format=omx','=',';');
var Reader := MatrixFormats.CreateReader(Config,['IVT','WaitTime']);
```

will create a MatrixReader-object that reads the matrices with labels IVT and WaitTime from an open matrix file named 'los.omx'.

# Supported formats

The following formats are supported by the matio-library:

 - Text format (various encodings and separators)
 - The binary Minutp-format that can be used within Bentley OpenPaths CUBE
 - The binary PTV Visum format
 - [Open Matrix Format (omx)](https://github.com/osPlanning/omx) (requires HDF5 DLL)
 - The Cube matrix format used within Bentley OpenPaths CUBE (requires HDF5 DLL)
 - The binary 4G-format that is being used within the national transport models of Flanders and the Netherlands.

Support for other formats can be added by registering the format at the global MatrixFormats-object.

# Enumeration-based reading and writing

`TMatrixEnumReader` and `TMatrixEnumWriter` provide an alternative API for situations where the caller's data is not naturally organised as a collection of rows. Consider for example a two-dimensional array of matrix rows indexed by mode and time-of-day: the standard `Read`/`Write` methods require all matrix rows for a file row to be supplied at once, which is inconvenient when the matrices are spread across such a structure. The enum API instead accepts one matrix row per `Read`/`Write` call; a call to `NextRow` advances to the next file row.

Both can be created via `MatrixFormats.CreateEnumReader` and `MatrixFormats.CreateEnumWriter`.

`TMatrixEnumWriter` accepts a `FixedRows` flag. When `true`, the caller guarantees that the array passed to `Write` will not be modified before `NextRow` is called, allowing the writer to skip a defensive copy. When `false` (the default), the writer copies each row so the caller can safely reuse the buffer.

# Reading and writing through callbacks

Besides row arrays and rows objects, the readers and writers accept callbacks, so values can be produced or consumed on the fly without allocating a row buffer. Two callback types are defined:

```delphi
TMatrixGetter = TFunc<Integer,Integer,Float64>; // returns the value at (Matrix,Column)
TMatrixSetter = TProc<Integer,Integer,Float64>; // receives the value at (Matrix,Column)
TMatrixRowGetter = TFunc<Integer,Float64>;      // returns the value at (Column) for a single matrix row
```

The `Write` method accepts a `TMatrixGetter` — useful when writing derived matrices whose values can be computed directly, for example a distance matrix based on zone coordinates:

```delphi
Writer.Write(
  function(Matrix, Column: Integer): Float64
  begin
    Result := ...; // compute value for this matrix and column
  end);
```

The `Read` method accepts a `TMatrixSetter`, which is called for every cell of the current row:

```delphi
Reader.Read(
  procedure(Matrix, Column: Integer; Value: Float64)
  begin
    ...; // store or process the value for this matrix and column
  end);
```

For more complex cases, derive a class from `TVirtualMatrixRows` and override `GetValues`. The `TGetterMatrixRows` class in `matio.row` is a ready-made descendant that wraps a `TMatrixGetter` for situations where a `TVirtualMatrixRows` object must be passed explicitly.

# Combined row storage and I/O

`TMatrixRowsReader` and `TMatrixRowsWriter` (unit `matio.io`) are intended for single-threaded applications that process matrix files one row at a time. They combine in-memory row storage and file I/O in a single object, avoiding the need to manage a separate rows object alongside the reader or writer.

`TMatrixRowsReader` inherits from `TFloat64MatrixRows`. Each call to `Read` loads the next file row directly into the object; values can then be accessed via the inherited `Values[Matrix, Column]` indexer. Reading past the last row zeroes all values. Index- and label-based matrix selection are supported through constructor overloads.

`TMatrixRowsWriter` works in the opposite direction: values are written to the object via `Values[Matrix, Column]`, and a call to `Write` flushes the current row to the file.

# In-memory matrices

`TFloat64Matrices` and `TFloat32Matrices` (unit `matio.matrix`) hold a complete set of matrices in memory. They are suited for applications that need random access to any cell, or that process the same data more than once.

Both classes are created with `Create(Count, Size)` and expose a `Values[Matrix, Row, Column]` default property for cell access. Values are always read and written as `Float64`; `TFloat32Matrices` stores them internally at single precision, halving memory use at the cost of reduced accuracy.

Matrices can be loaded from a file with `Read` — supporting the same index- and label-based selection as `CreateReader` — and written back with `Save`. Both methods accept a `TKeyValuePairs` configuration in the same format as `CreateReader`/`CreateWriter`. The `Transpose` method transposes a single matrix or all matrices in place.

# Tests

The `Tests` folder contains a [DUnitX](https://github.com/VSoftTechnologies/DUnitX) test project covering the readers and writers for all supported formats, the enumeration API, the combined row storage and I/O classes, and the in-memory matrix classes.

The OMX and Cube format tests depend on the HDF5 DLL being present at runtime. If the DLL is not found, those tests are skipped gracefully and the remaining tests continue to run.

# Dependencies

Before you can compile this library, you will need to clone the https://github.com/transportmodelling/Utils repository, and then add it to your Delphi Library path.

The OMX and Cube formats require the HDF5 DLL (`hdf5.dll`) to be present at runtime. This DLL can be obtained from the [HDF Group](https://www.hdfgroup.org). If the DLL is not found, these formats report themselves as unavailable and the rest of the library continues to function normally.
