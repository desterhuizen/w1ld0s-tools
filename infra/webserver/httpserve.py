#!/usr/bin/env python3 

from flask import Flask, request, send_from_directory
from flask_cors import CORS
import urllib.parse
import base64
import argparse
import os
from colorama import Fore


def urlencode(str):
  return urllib.parse.quote(str)

def urldecode(str):
  return urllib.parse.unquote(str)
    
parser = argparse.ArgumentParser(description='Callback Webserver')
parser.add_argument('port', help='The port you want to bind the web server too', default='8080')
parser.add_argument('-s','--ssl', help='Serve ssl, requires ssl_key and ssl_cert', action='store_true', default=False)
parser.add_argument('-sk','--ssl_key', help='SSL key to use for the HTTPS server', default='key.pem')
parser.add_argument('-sc','--ssl_cert', help='SSL certificate to use for the HTTPS server', default='cert.pem')
parser.add_argument('-b','--bind', help='IP Address to bind too', default='0.0.0.0')
parser.add_argument('-d', '--directory', help='Directory to serve files from default is current working directory')


args = parser.parse_args()

cwd = os.getcwd()
ssl_context = None

if (args.ssl):
    ssl_context = (args.ssl_key, args.ssl_cert)
if (args.directory):
    cwd = args.directory

app = Flask(__name__)
CORS(app)

@app.route('/<path:filename>')
def statics(filename):
    print (Fore.GREEN + '* Got %s' % filename)
    return send_from_directory(cwd, filename)


# Receive a POST with creds
@app.route('/msg', methods=['POST','GET'])
def creds():
    print (Fore.RESET+'='*100)
    print (Fore.GREEN+'%s from : %s' % ( request.method, request.remote_addr))
    print (Fore.RESET+'- headers ' + ('-' *90))
    for key,value in request.headers.items():
        print (Fore.GREEN+'%s: %s'% (key, value))
    if request.method == 'POST':
        print (Fore.GREEN+'- data decoded ' + ('-' *85))
        data = {}
        content_type = request.headers.get('Content-Type')
        if content_type == 'application/json':
            data = request.get_json()
        else:
            data = request.form

        if data.get('data'):
            try:
                print (Fore.GREEN+str(urldecode(data.get('data'))))
            except (ValueError, TypeError):
                pass
            try:
                print (Fore.GREEN+str(base64.b64decode(data.get('data'))))
            except (ValueError, TypeError):
                pass

        print (Fore.RESET+'- data ' + ('-' *93))
        for key,value in data.items():
            print (Fore.GREEN+'%s: %s'% (key, value))

    if request.args:
        print (Fore.RESET+'- query ' + ('-' *92))
        data = request.args
        for key, value in data.items():
            print (Fore.GREEN+'%s: %s'% (key, value))

        if data.get('data'):
            print (Fore.RESET+'- query decoded' + ('-' *84))
            try:
                print (Fore.GREEN+str(urldecode(data.get('data'))))
            except (ValueError, TypeError):
                pass
            try:
                print (Fore.GREEN+str(base64.b64decode(data.get('data'))))
            except (ValueError, TypeError):
                pass
        if data.get('update'):
            print (Fore.RESET+'- update ' + ('-' *91))
            print(Fore.GREEN+'Update: %s' % data.get('update'))
             
    print (Fore.RESET + ('-'*100))
    print (Fore.RESET + ('='*100))
    return "ok"


app.run(host=args.bind, port=args.port, ssl_context=ssl_context)



