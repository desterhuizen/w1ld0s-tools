import os
from db import create_connection, get_content_by_id, get_locations

database = r"sqlite.db"
contentDir = os.getcwd() + "/content"


def write_to_file(url, content):
    try: 
        fileName = url.replace('https://','')
        if not fileName.endswith(".html"):
            fileName = fileName + ".html"
        fullname = os.path.join(contentDir, fileName)
        path, basename = os.path.split(fullname)
        if not os.path.exists(path):
            os.makedirs(path)
        with open(fullname, 'w') as f:
            f.write(content)
    except:
        print('error writing: '+url)

if __name__ == '__main__':
    conn = create_connection(database)
    locations = get_locations(conn)
    for l in locations:
        content = get_content_by_id(conn, (l[0],))
        if content is not None:
            write_to_file(l[1], content[0][2])
