#!/usr/bin/env coffee

debugger

__ = require 'lodash'
path = require 'path'
fs = require 'fs-extra'

args = (->
  if require.main is module
    ArgumentParser = require('argparse').ArgumentParser
    parser = new ArgumentParser({
      version: '0.0.1',
      addHelp: true,
      description:
        [
          'pcn "Procrustes" SmArT is a CLI utility for copying subtrees containing supported audio',
          'files in sequence, naturally sorted.',
          'The end result is a "flattened" copy of the source subtree. "Flattened" means',
          'that only a namesake of the root source directory is created, where all the files get',
          'copied to, names prefixed with a serial number. Tags "Track" and "Tracks Total"',
          'get set, tags "Artist" and "Album" can be replaced optionally.',
          'The writing process is strictly sequential: either starting with the number one file,',
          'or in the reversed order. This can be important for some mobile devices.'
        ].join(' ')
    })

    parser.addArgument(['-f', '--file-title'], {help: "use file name for title tag", action: 'storeTrue'})
    parser.addArgument(['-x', '--sort-lex'], {help: "sort files lexicographically", action: 'storeTrue'})
    parser.addArgument(['-t', '--tree-dst'], {help: "retain the tree structure of the source album at destination", action: 'storeTrue'})
    parser.addArgument(['-p', '--drop-dst'], {help: "do not create destination directory", action: 'storeTrue'})
    parser.addArgument(['-r', '--reverse'], {help: "copy files in reverse order (number one file is the last to be copied)", action: 'storeTrue'})
    parser.addArgument(['-e', '--file-type'], {help: "accept only audio files of the specified type"})
    parser.addArgument(['-u', '--unified-name'],
      {
        help: [
                "destination root directory name and file names are based on UNIFIED_NAME,",
                "serial number prepended, file extensions retained; also album tag,",
                "if the latter is not specified explicitly"
              ].join(' ')
      })
    parser.addArgument(['-b', '--album-num'], {help: "0..99; prepend ALBUM_NUM to the destination root directory name"})
    parser.addArgument(['-a', '--artist-tag'], {help: "artist tag name"})
    parser.addArgument(['-g', '--album-tag'], {help: "album tag name"})
    parser.addArgument(['src_dir'], {help: "source directory"})
    parser.addArgument(['dst_dir'], {help: "general destination directory"})

    rg = parser.parseArgs()

    rg.src_dir = path.resolve(rg.src_dir)
    rg.dst_dir = path.resolve(rg.dst_dir)

    if rg.tree_dst and rg.reverse
      console.log("  *** -t option ignored (conflicts with -r) ***")
      rg.tree_dst = false
    if rg.unified_name and not rg.album_tag
      rg.album_tag = rg.unified_name
    rg
  else
    null
)(@)

sansExt = (pth) ->
  parts = path.parse pth
  path.join parts.dir, parts.name

hasExtOf = (pth, ext) ->
  extension = if ext is '' or ext[0] is '.' then ext else '.' + ext
  path.extname(pth).toUpperCase() is extension.toUpperCase()

strStripNumbers = (str) ->
  match = str.match /\d+/g
  if match then match.map __.parseInt else match

arrayCmp = (x, y) ->
  if x.length is 0 then return (if y.length is 0 then 0 else -1)
  if y.length is 0 then return (if x.length is 0 then 0 else 1)
  i = 0
  while x[i] is y[i]
    if i is x.length - 1 or i is y.length - 1
      if x.length is y.length then return 0
      return if x.length < y.length then -1 else 1
    i++
  if x[i] < y[i] then -1 else 1

strcmp = (x, y) -> if x < y then -1 else +(x > y)

strcmpNaturally = (x, y) ->
  a = strStripNumbers x
  b = strStripNumbers y
  if a and b then arrayCmp a, b else strcmp x, y

makeInitials = (name, sep='.', trail='.', hyph='-') ->
  splitBySpace = (nm) ->
    nm.trim().split(/\s+/).map((x) -> x[0]).join(sep).toUpperCase()
  name.split(hyph).map(splitBySpace).join(hyph) + trail

collectDirsAndFiles = (absPath, fileCondition) ->
  lst = fs.readdirSync(absPath).map((x) -> path.join absPath, x)
  i = 0; dirs = []; files = []
  while i < lst.length
    if fs.lstatSync(lst[i]).isDirectory()
      dirs.push lst[i]
    else
      if fileCondition lst[i] then files.push lst[i]
    i++
  {dirs: dirs, files: files}

fileCount = (dirPath, fileCondition) ->
  i = 0; cnt = 0; haul = collectDirsAndFiles dirPath, fileCondition
  while i < haul.dirs.length
    cnt += fileCount haul.dirs[i], fileCondition
    i++
  i = 0
  while i < haul.files.length
    if fileCondition haul.files[i] then cnt++
    i++
  cnt

comparePath = (xp, yp) ->
  x = sansExt(xp)
  y = sansExt(yp)
  if args.sort_lex then strcmp x, y else strcmpNaturally x, y

compareFile = (xf, yf) ->
  x = sansExt path.parse(xf).base
  y = sansExt path.parse(yf).base
  if args.sort_lex then strcmp x, y else strcmpNaturally x, y

isAudioFile = (pth) ->
  if fs.lstatSync(pth).isDirectory() then return false
  if ['.MP3', '.M4A'].indexOf(path.extname(pth).toUpperCase()) isnt -1 then return true
  false

listDirGroom = (absPath, reverse) ->
  haul = collectDirsAndFiles absPath, isAudioFile
  {
    dirs: haul.dirs.sort if reverse then (xp, yp) -> -comparePath xp, yp else comparePath,
    files: haul.files.sort if reverse then (xf, yf) -> -compareFile xf, yf else compareFile
  }

zeroPad = (w, i) -> (['ZZZ', '0', '00', '000', '0000', '00000'][w] + i).slice(-w)

spacePad = (w, i) -> (['ZZZ', ' ', '  ', '   ', '    ', '     '][w] + i).slice(-w)

decorateDirName = (i, name) -> zeroPad(3, i) + '-' + name

decorateFileName = (cntw, i, name) ->
  zeroPad(cntw, i) + '-' + if args.unified_name then args.unified_name + path.extname(name) else name

traverseFlatDst = (srcDir, dstRoot, flatAcc, fcount, cntw) ->
  i = 0; groom = listDirGroom srcDir, false
  while i < groom.dirs.length
    traverseFlatDst groom.dirs[i], dstRoot, flatAcc, fcount, cntw
    i++
  i = 0
  while i < groom.files.length
    dst = path.join(dstRoot, decorateFileName(cntw, fcount[0], path.basename(groom.files[i])))
    flatAcc.push {src: groom.files[i], dst: dst}
    fcount[0]++
    i++


if require.main is module
  console.log 'main: '
else
  u = module.exports
  u.sansExt = sansExt
  u.hasExtOf = hasExtOf
  u.strStripNumbers = strStripNumbers
  u.arrayCmp = arrayCmp
  u.strcmpNaturally = strcmpNaturally
  u.makeInitials = makeInitials
