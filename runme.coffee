#!/usr/bin/env coffee

require 'shelljs/global'
term = require('terminal-kit').terminal

term.blue.bold 'Hello!\n'


# term.green ls '-A', '.'