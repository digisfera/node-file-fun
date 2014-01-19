expect = require('chai').expect
fileFun = require('../src/index')
mkdirp = require('mkdirp')
rimraf = require('rimraf')
path = require('path')
fs = require('fs')
stream = require('stream')


describe 'file-fun', ->

  delay = (t, f) -> setTimeout(f, t)
  djoin = (p) -> path.join(__dirname, 'files', p)
  rfile = (p) -> fs.readFileSync(p, { encoding: 'utf-8'})

  uppercaseTransformStream = () ->
    transformStream = new stream.Transform({decodeStrings: false})
    transformStream._transform = (chunk, encoding, done) -> done(null, chunk.toUpperCase())
    transformStream

  before ->
    rimraf.sync(djoin('tmp'))
    mkdirp.sync(djoin('tmp'))

  upperCaseFun = (input) -> input.toUpperCase()

  describe 'sync_async', ->

    f = asyncF = null
    before ->
      asyncF = fileFun.sync_async(upperCaseFun)

    it 'should make function assynchronous, adding callback as last argument', (done) ->
      asyncF 'foo', (err, res) ->
        expect(err).to.be.not.ok
        expect(res).to.equal('FOO')
        done()

    it 'should callback error if function threw', (done) ->
      asyncF null, (err, res) ->
        expect(err).to.be.ok
        done() 

    it 'should not attempt to call callback if last argument is not a function', (done) ->
      asyncF('bar')
      setTimeout(done, 10)

  describe 'stringToString_fileToFile', ->

    f = null
    before ->
      f = (input, cb) -> delay 1, ->
        try 
          cb(null, input.toUpperCase())
        catch e
          cb(e)        

    it 'should make function read input from file and write output to file, adding outputPath as argument', (done) ->
      outFile = djoin('tmp/f1.txt')
      fileF = fileFun.stringToString_fileToFile(f, 0, 1)
      fileF djoin('f1.txt'),outFile , (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()


    it 'should work when output is added before input', (done) ->
      outFile = djoin('tmp/f1b.txt')
      fileF = fileFun.stringToString_fileToFile(f, 0, 0)
      fileF outFile, djoin('f1.txt'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()

    it 'should not attempt to call callback if last argument is not a function', (done) ->
      outFile = djoin('tmp/f1c.txt')
      fileF = fileFun.stringToString_fileToFile(f, 0, 1)
      fileF(djoin('f1.txt'), outFile)

      delay 50, ->
        expect(rfile(outFile)).to.equal('FOO')
        done()

    it 'should create folders to write output file if necessary', (done) ->
      outFile = djoin('tmp/dir1/dir2/f1d.txt')
      fileF = fileFun.stringToString_fileToFile(f, 0, 1)
      fileF djoin('f1.txt'),outFile , (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()

  describe 'fileToFile_globsToDir', ->

    f = null
    before ->
      f = fileFun.stringToString_fileToFile(fileFun.sync_async(upperCaseFun))

    it 'should read files in glob and write output to dir', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF 'g*.txt', { cwd: djoin('') }, djoin('tmp'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/g1.txt.ext'), djoin('tmp/g2.txt.ext'), djoin('tmp/g3.txt.ext') ])
        expect(rfile(djoin('tmp/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/g2.txt.ext'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/g3.txt.ext'))).to.equal('BAR')
        done()


    it 'not add extension if it is empty or null', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, '')
      globF 'g*.txt', { cwd: djoin('') }, djoin('tmp/glob2'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob2/g1.txt'), djoin('tmp/glob2/g2.txt'), djoin('tmp/glob2/g3.txt') ])
        expect(rfile(djoin('tmp/glob2/g1.txt'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob2/g2.txt'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/glob2/g3.txt'))).to.equal('BAR')
        done()

    it 'should work if cwd is not given', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF djoin('g*.txt'), {}, djoin('tmp/glob3'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob3/g1.txt.ext'), djoin('tmp/glob3/g2.txt.ext'), djoin('tmp/glob3/g3.txt.ext') ])
        expect(rfile(djoin('tmp/glob3/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob3/g2.txt.ext'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/glob3/g3.txt.ext'))).to.equal('BAR')
        done()

    it 'should replicate directory structure', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF 'g4/**/*.txt', { cwd: djoin('') }, djoin('tmp/glob4'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob4/g4/bar.txt.ext'), djoin('tmp/glob4/g4/baz.txt.ext'), djoin('tmp/glob4/g4/foo/test.txt.ext') ])
        expect(rfile(djoin('tmp/glob4/g4/bar.txt.ext'))).to.equal('BAR')
        expect(rfile(djoin('tmp/glob4/g4/baz.txt.ext'))).to.equal('BAZ')
        expect(rfile(djoin('tmp/glob4/g4/foo/test.txt.ext'))).to.equal('TEST')
        done()

    it 'should take multiple globs', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF [ '*1.txt', 'g2.*' ], { cwd: djoin('') }, djoin('tmp/glob5'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob5/f1.txt.ext'), djoin('tmp/glob5/g1.txt.ext'), djoin('tmp/glob5/g2.txt.ext') ])
        expect(rfile(djoin('tmp/glob5/f1.txt.ext'))).to.equal('FOO')
        expect(rfile(djoin('tmp/glob5/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob5/g2.txt.ext'))).to.equal('WORLD')
        done()


    it 'should not repeat files, even if they are matched in multiple globs', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF [ '*1.txt', 'g1.*' ], { cwd: djoin('') }, djoin('tmp/glob6'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob6/f1.txt.ext'), djoin('tmp/glob6/g1.txt.ext') ])
        expect(rfile(djoin('tmp/glob6/f1.txt.ext'))).to.equal('FOO')
        expect(rfile(djoin('tmp/glob6/g1.txt.ext'))).to.equal('HELLO')
        done()

    it 'should not attempt to call callback if last argument is not a function', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF 'g*.txt', { cwd: djoin('') }, djoin('tmp/glob7')
      delay 50, ->
        expect(rfile(djoin('tmp/glob7/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob7/g2.txt.ext'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/glob7/g3.txt.ext'))).to.equal('BAR')
        done()


    it 'should work if globOptions index is smaller than input and output index', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext', 0, 1, 0)
      globF { cwd: djoin('') }, 'g*.txt', djoin('tmp/glob8'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob8/g1.txt.ext'), djoin('tmp/glob8/g2.txt.ext'), djoin('tmp/glob8/g3.txt.ext') ])
        expect(rfile(djoin('tmp/glob8/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob8/g2.txt.ext'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/glob8/g3.txt.ext'))).to.equal('BAR')
        done()

    it 'should work if globOptions index is larger than input and output index', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext', 0, 1, 2)
      globF 'g*.txt', djoin('tmp/glob8'), { cwd: djoin('') }, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob8/g1.txt.ext'), djoin('tmp/glob8/g2.txt.ext'), djoin('tmp/glob8/g3.txt.ext') ])
        expect(rfile(djoin('tmp/glob8/g1.txt.ext'))).to.equal('HELLO')
        expect(rfile(djoin('tmp/glob8/g2.txt.ext'))).to.equal('WORLD')
        expect(rfile(djoin('tmp/glob8/g3.txt.ext'))).to.equal('BAR')
        done()

    it 'should pass this big test', (done) ->
      globF = fileFun.fileToFile_globsToDir(f, 'ext')
      globF [ 'g4/**/*.txt', 'g4/ba*.txt' ], { cwd: djoin('') }, djoin('tmp/glob9'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob9/g4/bar.txt.ext'), djoin('tmp/glob9/g4/baz.txt.ext'), djoin('tmp/glob9/g4/foo/test.txt.ext') ])
        expect(rfile(djoin('tmp/glob9/g4/bar.txt.ext'))).to.equal('BAR')
        expect(rfile(djoin('tmp/glob9/g4/baz.txt.ext'))).to.equal('BAZ')
        expect(rfile(djoin('tmp/glob9/g4/foo/test.txt.ext'))).to.equal('TEST')
        done()

  describe 'fileToFile_globsToDirWithWatch', ->
    it 'should build file when original is changed'
    it 'should build file when new file is added'
    it 'should remove built file when original is deleted'
    it 'should build new file and remove old one on rename'

  describe 'transformStream_stringToString', ->


    it 'should receive string input and callback with string', (done) ->
      stringF = fileFun.transformStream_stringToString(uppercaseTransformStream)
      stringF 'foo', (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal('FOO')
        done()

    it 'should callback with error if stream has error event', (done) ->
      transformStreamConstructor = ->
        transformStream = new stream.Transform({decodeStrings: false})
        transformStream._transform = (chunk, encoding, done) -> done("explode")
        transformStream

      stringF = fileFun.transformStream_stringToString(transformStreamConstructor)
      stringF 'foo', (err, success) ->
        expect(err).to.be.ok
        done()

    it 'should not attempt to call callback if last argument is not a function', (done) ->
      stringF = fileFun.transformStream_stringToString(uppercaseTransformStream)
      stringF('foo')
      delay(10, done)

  describe 'transformStream_fileToFile', ->
    
    it 'should receive filePath input and write result to file', (done) ->
      outFile = djoin('tmp/s1.txt')
      fileF = fileFun.transformStream_fileToFile(uppercaseTransformStream)
      fileF djoin('f1.txt'),outFile , (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()

    it 'should callback error if file does not exist', (done) ->
      outFile = djoin('tmp/s3.txt')
      fileF = fileFun.transformStream_fileToFile(uppercaseTransformStream)
      fileF 'unexisting_file', outFile , (err, success) ->
        expect(err).to.be.ok
        done()

    it 'should callback error if function calls back error', (done) ->
      transformStreamConstructor = ->
        transformStream = new stream.Transform({decodeStrings: false})
        transformStream._transform = (chunk, encoding, done) -> done("explode")
        transformStream

      outFile = djoin('tmp/s4.txt')
      fileF = fileFun.transformStream_fileToFile(transformStreamConstructor)
      fileF djoin('f1.txt'), outFile , (err, success) ->
        expect(err).to.be.ok
        done()

    it 'should not attempt to call callback if last argument is not a function', (done) ->
      outFile = djoin('tmp/s5.txt')
      fileF = fileFun.transformStream_fileToFile(uppercaseTransformStream)
      fileF djoin('f1.txt'),outFile
      delay 50, ->
        expect(rfile(outFile)).to.equal('FOO')
        done()

    it 'should create folders to write output file if necessary', (done) ->
      outFile = djoin('tmp/streams/s6.txt')
      fileF = fileFun.transformStream_fileToFile(uppercaseTransformStream)
      fileF djoin('f1.txt'),outFile , (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()

  describe 'transformStream_globsToDir', ->
    it 'should pass this big test', (done) ->
      globF = fileFun.transformStream_globsToDir(uppercaseTransformStream, 'ext')
      globF [ 'g4/**/*.txt', 'g4/ba*.txt' ], { cwd: djoin('') }, djoin('tmp/glob10'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob10/g4/bar.txt.ext'), djoin('tmp/glob10/g4/baz.txt.ext'), djoin('tmp/glob10/g4/foo/test.txt.ext') ])
        expect(rfile(djoin('tmp/glob10/g4/bar.txt.ext'))).to.equal('BAR')
        expect(rfile(djoin('tmp/glob10/g4/baz.txt.ext'))).to.equal('BAZ')
        expect(rfile(djoin('tmp/glob10/g4/foo/test.txt.ext'))).to.equal('TEST')
        done()

  describe 'stringToString_globsToDir', ->
    it 'should pass this big test', (done) ->
      globF = fileFun.stringToString_globsToDir(fileFun.sync_async(upperCaseFun), 'ext')
      globF [ 'g4/**/*.txt', 'g4/ba*.txt' ], { cwd: djoin('') }, djoin('tmp/glob11'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob11/g4/bar.txt.ext'), djoin('tmp/glob11/g4/baz.txt.ext'), djoin('tmp/glob11/g4/foo/test.txt.ext') ])
        expect(rfile(djoin('tmp/glob11/g4/bar.txt.ext'))).to.equal('BAR')
        expect(rfile(djoin('tmp/glob11/g4/baz.txt.ext'))).to.equal('BAZ')
        expect(rfile(djoin('tmp/glob11/g4/foo/test.txt.ext'))).to.equal('TEST')
        done()


  describe 'sync_fileToFile', ->
    it 'should pass this big test', (done) ->
      outFile = djoin('tmp/sync_fileToFile.txt')
      fileF = fileFun.sync_fileToFile(upperCaseFun)
      fileF djoin('f1.txt'), outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql(outFile)
        expect(rfile(outFile)).to.equal('FOO')
        done()

  describe 'sync_globsToDir', ->
    it 'should pass this big test', (done) ->
      globF = fileFun.sync_globsToDir(upperCaseFun, 'ext')
      globF [ 'g4/**/*.txt', 'g4/ba*.txt' ], { cwd: djoin('') }, djoin('tmp/glob12'), (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql([ djoin('tmp/glob12/g4/bar.txt.ext'), djoin('tmp/glob12/g4/baz.txt.ext'), djoin('tmp/glob12/g4/foo/test.txt.ext') ])
        expect(rfile(djoin('tmp/glob12/g4/bar.txt.ext'))).to.equal('BAR')
        expect(rfile(djoin('tmp/glob12/g4/baz.txt.ext'))).to.equal('BAZ')
        expect(rfile(djoin('tmp/glob12/g4/foo/test.txt.ext'))).to.equal('TEST')
        done()


  describe 'stringsToString_filesToFile', ->
    concat = fileFun.sync_async((strList) -> strList.join(''))
    it 'should receive list of files as input and write output to file', (done) ->
      outFile = djoin('tmp/concat1.txt')
      fileF = fileFun.stringsToString_filesToFile(concat)
      fileF [ djoin('g1.txt'), djoin('g2.txt') ], outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('helloworld')
        done()

  describe 'filesToFile_globsToFile', ->
    concat = fileFun.stringsToString_filesToFile(fileFun.sync_async((strList) -> strList.join('')))
    it 'should read files in glob and write output to file', (done) ->
      outFile = djoin('tmp/concat2.txt')
      globF = fileFun.filesToFile_globsToFile(concat)
      globF 'g*.txt', { cwd: djoin('') }, outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql(outFile)
        expect(rfile(outFile)).to.equal('helloworldbar')
        done()

  describe 'stringsToString_globsToFile', ->
    concat = fileFun.sync_async((strList) -> strList.join(''))
    it 'should read files in glob and write output to file', (done) ->
      outFile = djoin('tmp/concat3.txt')
      globF = fileFun.stringsToString_globsToFile(concat)
      globF 'g*.txt', { cwd: djoin('') }, outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql(outFile)
        expect(rfile(outFile)).to.equal('helloworldbar')
        done()


  describe 'sync_filesToFile', ->
    concat = (strList) -> strList.join('')
    it 'should receive list of files as input and write output to file', (done) ->
      outFile = djoin('tmp/concat4.txt')
      fileF = fileFun.sync_filesToFile(concat)
      fileF [ djoin('g1.txt'), djoin('g2.txt') ], outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.equal(outFile)
        expect(rfile(outFile)).to.equal('helloworld')
        done()


  describe 'sync_globsToFile', ->
    concat = (strList) -> strList.join('')
    it 'should read files in glob and write output to file', (done) ->
      outFile = djoin('tmp/concat5.txt')
      globF = fileFun.sync_globsToFile(concat)
      globF 'g*.txt', { cwd: djoin('') }, outFile, (err, success) ->
        expect(err).to.be.not.ok
        expect(success).to.eql(outFile)
        expect(rfile(outFile)).to.equal('helloworldbar')
        done()
