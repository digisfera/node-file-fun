_ = require('lodash')
async = require('async')
fs = require('fs')
path = require('path')
glob = require('glob')
watchGlob = require('watch-glob')
mkdirp = require('mkdirp')
concatStream = require('concat-stream')

exports.sync_async = (f) -> () ->
  args = Array.prototype.slice.call(arguments)
  callback = if _.isFunction(_.last(args)) then _.last(args) else (->)

  async.nextTick ->
    try
      result = f.apply(null, args)
      callback(null, result)
    catch e
      callback(e)


stringFun_fileFun = (receivesMultipleInputs, f, oldInputIndex = 0, newOutputFilePathIndex = 1) -> () ->
  args = Array.prototype.slice.call(arguments)  
  inputIndex = if newOutputFilePathIndex <= oldInputIndex then oldInputIndex + 1 else oldInputIndex
  callbackIndex = Math.max(args.length - 1, 2)

  callback = if _.isFunction(args[callbackIndex]) then args[callbackIndex] else (->)
  inFiles = if receivesMultipleInputs then args[inputIndex] else [ args[inputIndex] ]
  outFile = args[newOutputFilePathIndex]

  args[callbackIndex] = (err, result) ->
    if err then return callback(err)
    mkdirp path.dirname(outFile), (err, createdDir) ->
      if err then return callback(err)
      fs.writeFile outFile, result, null, (err) ->
        if err then return callback(err)
        callback(null, outFile)

  async.map inFiles, ((f, cb) -> fs.readFile(f, { encoding: 'utf-8' }, cb)), (err, fileContents) ->
    if err? then return callback(err)
    #If the function does not receive multiple inputs, we should only have one result
    args[inputIndex] = if receivesMultipleInputs then fileContents else fileContents[0]
    #Remove outFile from args to original function
    args.splice(newOutputFilePathIndex, 1)
    f.apply(null, args)


exports.stringToString_fileToFile = (f, oldInputIndex = 0, newOutputFilePathIndex = 1) ->
  stringFun_fileFun(false, f, oldInputIndex, newOutputFilePathIndex)

exports.stringsToString_filesToFile = (f, oldInputIndex = 0, newOutputFilePathIndex = 1) ->
  stringFun_fileFun(true, f, oldInputIndex, newOutputFilePathIndex)


fileToFile_globsToDirWithOptionalWatch = (f, extension, withWatch = false, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1) -> () ->
  args = Array.prototype.slice.call(arguments)
  inputIndex = if newGlobOptionsIndex <= oldInputIndex then oldInputIndex + 1 else oldInputIndex
  outputIndex = if newGlobOptionsIndex <= oldOutputIndex then oldOutputIndex + 1 else oldOutputIndex
  callbackIndex = Math.max(args.length - (if withWatch then 3 else 1), 3)
  callback = if _.isFunction(args[callbackIndex]) then args[callbackIndex] else (->)

  patterns = if _.isArray(args[inputIndex]) then args[inputIndex] else [ args[inputIndex] ]
  globOptions = args[newGlobOptionsIndex]
  outputDir = args[outputIndex]

  outputFilePath = (p) ->
    outPath = 
      if path.normalize(path.resolve(p)) == path.normalize(p)
      #This is an absolute path, just use the basename
        path.join(outputDir, path.basename(p))
      else
        path.join(outputDir, p)

    if extension?.length > 0 then "#{outPath}.#{extension}"
    else outPath


  async.map patterns, ((pattern, cb) -> glob(pattern, globOptions, cb)), (err, matches) ->
    allMatches = _(matches).flatten().uniq().value()
    inFilesAbsolute = _.map(allMatches, (p) -> path.resolve(globOptions?.cwd || '', p))

    outFiles = _.map(allMatches, outputFilePath)

    processFilePair = (filePair, cb) ->
      callArgs = _.clone(args)
      callArgs[inputIndex] = filePair[0]
      callArgs[outputIndex] = filePair[1]
      callArgs[callbackIndex] = cb

      #Remove any extra arguments after the callback (they may exist for withWatch)
      callArgs = callArgs.slice(0, callbackIndex + 1)
      #Remove outFile from args to original function
      callArgs.splice(newGlobOptionsIndex, 1)

      f.apply(null, callArgs)

    async.map _.zip(inFilesAbsolute, outFiles), processFilePair, (err, success) ->
      
      if !withWatch then callback(err, success)
      else
        updateCallbackIndex = Math.max(args.length - 2, 4)
        removeCallbackIndex = Math.max(args.length - 1, 5)
        updateCallback = args[updateCallbackIndex] || (->)
        removeCallback = args[removeCallbackIndex] || (->)

        buildFile = (file) -> processFilePair([ file.path, outputFilePath(file.relative)], updateCallback)

        deleteFile = (file) ->
          builtPath = outputFilePath(file.relative)
          fs.unlink(builtPath , (err, success) -> removeCallback(err,builtPath))

        watchGlob(patterns, globOptions, buildFile, deleteFile)

        callback(err, success)

