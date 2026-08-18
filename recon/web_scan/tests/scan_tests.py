import unittest
import scan


class ScanTestCases(unittest.TestCase):
    def test_load_files(self):
        list_of_sites = scan.load_site_list('tests/testlist.txt')
        self.assertEquals(list_of_sites, ['http://google.com', 'https://gmail.com', 'https://donkie.com'])


if __name__ == '__main__':
    unittest.main()
