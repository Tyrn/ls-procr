sut = require '../src/pcn.coffee'
should = require 'should'
assert = require 'assert'

describe 'sansExt(path)', ->
  it 'returns path with file extension dropped', ->
    sut.sansExt('/alfa/bra.vo/masha.txt').should.equal '/alfa/bra.vo/masha'
    sut.sansExt('/alfa/bravo/charlie.dat').should.equal '/alfa/bravo/charlie'
#    sut.sansExt('').should.equal ''
    sut.sansExt('/alfa/bravo/charlie').should.equal '/alfa/bravo/charlie'
    sut.sansExt('/alfa/bravo/charlie/').should.equal '/alfa/bravo/charlie'
    sut.sansExt('/alfa/bra.vo/charlie.dat').should.equal '/alfa/bra.vo/charlie'

describe 'hasExtOf(path, ext)', ->
  it 'returns true, if path ends with ext', ->
    sut.hasExtOf('/alfa/bra.vo/masha.TXT', '.txt').should.equal true
    sut.hasExtOf('/alfa/bra.vo/masha.txt', 'TxT').should.equal true
    sut.hasExtOf('/alfa/bra.vo/masha', '').should.equal true
    sut.hasExtOf('/alfa/bra.vo/masha.', '.').should.equal true

describe 'strStripNumbers(str)', ->
  it 'returns an array of numbers embedded in str', ->
    sut.strStripNumbers('13uk4_8pz11n').should.deepEqual [13, 4, 8, 11]
    assert.equal sut.strStripNumbers('Mocha'), null
