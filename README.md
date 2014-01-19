# file-fun

Wrap functions to work with files


## Usage

**sync_async(f)**

Take a syncronous function and generate an asynchronous function, which receives a callback as the last argument

    result = f(input)
    g = sync_async(f)
    g(input, function(err, result) { })


### one-to-one functions

Generate functions which work with files from an asynchronous function which receives and returns (through a callback) a single value
  
**stringToString_fileToFile(f, oldInputIndex = 0, newOutputFilePathIndex = 1)**

    f(input, function(err, result) { })
    g = stringToString_fileToFile(f)
    g(inputFilePath, outputFilePath, function(err, outputFilePath) { })


**fileToFile_globsToDir(f, extension, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1)**
**fileToFile_globsToDirWithWatch(f, extension, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1)**

`globsToDirWithWatch` works in the same way as `globsToDir`, but it then watches the patterns to (1) rerun the function on files which were added or have changed and (2) delete files when the original file is deleted

    f(inputFilePath, outputFilePath, function(err, outputFilePath) { })
    g = fileToFile_globsToDir(f)
    g( [patterns] , globOptions, outputDir, function(err, outputFilePaths) { })

  
**stringToString_globsToDir(f, extension, inputIndex = 0)**
**stringToString_globsToDirWithWatch(f, extension, inputIndex = 0)**

    f(input, function(err, result) { })
    g = stringToString_globsToDir(f)
    g( [patterns] , globOptions, outputDir, function(err, outputFilePaths) { })


**sync_fileToFile(f, inputIndex = 0)**


**sync_globsToDir(f, inputIndex = 0)**


**sync_globsToDirWithWatch(f, inputIndex = 0)**


### transform streams

Generate functions from a transform stream

**transformStream_stringToString(transformStreamConstructor)**

    g = transformStream_stringToString(transformStreamConstructor)
    g(input, function(err, result) { })


**transformStream_fileToFile(transformStreamConstructor)**

    g = transformStream_fileToFile(transformStreamConstructor)
    g(inputFilePath, outputFilePath, function(err, outputFilePath) { })


**transformStream_globsToDir(transformStreamConstructor)**

    g = transformStream_globsToDir(transformStreamConstructor)
    g( [patterns] , globOptions, outputDir, function(err, outputFilePaths) { })


### many-to-one functions

Generate functions which work with files from an asynchronous function which receives a list of values and and returns (through a callback) a single value

**stringsToString_filesToFile(f, oldInputIndex = 0, newOutputFilePathIndex = 1)**

    f( [input] , function(err, result) { })
    g = stringsToString_filesToFile(f)
    g( [inputFilePaths] , outputFilePath, function(err, outputFilePath) { })
  
  
**filesToFile_globsToFile(f, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1)**

    f( [inputFilePaths] , outputFilePath, function(err, outputFilePath) { })
    g = filesToFile_globsToFile(f)
    g( [patterns], globOptions, outputFilePath, function(err, outputFilePath){ })
  

**stringsToString_globsToFile(f, inputIndex = 0)**
  
    f( [input] , function(err, result) { })
    g = stringsToString_globsToFile(f)
    g( [patterns], globOptions, outputFilePath, function(err, outputFilePath){ })


**sync_filesToFile(f, inputIndex = 0)**


**sync_globsToFile(f, inputIndex = 0)**