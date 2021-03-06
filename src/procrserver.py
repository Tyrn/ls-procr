#!/usr/bin/python -u

###
#   Mutagen tag server
#

import sys

if sys.version_info < (3, 6, 0):
    sys.stderr.write("You need python 3.4 or later to run this script\n")
    sys.exit(1)

import time
import zmq
import mutagen
import json

port = "64107"

context = zmq.Context()
responder = context.socket(zmq.REP)
try:
    responder.bind(f"tcp://*:{port}")
except:
    sys.exit(0)

print(f'running on port {port}')

try:

    while True:
        #  Wait for next request from client
        message = responder.recv()
        jsn = message.decode('utf8')
        rq = json.loads(jsn)

        reply = '{"reply": "unknown"}'

        if rq['request'] == 'settags':
            audio = mutagen.File(rq['file'], easy=True)
            if audio:
                reply = '{{"reply": "settags", "file": "{}", "tags": {{"tracknumber": "{}"}}}}'
                reply = reply.format(rq['file'], rq['tags']['tracknumber'])
                for tag, value in rq['tags'].items():
                    audio[tag] = value
                audio.save()
        elif rq['request'] == 'serve':
            reply = '{"reply": "serve"}'

        #  Send reply back to client
        responder.send_string(reply)

except KeyboardInterrupt as e:
    sys.exit(e)
