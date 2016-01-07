#!/usr/bin/env coffee

debugger
# Debugging in iron-node
require("fake-require-main").fakeFor require, __filename, "electron"

__ = require 'lodash'
path = require 'path'
fs = require 'fs-extra'
zmq = require 'zmq'

args = do ->
  if require.main is module
    ArgumentParser = require('argparse').ArgumentParser
    cmdName = 'pcf'
    parser = new ArgumentParser
      prog: cmdName
      version: '0.0.1'
      addHelp: true
      description:
        [
          cmdName
          '"Procrustes" SmArT is a CLI utility for copying subtrees containing supported audio'
          'files in sequence, naturally sorted.'
          'The end result is a "flattened" copy of the source subtree. "Flattened" means'
          'that only a namesake of the root source directory is created, where all the files get'
          'copied to, names prefixed with a serial number. Tags "Track" and "Tracks Total"'
          'get set, tags "Artist" and "Album" can be replaced optionally.'
          'The writing process is strictly sequential: either starting with the number one file,'
          'or in the reversed order. This can be important for some mobile devices.'
        ].join ' '

    parser.addArgument ['-f', '--file-title'],
      {help: "use file name for title tag", action: 'storeTrue'}
    parser.addArgument ['-x', '--sort-lex'],
      {help: "sort files lexicographically", action: 'storeTrue'}
    parser.addArgument ['-t', '--tree-dst'],
      {help: "retain the tree structure of the source album at destination", action: 'storeTrue'}
    parser.addArgument ['-p', '--drop-dst'],
      {help: "do not create destination directory", action: 'storeTrue'}
    parser.addArgument ['-r', '--reverse'],
      {help: "copy files in reverse order (number one file is the last to be copied)", action: 'storeTrue'}
    parser.addArgument ['-e', '--file-type'],
      {help: "accept only audio files of the specified type"}
    parser.addArgument ['-u', '--unified-name'],
      {
        help: [
                "destination root directory name and file names are based on UNIFIED_NAME,"
                "serial number prepended, file extensions retained; also album tag,"
                "if the latter is not specified explicitly"
              ].join ' '
      }
    parser.addArgument ['-b', '--album-num'],
      {help: "0..99; prepend ALBUM_NUM to the destination root directory name"}
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


fluffChar = "\u27a4"


sansExt = (pth) ->
  ###
  Discards file extension
  ###
  parts = path.parse pth
  path.join parts.dir, parts.name


hasExtOf = (pth, ext) ->
  ###
  Returns true, if pth has extension ext, case and leading dot insensitive
  ###
  extension = if ext is '' or ext[0] is '.' then ext else '.' + ext
  path.extname(pth).toUpperCase() is extension.toUpperCase()


strStripNumbers = (str) ->
  ###
  Returns a vector of integer numbers
  embedded in a string argument
  ###
  match = str.match /\d+/g
  if match then match.map __.parseInt else match


arrayCmp = (x, y) ->
  ###
  Compares arrays of integers using 'string semantics'
  ###
  if x.length is 0 then return (if y.length is 0 then 0 else -1)
  if y.length is 0 then return (if x.length is 0 then 0 else 1)
  i = 0
  while x[i] is y[i]
    if i is x.length - 1 or i is y.length - 1
      # Short array is a prefix of the long one; end reached. All is equal so far.
      if x.length is y.length then return 0   # Long array is no longer than the short one.
      return if x.length < y.length then -1 else 1
    i++
  # Difference encountered.
  if x[i] < y[i] then -1 else 1


strcmp = (x, y) -> if x < y then -1 else +(x > y)
### Compares strings ###


strcmpNaturally = (x, y) ->
  ###
  If both strings contain digits, returns numerical comparison based on the numeric
  values embedded in the strings, otherwise returns the standard string comparison.
  The idea of the natural sort as opposed to the standard lexicographic sort is one of coping
  with the possible absence of the leading zeros in 'numbers' of files or directories
  ###
  a = strStripNumbers x
  b = strStripNumbers y
  if a and b then arrayCmp a, b else strcmp x, y


makeInitials = (name, sep='.', trail='.', hyph='-') ->
  ###
  Reduces a string of names to initials
  ###

  # Remove double quoted substring, if any.
  quotes = name.match /\"/g
  qcnt = if quotes then quotes.length else 0
  enm = if qcnt is 0 or qcnt %% 2
          name
        else
          name.replace(/"(.*?)"/g, ' ')

  splitBySpace = (nm) ->
    nm.trim().split(/\s+/).map((x) -> x[0]).join(sep).toUpperCase()
  enm.split(hyph).map(splitBySpace).join(hyph) + trail


collectDirsAndFiles = (absPath, fileCondition) ->
  ###
  Returns a list of directories in absPath directory, and a list of files filtered by fileCondition
  ###
  lst = fs.readdirSync(absPath).map((x) -> path.join absPath, x)
  dirs = []; files = []
  for item in lst
    if fs.lstatSync(item).isDirectory()
      dirs.push item
    else
      if fileCondition item then files.push item
  {dirs: dirs, files: files}


