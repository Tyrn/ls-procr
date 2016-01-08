#!/usr/bin/python -u

###
#   Mutagen tag server
#

import sys

if sys.version_info < (3, 4, 0):
    sys.stderr.write("You need python 3.4 or later to run this script\n")
    sys.exit(1)

import time
import zmq
import mutagen
import json

context = zmq.Context()
socket = context.socket(zmq.REP)
try:
    socket.bind("tcp://*:64107")
except:
    sys.exit(0)

try:

    while True:
        #  Wait for next request from client
        message = socket.recv()
        jsn = message.decode('utf8')
        rq = json.loads(jsn)

        reply = '{"request": "unknown"}'

        if rq['request'] == 'settags':
            audio = mutagen.File(rq['file'], easy=True)
            if audio:
                reply = '{{"request": "settags", "tags": {{"tracknumber": "{}"}}}}'
                reply = reply.format(rq['tags']['tracknumber'])
                for tag, value in rq['tags'].items():
                    audio[tag] = value
                audio.save()
        #  Send reply back to client
        socket.send_string(reply)

except KeyboardInterrupt as e:
    sys.exit(e)
