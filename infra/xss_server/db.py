import sqlite3
import argparse
import os

def create_connection(db_file):
    conn = None
    try:
        conn = sqlite3.connect(db_file)
    except Exception as e:
        print(e)
    return conn

def create_db(conn):
    createContentTable="""CREATE TABLE IF NOT EXISTS content (
            id integer PRIMARY KEY,
            location text NOT NULL,
            content blob);"""

    createCookiesTable=""" CREATE TABLE IF NOT EXISTS cookies (
            id INTEGER PRIMARY KEY,
            cookie TEXT NOT NULL,
            value TEXT NOT NULL
        );"""

    createCredentialsTable=""" CREATE TABLE IF NOT EXISTS credentials(
            id INTEGER PRIMARY KEY,
            username TEXT NOT NULL,
            password TEXT,
            hash TEXT
        );"""
    try:
        c = conn.cursor()
        c.execute(createContentTable)
        c.execute(createCookiesTable)
        c.execute(createCredentialsTable)
    except Exception as e:
        print(e)

def insert_content(conn, newEntryData):
    createNewEntry='INSERT INTO content(location, content) VALUES (?,?)'
    try:
        c = conn.cursor()
        c.execute(createNewEntry, newEntryData)
    except Exception as e:
        print(e)

def get_locations(conn):
    selectAll='SELECT id, location FROM content'
    contentList = ('-'*150)+'\n'
    try:
        c = conn.cursor()
        c.execute(selectAll)

        rows = c.fetchall()

        return rows
    except Exception as e:
        print(e)

def get_content_by_id(conn, id_to_load):
    query='SELECT id, location, content from content where id=?'
    try:
        c = conn.cursor()
        c.execute(query, id_to_load)
        rows = c.fetchall()
        return rows
    except Exception as e:
        print(e)

def get_content(conn, queryParameters):
    query='SELECT id, location, content from content where location=?'
    print (queryParameters)
    try:
        c = conn.cursor()
        c.execute(query, queryParameters)
        rows = c.fetchall()

        return rows
    except Exception as e:
        print(e)

def replace_content(conn, updateValues):
    query='UPDATE content SET content = ? WHERE id = ?'

    try:
        c = conn.cursor()
        c.execute(query, updateValues)

        conn.commit()
        return 'Updated %s' % updateValues[1]
    except Exception as e:
        print(e)

def delete_content(conn, idToDelete):
    query='DELETE FROM content WHERE id = ?'

    try:
        c = conn.cursor()
        c.execute(query, idToDelete)

        conn.commit()
        return 'Deleted %s' % idToDelete
    except Exception as e:
        print(e)

if __name__ == "__main__":
    database = r"sqlite.db"
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--create','-c', help='Create Database', action='store_true')
    group.add_argument('--insert','-i', help='Insert Content', action='store_true')
    group.add_argument('--delete','-d', help='Delete Content', action='store_true')
    group.add_argument('--replace','-r', help='Replace Content', action='store_true')
    group.add_argument('--get','-g', help='Get Content', action='store_true')
    group.add_argument('--getLocations','-l', help='Get all Locations', action='store_true')

    parser.add_argument('--location','-L')
    parser.add_argument('--content','-C')
    parser.add_argument('--id','-I', default=-1, type=int)
    args = parser.parse_args()

    conn = create_connection(database)

    if (args.create):
        print("[+] Creating Database")
        create_db(conn)
    elif (args.insert):
        if(args.location is None or args.content is None):
            parser.error("--insert requires --location, --content.")
        else:
            print("[+] Inserting Data")
            insert_content(conn, (args.location, args.content))
            conn.commit()
    elif (args.get):
        if args.id != -1:
            print("[+] Getting Content")
            print(get_content_by_id(conn, (args.id,)))
        elif args.location is not None:
            print("[+] Getting Content")
            print(get_content(conn, (args.location,)))
        else:
            parser.error("--get requires --location or --id.")
    elif (args.delete):
        if(args.id == -1):
            parser.error("--replace requires --id.")
        else:
            print("[+] Deleting Content")
            print(delete_content(conn, (args.id,)))
    elif (args.replace):
        if(args.content is None or args.id == -1):
            parser.error("--replace requires --id and --content.")
        else:
            print("[+] Replacing Content")
            print(replace_content(conn, ( args.content, args.id,)))
    if (args.getLocations):
        print("[+] Getting All Locations")
        print(get_locations(conn))