exports.fileToFile_globsToDir = (f, extension, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1) ->
  fileToFile_globsToDirWithOptionalWatch(f, extension, false, oldInputIndex, oldOutputIndex, newGlobOptionsIndex)

exports.fileToFile_globsToDirWithWatch = (f, extension, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1) ->
  fileToFile_globsToDirWithOptionalWatch(f, extension, true, oldInputIndex, oldOutputIndex, newGlobOptionsIndex)



exports.filesToFile_globsToFile = (f, oldInputIndex = 0, oldOutputIndex = 1, newGlobOptionsIndex = 1) -> () ->
  args = Array.prototype.slice.call(arguments)
  inputIndex = if newGlobOptionsIndex <= oldInputIndex then oldInputIndex + 1 else oldInputIndex
  outputIndex = if newGlobOptionsIndex <= oldOutputIndex then oldOutputIndex + 1 else oldOutputIndex
  callbackIndex = Math.max(args.length - 1, 3)

  callback = if _.isFunction(args[callbackIndex]) then args[callbackIndex] else (->)

  patterns = if _.isArray(args[inputIndex]) then args[inputIndex] else [ args[inputIndex] ]
  globOptions = args[newGlobOptionsIndex]
  outputFile = args[outputIndex]

  async.map patterns, ((pattern, cb) -> glob(pattern, globOptions, cb)), (err, matches) ->
    allMatches = _(matches).flatten().uniq().value()
    inFilesAbsolute = _.map(allMatches, (p) -> path.resolve(globOptions?.cwd || '', p))

    args[inputIndex] = inFilesAbsolute
    #Remove outFile from args to original function
    args.splice(newGlobOptionsIndex, 1)
    f.apply(null, args)



exports.transformStream_stringToString = (transformStreamConstructor) ->
  (inputString, callback = (->)) ->
    gotError = false

    s = transformStreamConstructor()

    w = concatStream { encoding: 'string' }, (data) ->
      if !gotError then callback(null, data) 
    
    s.on 'error', (err) ->
      gotError = true
      callback(err)

    s.pipe(w)
    s.write(inputString)
    s.end()


exports.transformStream_fileToFile = (transformStreamConstructor) ->
  (inputFile, outFile, callback = (->)) ->
    gotError = false

    s = transformStreamConstructor()

    mkdirp path.dirname(outFile), (err, createdDir) ->
      readStream = fs.createReadStream(inputFile, { encoding: 'utf-8' })
      writeStream = fs.createWriteStream(outFile)
      stream = readStream.pipe(s).pipe(writeStream)

      stream.on('finish', () -> if !gotError then callback(null, outFile))

      handleError = (err) ->
        gotError = true
        writeStream.end()
        callback(err)

      readStream.on('error', handleError)
      s.on('error', handleError)
      


exports.transformStream_globsToDir = (transformStreamConstructor, ext) ->
  fileToFile = exports.transformStream_fileToFile(transformStreamConstructor) # fileToFile(inFile, outFile, callback)
  exports.fileToFile_globsToDir(fileToFile, ext)

exports.stringToString_globsToDir = (f, ext, inputIndex = 0) ->
  fileToFile = exports.stringToString_fileToFile(f, inputIndex) # fileToFile(inFile, outFile, callback)
  exports.fileToFile_globsToDir(fileToFile, ext, inputIndex)

exports.stringToString_globsToDirWithWatch = (f, ext, inputIndex = 0) ->
  fileToFile = exports.stringToString_fileToFile(f, inputIndex) # fileToFile(inFile, outFile, callback)
  exports.fileToFile_globsToDirWithWatch(fileToFile, ext, inputIndex)

exports.sync_fileToFile = (f, inputIndex = 0) ->
  exports.stringToString_fileToFile(exports.sync_async(f), inputIndex)

exports.sync_globsToDir = (f, extension, inputIndex = 0) ->
  exports.stringToString_globsToDir(exports.sync_async(f), extension, inputIndex)

exports.sync_globsToDirWithWatch = (f, extension, inputIndex = 0) ->
  exports.stringToString_globsToDirWithWatch(exports.sync_async(f), extension, inputIndex)



exports.stringsToString_globsToFile = (f, inputIndex = 0) ->
  fileToFile = exports.stringsToString_filesToFile(f, inputIndex) # fileToFile(inFile, outFile, callback)
  exports.filesToFile_globsToFile(fileToFile, inputIndex)

exports.sync_filesToFile = (f, inputIndex = 0) ->
  exports.stringsToString_filesToFile(exports.sync_async(f), inputIndex)

exports.sync_globsToFile = (f, inputIndex = 0) ->
  exports.stringsToString_globsToFile(exports.sync_async(f), inputIndex)
