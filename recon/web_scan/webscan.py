#!/usr/bin/env python3
import argparse
import re

from selenium import webdriver
import os


def scan_sites(site_list):
    # 1. create a web driver instance
    driver = webdriver.Chrome()

    for site in site_list:
        print('Getting: ' + site)
        # 2. navigate to the website
        try:
            driver.get(site)

            # 3. save a screenshot of the current page
            path = os.getcwd() + '/screenshots/' + site.replace('/', '').replace(':', '_').replace('.', '_') + ".png"
            print('Writing:' + path)
            driver.save_screenshot(path)
        except:
            print('Ignoring: ' + site)

    # 4. close the web driver
    driver.quit()


def load_site_list(path):
    f = open(path, "r")
    sites = f.readlines()
    clean_list = []
    for site in sites:
        # We remove any invalid URIs
        if re.search(
                r'^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$',
                site):
            if not re.search(r'^(http:\/\/|https:\/\/)',site):
                site = 'https://'+site
            clean_list.append(site.rstrip('\n'))
    return clean_list


def main():
    parser = argparse.ArgumentParser(prog='Web Page Scanner', description='Takes a list of URIs then catures a screenshot of each',
                                     epilog='python3 scan.py <uri file>')
    parser.add_argument('path')

    args = parser.parse_args()
    site_list = load_site_list(args.path)
    scan_sites(site_list)


if __name__ == '__main__':
    main()
