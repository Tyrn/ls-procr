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

describe 'arrayCmp(x, y)', ->
  it 'compares arrays of integers using "string semantics"', ->
    sut.arrayCmp([], [8]).should.equal -1
    sut.arrayCmp([], []).should.equal 0
    sut.arrayCmp([1], []).should.equal 1
    sut.arrayCmp([3], []).should.equal 1
    sut.arrayCmp([1, 2, 3], [1, 2, 3, 4, 5]).should.equal -1
    sut.arrayCmp([1, 4], [1, 4, 16]).should.equal -1
    sut.arrayCmp([2, 8], [2, 2, 3]).should.equal 1
    sut.arrayCmp([0, 0, 2, 4], [0, 0, 15]).should.equal -1
    sut.arrayCmp([0, 13], [0, 2, 2]).should.equal 1
    sut.arrayCmp([11, 2], [11, 2]).should.equal 0

describe 'strcmpNaturally(x, y)', ->
  it 'compares strings "naturally" with respect to embedded numbers', ->
    sut.strcmpNaturally("zulu", "charlie").should.equal 1
    sut.strcmpNaturally("", "").should.equal 0
    sut.strcmpNaturally("Grima", "Grima").should.equal 0
    sut.strcmpNaturally("2a", "10a").should.equal -1
    sut.strcmpNaturally("alfa", "bravo").should.equal -1

describe 'makeInitials(name)', ->
  it 'reduces a string of names to initials', ->
    sut.makeInitials(" ").should.equal "."
    sut.makeInitials("John ronald reuel Tolkien").should.equal "J.R.R.T."
    sut.makeInitials("e. B. Sledge").should.equal "E.B.S."
    sut.makeInitials("Apsley Cherry-Garrard").should.equal "A.C-G."
    sut.makeInitials("Windsor Saxe-\tCoburg - Gotha").should.equal "W.S-C-G."
    sut.makeInitials("Elisabeth Kubler-- - Ross").should.equal "E.K---R."
    sut.makeInitials("Fitz-Simmons   Ashton-Burke Leigh").should.equal "F-S.A-B.L."