fileCount = (dirPath, fileCondition) ->
  ###
  Returns a total number of files in the dirPath directory filtered by fileCondition
  ###
  cnt = 0; haul = collectDirsAndFiles dirPath, fileCondition
  for dir in haul.dirs
    cnt += fileCount dir, fileCondition
  for file in haul.files
    if fileCondition file then cnt++
  cnt


comparePath = (xp, yp) ->
  ###
  Compares two paths, ignoring extensions
  ###
  x = sansExt(xp)
  y = sansExt(yp)
  if args.sort_lex then strcmp x, y else strcmpNaturally x, y


compareFile = (xf, yf) ->
  ###
  Compares two paths, filenames only, ignoring extensions
  ###
  x = sansExt path.parse(xf).base
  y = sansExt path.parse(yf).base
  if args.sort_lex then strcmp x, y else strcmpNaturally x, y


isAudioFile = (pth) ->
  ###
  Returns true, if pth is a recognized audio file
  ###
  if fs.lstatSync(pth).isDirectory() then return false
  if ['.MP3', '.M4A', '.M4B', '.OGG', '.WMA'].indexOf(path.extname(pth).toUpperCase()) isnt -1 then return true
  false


listDirGroom = (absPath, reverse) ->
  ###
  Returns (0) a naturally sorted list of
  offspring directory paths (1) a naturally sorted list
  of offspring file paths.
  ###
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
  ###
  Recursively traverses the source directory and yields a sequence of (src, flat dst) pairs;
  the destination directory and file names get decorated according to options
  ###
  groom = listDirGroom srcDir, false
  for dir in groom.dirs
    yield from traverseFlatDst dir, dstRoot, fcount, cntw
  for file in groom.files
    dst = path.join dstRoot, decorateFileName cntw, fcount[0], path.basename file
    fcount[0]++
    yield {src: file, dst: dst}
  return


traverseFlatDstReverse = (srcDir, dstRoot, fcount, cntw) ->
  ###
  Recursively traverses the source directory backwards (-r) and yields a sequence of (src, flat dst) pairs;
  the destination directory and file names get decorated according to options
  ###
  groom = listDirGroom srcDir, true
  for file in groom.files
    dst = path.join dstRoot, decorateFileName cntw, fcount[0], path.basename file
    fcount[0]--
    yield {src: file, dst: dst}
  for dir in groom.dirs
    yield from traverseFlatDstReverse dir, dstRoot, fcount, cntw
  return


traverseTreeDst = (srcDir, dstRoot, dstStep, cntw) ->
  ###
  Recursively traverses the source directory and yields a sequence of (src, tree dst) pairs;
  the destination directory and file names get decorated according to options
  ###
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
  ###
  Makes an 'executive' run of traversing the source directory; returns the 'ammo belt' generator
  ###
  cntw = cnt.toString().length
  if args.tree_dst
    return traverseTreeDst src, dst, '', cntw
  else
    if args.reverse
      return traverseFlatDstReverse src, dst, [cnt], cntw
    else
      return traverseFlatDst src, dst, [1], cntw


buildAlbum = -> 
  ###
  Sets up boilerplate required by the options and returns the ammo belt generator
  of (src, dst) pairs
  ###
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
  ###
  Runs through the ammo belt and does copying, in the reverse order if necessary
  ###
  alb = buildAlbum()

  spawn = require('child_process').spawn
  srv = spawn 'python', ['-u', '/home/alexey/Dropbox/procrustes/procrserver.py']
  srv.stdout.on 'data', (data) -> console.log "stdout: #{data}"
  srv.stderr.on 'data', (data) -> console.log fluffChar.repeat(7)

  requester = zmq.socket 'req'
  check = 0
  requester.on "message",
    (reply) ->
      check++
      if check >= alb.count
        requester.close()
        console.log "     #{fluffChar.repeat(2)} #{check} file(s) copied " + 
                    "and tagged #{fluffChar.repeat(2)}"
        process.exit 0
      return
  
  requester.connect "tcp://localhost:64107"
  
  setTags = (i, total, pth, title) ->
    buildTitle = (s) -> if title then title else "#{i} #{s}"

    rq = {}
    rq.request = 'settags'
    rq.file = pth
    rq.tags = {}
    rq.tags.tracknumber = "#{i}/#{total}"
    
    if args.artist_tag and args.album_tag
      rq.tags.title = buildTitle makeInitials(args.artist_tag) + ' - ' + args.album_tag
      rq.tags.artist = args.artist_tag
      rq.tags.album = args.album_tag
    else if args.artist_tag
      rq.tags.title = buildTitle args.artist_tag
      rq.tags.artist = args.artist_tag
    else if args.album_tag
      rq.tags.title = buildTitle args.album_tag
      rq.tags.album = args.album_tag
    
    requester.send JSON.stringify(rq)
    return
  
  copyFile = (i, total, entry) ->
    fs.copySync entry.src, entry.dst
    console.log "#{spacePad(4, i)}/#{total} #{fluffChar} #{entry.dst}"
    setTags i, total, entry.dst, if args.file_title then sansExt path.basename entry.dst else null
    return

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
