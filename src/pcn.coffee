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

if require.main is module
  console.log args()
else
  u = module.exports
  u.sansExt = sansExt
  u.hasExtOf = hasExtOf
  u.strStripNumbers = strStripNumbers
