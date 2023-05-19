from flask import Flask, request, session, redirect, url_for, render_template
from flask_simpleldap import LDAP
import os

app = Flask(__name__)
app.secret_key = os.urandom(24)
app.config['LDAP_HOST'] = 'localhost'
app.config['LDAP_BASE_DN'] = 'dc=gazi,dc=edu,dc=tr'
app.config['LDAP_USERNAME'] = 'cn=admin,dc=gazi,dc=edu,dc=tr'
app.config['LDAP_PASSWORD'] = 'password'
app.config['LDAP_OBJECTS_DN'] = 'dn'
app.config['LDAP_OPENLDAP'] = True
app.config['LDAP_USER_OBJECT_FILTER'] = '(&(objectclass=inetOrgPerson)(uid=%s))'

ldap = LDAP(app)

@app.route('/')
def index():
    if 'username' not in session:
        return redirect(url_for('login'))
    return 'Welcome, %s!' % session['username']

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        test = ldap.bind_user(username, password)
        if test is None:
            return 'Invalid credentials'
        else:
            session['username'] = username
            return redirect(url_for('index'))
    return render_template('login.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0')
