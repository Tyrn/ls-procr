#!/usr/bin/env coffee

###
#
# Unofficial setup pet script. Don't use if in doubt.
# Run (after git clone) in the project directory as superuser.
#
###

sh = require '/usr/lib/node_modules/shelljs'
tm = require('terminal-kit').terminal
path = require 'path'
isRoot = require 'is-root'


# Callbacks never called?
process.on 'SIGINT',
  ->
    tm.red.bold "Aborted by user?\n"
    process.exit()


process.on 'uncaughtException',
  (err) ->
    tm.red.bold "Permission denied?\n"
    process.exit()


exePath = '/usr/bin/'

lks = {
        cmd: {target: path.join(sh.pwd(), 'src/pcn.coffee'), linkPath: exePath, linkName: 'pcf'}
        srv: {target: path.join(sh.pwd(), 'src/procrserver.py'), linkPath: exePath, linkName: 'procrserver'}
      }

overWarn = do ->
  flw = -1
  ->
    flw++
    if not flw
      tm.brightWhite "\nThe following entities on the system will be overwritten:\n\n"
    return


for k, v of lks
  link = path.join v.linkPath, v.linkName
  if sh.which(v.linkName) is link
    overWarn()
    sh.exec "ls -l \"#{link}\""

tm.brightWhite "\nThe following symlinks\n\n"

for k, v of lks
  tm.brightCyan path.join v.linkPath, v.linkName
  tm " -> "
  tm.brightGreen "#{v.target}\n"

tm.brightWhite "\nare going to be created. Are you sure? "; tm.white "[Y|n]\n"

tm.yesOrNo {yes: ['y', 'ENTER'], no: ['n']},
  (error, result) ->
    if result
      if not isRoot()
        tm.brightRed "Permission denied.\n"
        tm '\n'
        process.exit()
      for k, v of lks
        sh.ln '-sf', v.target, path.join v.linkPath, v.linkName
      process.exit()
    else
      process.exit()
