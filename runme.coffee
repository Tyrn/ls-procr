#!/usr/bin/env coffee

###
#
# Unofficial setup script. Don't use if in doubt.
# Run (after git clone) in the project directory as superuser.
#
###

sh = require '/usr/lib/node_modules/shelljs'
tm = require('terminal-kit').terminal
path = require 'path'

process.on 'SIGINT',
  ->
    term.red "Aborted by user\n"
    process.exit()


lsl = (path) ->
  sh.exec("ls -l \"#{path}\"")


cmd = sh.which 'pcf'
srv = sh.which 'procrserver'

lks = {
        cmd: {target: path.join(sh.pwd(), 'src/pcn.coffee'), link: '/usr/bin/pcf'}
        srv: {target: path.join(sh.pwd(), 'src/procrserver.py'), link: '/usr/bin/procrserver'}
      }

if cmd is lks.cmd.link or srv is lks.srv.link
  tm.bold "The following entities on the system will be overwritten:\n"
if cmd
  lsl(cmd)
if srv
  lsl(srv)

tm.bold "The following symlinks\n"

for k, v of lks
  tm.cyan.bold "#{v.link}"
  tm " -> "
  tm.green.bold "#{v.target}\n"

tm.bold "are going to be created. Are you sure? [Y|n]\n"

tm.yesOrNo {yes: ['y', 'ENTER'], no: ['n']},
  (error, result) ->
    if result
      for k, v of lks
        sh.ln '-sf', v.target, v.link
      process.exit()
    else
      process.exit()
