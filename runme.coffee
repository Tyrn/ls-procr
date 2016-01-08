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
    term.red "Aborted by user?\n"
    process.exit()


process.on 'uncaughtException',
  (err) ->
    tm.red.bold "Permission denied?\n"
    process.exit()


cmdName = 'pcf'
srvName = 'procrserver'


lsl = (path) ->
  sh.exec("ls -l \"#{path}\"")


cmd = sh.which cmdName
srv = sh.which srvName


lks = {
        cmd: {target: path.join(sh.pwd(), 'src/pcn.coffee'), link: "/usr/bin/#{cmdName}"}
        srv: {target: path.join(sh.pwd(), 'src/procrserver.py'), link: "/usr/bin/#{srvName}"}
      }


if cmd is lks.cmd.link or srv is lks.srv.link
  tm.bold "\nThe following entities on the system will be overwritten:\n\n"
if cmd
  lsl(cmd)
if srv
  lsl(srv)

tm.bold "\nThe following symlinks\n\n"

for k, v of lks
  tm.cyan.bold "#{v.link}"
  tm " -> "
  tm.green.bold "#{v.target}\n"

tm.bold "\nare going to be created. Are you sure? [Y|n]\n"

tm.yesOrNo {yes: ['y', 'ENTER'], no: ['n']},
  (error, result) ->
    if result
      if not isRoot()
        tm.red.bold "Permission denied.\n"
        tm '\n'
        process.exit()
      for k, v of lks
        sh.ln '-sf', v.target, v.link
      process.exit()
    else
      process.exit()
