#!/usr/bin/env coffee

debugger

__ = require 'lodash'
path = require 'path'
fs = require 'fs-extra'

args = ->
  ArgumentParser = require 'argparse'
  ArgPars = ArgumentParser.ArgumentParser
  'Hello, ladies!'

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

if require.main is module
  console.log args()
else
  u = module.exports
  u.sansExt = sansExt
  u.hasExtOf = hasExtOf
  u.strStripNumbers = strStripNumbers
  u.arrayCmp = arrayCmp
  u.strcmpNaturally = strcmpNaturally
  u.makeInitials = makeInitials
