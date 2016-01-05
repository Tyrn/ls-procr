#!/usr/bin/env coffee

debugger
# Debugging in iron-node
require("fake-require-main").fakeFor require, __filename, "electron"

__ = require 'lodash'
path = require 'path'
fs = require 'fs-extra'


args = (->
  if require.main is module
    ArgumentParser = require('argparse').ArgumentParser
    cmdName = 'pcf'
    parser = new ArgumentParser({
      prog: cmdName,
      version: '0.0.1',
      addHelp: true
      description:
        [
          cmdName,
          '"Procrustes" SmArT is a CLI utility for copying subtrees containing supported audio',
          'files in sequence, naturally sorted.',
          'The end result is a "flattened" copy of the source subtree. "Flattened" means',
          'that only a namesake of the root source directory is created, where all the files get',
          'copied to, names prefixed with a serial number. Tags "Track" and "Tracks Total"',
          'get set, tags "Artist" and "Album" can be replaced optionally.',
          'The writing process is strictly sequential: either starting with the number one file,',
          'or in the reversed order. This can be important for some mobile devices.'
        ].join ' '
    })

    parser.addArgument ['-f', '--file-title'], {help: "use file name for title tag", action: 'storeTrue'}
    parser.addArgument ['-x', '--sort-lex'], {help: "sort files lexicographically", action: 'storeTrue'}
    parser.addArgument ['-t', '--tree-dst'], {help: "retain the tree structure of the source album at destination", action: 'storeTrue'}
    parser.addArgument ['-p', '--drop-dst'], {help: "do not create destination directory", action: 'storeTrue'}
    parser.addArgument ['-r', '--reverse'], {help: "copy files in reverse order (number one file is the last to be copied)", action: 'storeTrue'}
    parser.addArgument ['-e', '--file-type'], {help: "accept only audio files of the specified type"}
    parser.addArgument ['-u', '--unified-name'],
      {
        help: [
                "destination root directory name and file names are based on UNIFIED_NAME,",
                "serial number prepended, file extensions retained; also album tag,",
                "if the latter is not specified explicitly"
              ].join ' '
      }
    parser.addArgument ['-b', '--album-num'], {help: "0..99; prepend ALBUM_NUM to the destination root directory name"}
    parser.addArgument ['-a', '--artist-tag'], {help: "artist tag name"}
    parser.addArgument ['-g', '--album-tag'], {help: "album tag name"}
    parser.addArgument ['src_dir'], {help: "source directory"}
    parser.addArgument ['dst_dir'], {help: "general destination directory"}

    rg = parser.parseArgs()

    rg.src_dir = path.resolve rg.src_dir
    rg.dst_dir = path.resolve rg.dst_dir

    if rg.tree_dst and rg.reverse
      console.log "  *** -t option ignored (conflicts with -r) ***"
      rg.tree_dst = false
    if rg.unified_name and not rg.album_tag
      rg.album_tag = rg.unified_name
    rg
  else
    null
)()


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
  dirs = []; files = []
  for item in lst
    if fs.lstatSync(item).isDirectory()
      dirs.push item
    else
      if fileCondition item then files.push item
  {dirs: dirs, files: files}


fileCount = (dirPath, fileCondition) ->
  cnt = 0; haul = collectDirsAndFiles dirPath, fileCondition
  for dir in haul.dirs
    cnt += fileCount dir, fileCondition
  for file in haul.files
    if fileCondition file then cnt++
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
    dirs: haul.dirs.sort if reverse then (xp, yp) -> -comparePath xp, yp else comparePath
    files: haul.files.sort if reverse then (xf, yf) -> -compareFile xf, yf else compareFile
  }


zeroPad = (w, i) -> (['ZZZ', '0', '00', '000', '0000', '00000'][w] + i).slice(-w)


spacePad = (w, i) -> (['ZZZ', ' ', '  ', '   ', '    ', '     '][w] + i).slice(-w)


decorateDirName = (i, name) -> zeroPad(3, i) + '-' + name


decorateFileName = (cntw, i, name) ->
  zeroPad(cntw, i) + '-' + if args.unified_name then args.unified_name + path.extname(name) else name


traverseFlatDst = (srcDir, dstRoot, fcount, cntw) ->
  groom = listDirGroom srcDir, false
  for dir in groom.dirs
    yield from traverseFlatDst dir, dstRoot, fcount, cntw
  for file in groom.files
    dst = path.join dstRoot, decorateFileName cntw, fcount[0], path.basename file
    fcount[0]++
    yield {src: file, dst: dst}
  return


traverseFlatDstReverse = (srcDir, dstRoot, fcount, cntw) ->
  groom = listDirGroom srcDir, true
  for file in groom.files
    dst = path.join dstRoot, decorateFileName cntw, fcount[0], path.basename file
    fcount[0]--
    yield {src: file, dst: dst}
  for dir in groom.dirs
    yield from traverseFlatDstReverse dir, dstRoot, fcount, cntw
  return


traverseTreeDst = (srcDir, dstRoot, dstStep, cntw) ->
  groom = listDirGroom srcDir, false
  for dir, i in groom.dirs
    step = path.join dstStep, decorateDirName i, path.basename dir
    fs.mkdirSync path.join dstRoot, step
    yield from traverseTreeDst dir, dstRoot, step, cntw
  for file, i in groom.files
    dst = path.join dstRoot, path.join dstStep, decorateFileName cntw, i, path.basename file
    yield {src: file, dst: dst}
  return


groom = (src, dst, cnt) ->
  cntw = cnt.toString().length
  if args.tree_dst
    return traverseTreeDst src, dst, '', cntw
  else
    if args.reverse
      return traverseFlatDstReverse src, dst, [cnt], cntw
    else
      return traverseFlatDst src, dst, [1], cntw


buildAlbum = -> 
  srcName = path.basename args.src_dir
  prefix = if args.album_num then zeroPad(2, args.album_num) + '-' else ''
  baseDst = prefix + if args.unified_name then args.unified_name else srcName
  executiveDst = path.join args.dst_dir, if args.drop_dst then '' else baseDst

  if not args.drop_dst
    if fs.existsSync executiveDst
      console.log 'Destination directory "' + executiveDst + '" already exists.'
      process.exit()
    else
      fs.mkdirSync executiveDst
  
  tot = fileCount args.src_dir, isAudioFile
  belt = groom args.src_dir, executiveDst, tot
  
  if not args.drop_dst and tot is 0
    fs.unlinkSync executiveDst
    console.log 'There are no supported audio files in the source directory "' + args.src_dir + '".'
    process.exit()
  
  {count: tot, belt: belt}


copyAlbum = ->
  copyFile = (i, total, entry) ->
    fs.copySync entry.src, entry.dst
    console.log spacePad(4, i) + '/' + total + ' \u27a4 ' + entry.dst

  alb = buildAlbum()

  if args.reverse
    `var i = 0;
     for(round of alb.belt) {
       copyFile(alb.count - i, alb.count, round);
       i++;
     }`
  else
    `var i = 0;
     for(round of alb.belt) {
       copyFile(i + 1, alb.count, round);
       i++;
     }`
  return


if require.main is module
  copyAlbum()
else
  u = module.exports
  u.sansExt = sansExt
  u.hasExtOf = hasExtOf
  u.strStripNumbers = strStripNumbers
  u.arrayCmp = arrayCmp
  u.strcmpNaturally = strcmpNaturally
  u.makeInitials = makeInitials
