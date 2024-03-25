# Objective

The matio-library aims to facilitate the reading and writing of matrix files in transport models, in a way that allows to easily switch between matrix formats. The abstract base classes TMatrixReader/TMatrixWriter are the ancestor classes for the format specific readers/writers. They are intended to read/write matrix files that may contain multiple matrices. The TMatrixReader.Read/TMatrixWriter.Write methods read/write a single row of each matrix in the matrix file. This allows to apply a transport model zone by zone for the successive model zones, without having to store the complete matrices in memory.

# Instantiating Readers/Writers

Matrices are identified either by label, or by their index in the matrix file. Depending on the file format, label-based access (e.g. text format without header), or index-based access (e.g. the omx-format) may not be supported.

To read a selection of matrices, specified by their label, a list of labels for the matrices to be read must be supplied. Matrices can then be accessed by their list index.

The MatrixReader and MatrixWriter-objects can be instantiated by providing a [key-value string specifying the desired format and other (format specific) properties](https://github.com/transportmodelling/matio/wiki/File-specification), for example:

```
var Reader := MatrixFormats.CreateReader('file=matrix.dat; format=txt; delim=comma');
```

will create a MatrixReader-object that reads matrices from a comma-separated text file named 'matrix.dat'.

```
var Reader := MatrixFormats.CreateReader('file=los.omx; format=omx',['IVT','WaitTime']);
```

will create a MatrixReader-object that reads the matrices with labels IVT and WaitTime from an open matrix file named 'los.omx'.

# Supported formats

The following formats are supported by the matio-library:

 -	Text format (various encodings and separators)
 -	The binary Minutp-format that can be used within Citilab's CUBE
 -	The binary PTV Visum format
 -  [Open Matrix Format (omx)](https://github.com/osPlanning/omx)
 -	The binary 4G-format that is being used within the national transport models of Flanders and the Netherlands.

Support for other formats can be added by registering the format at the global MatrixFormats-object.

# Dependencies
Before you can compile this library, you will need to clone the https://github.com/transportmodelling/Utils repository, and then add it to your Delphi Library path.
