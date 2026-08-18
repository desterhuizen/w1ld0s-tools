# PHP Dangerous Functions Reference

This document catalogs PHP functions that can create security vulnerabilities when used without proper input validation.

## 1. Command Execution Functions
Functions that allow execution of system commands - critical when user input reaches these:

```php
exec             // Returns last line of command output
passthru         // Passes command output directly to browser
system           // Passes command output to browser and returns last line
shell_exec       // Returns complete command output
`...` (backticks) // Same as shell_exec()
popen            // Opens read/write pipe to command process
proc_open        // Similar to popen() but with greater control
pcntl_exec       // Executes a program
```

## 2. PHP Code Execution Functions
Functions that directly execute PHP code - extremely dangerous when user input is involved:

```php
eval()           // Executes string as PHP code
assert()         // Acts like eval() when string is passed
preg_replace('/.*/e', ...) // 'e' modifier executes matched code
create_function() // Creates anonymous function from string
include()        // Includes and evaluates file
include_once()   // Includes and evaluates file if not already included
require()        // Same as include() but produces fatal error on failure
require_once()   // Same as include_once() but produces fatal error on failure

// Dynamic function calls - also dangerous:
$_GET['func_name']($_GET['argument']);
$func = new ReflectionFunction($_GET['func_name']); 
$func->invoke(); // or $func->invokeArgs(array());
```

## 3. Callback Functions
Functions that accept callbacks as parameters - can be exploited if user input reaches the callback parameter:

```php
// Format: 'function_name' => position(s) of callback parameter
'ob_start'                   =>  0,
'array_diff_uassoc'          => -1,
'array_diff_ukey'            => -1,
'array_filter'               =>  1,
'array_intersect_uassoc'     => -1,
'array_intersect_ukey'       => -1,
'array_map'                  =>  0,
'array_reduce'               =>  1,
'array_udiff_assoc'          => -1,
'array_udiff_uassoc'         => array(-1, -2),
'array_udiff'                => -1,
'array_uintersect_assoc'     => -1,
'array_uintersect_uassoc'    => array(-1, -2),
'array_uintersect'           => -1,
'array_walk_recursive'       =>  1,
'array_walk'                 =>  1,
'assert_options'             =>  1,
'uasort'                     =>  1,
'uksort'                     =>  1,
'usort'                      =>  1,
'preg_replace_callback'      =>  1,
'spl_autoload_register'      =>  0,
'iterator_apply'             =>  1,
'call_user_func'             =>  0,
'call_user_func_array'       =>  0,
'register_shutdown_function' =>  0,
'register_tick_function'     =>  0,
'set_error_handler'          =>  0,
'set_exception_handler'      =>  0,
'session_set_save_handler'   => array(0, 1, 2, 3, 4, 5),
'sqlite_create_aggregate'    => array(2, 3),
'sqlite_create_function'     =>  2,
```

## 4. Information Disclosure Functions
These functions can reveal sensitive system information if their output is exposed to attackers:

```php
phpinfo()        // Reveals detailed PHP configuration
posix_mkfifo     // Creates a FIFO special file
posix_getlogin   // Returns login name
posix_ttyname    // Returns terminal device name
getenv           // Gets environment variable value
get_current_user // Gets current PHP script owner name
proc_get_status  // Gets information about a process opened by proc_open()
get_cfg_var      // Gets PHP configuration option value
disk_free_space  // Returns available space on filesystem
disk_total_space // Returns total size of filesystem
diskfreespace    // Alias of disk_free_space()
getcwd           // Gets current working directory
getlastmo        // Gets time of last page modification
getmygid         // Gets PHP script owner's GID
getmyinode       // Gets inode of current script
getmypid         // Gets PHP process ID
getmyuid         // Gets PHP script owner's UID
```

## 5. Variable Handling & Environmental Functions
These can be abused for various attacks including variable overwrites and injection:

```php
extract          // Creates variables from array elements - vulnerable to register_globals attacks
parse_str        // Parses string as if it were query string parameters - like extract() with one argument
putenv           // Sets value of an environment variable
ini_set          // Sets value of a PHP configuration option
mail             // Vulnerable to CRLF injection in 3rd parameter (headers) - email header injection
header           // Can allow response splitting attacks if not followed by exit()

// Process control functions
proc_nice        // Changes process priority
proc_terminate   // Kills a process opened by proc_open()
proc_close       // Closes a process opened by proc_open() and returns exit code
pfsockopen       // Opens persistent socket connection
fsockopen        // Opens socket connection
apache_child_terminate // Terminates Apache process
posix_kill       // Sends signal to a process
posix_setpgid    // Sets process group ID for job control
posix_setsid     // Makes current process a session leader
posix_setuid     // Sets real user ID of current process
```

## 6. Filesystem Functions
Functions that read or write to the filesystem - dangerous if paths contain user input:

### File Writing Functions
```php
// File/directory creation and modification
chgrp            // Changes file group
chmod            // Changes file permissions
chown            // Changes file owner
copy             // Copies file
file_put_contents // Writes data to a file
lchgrp           // Changes symlink group
lchown           // Changes symlink owner
link             // Creates hard link
mkdir            // Makes directory
move_uploaded_file // Moves uploaded file to new location
rename           // Renames file or directory
rmdir            // Removes directory
symlink          // Creates symbolic link
tempnam          // Creates temporary file with unique name
touch            // Sets file access and modification time
unlink           // Deletes file

// Image functions with file path parameters
imagepng         // Outputs PNG image to file (2nd parameter is path)
imagewbmp        // Outputs WBMP image to file (2nd parameter is path)
image2wbmp       // Outputs WBMP image to file (2nd parameter is path)
imagejpeg        // Outputs JPEG image to file (2nd parameter is path)
imagexbm         // Outputs XBM image to file (2nd parameter is path)
imagegif         // Outputs GIF image to file (2nd parameter is path)
imagegd          // Outputs GD image to file (2nd parameter is path)
imagegd2         // Outputs GD2 image to file (2nd parameter is path)

// Other file operations
iptcembed        // Embeds binary IPTC data into JPEG image
ftp_get          // Downloads file from FTP server
ftp_nb_get       // Downloads file from FTP server (non-blocking)
```

### File Reading Functions
```php
file_exists      // Checks if file/directory exists
file_get_contents // Reads entire file into string
file             // Reads file into array
fileatime        // Gets last access time of file
filectime        // Gets inode change time of file
filegroup        // Gets file group
fileinode        // Gets file inode
filemtime        // Gets file modification time
fileowner        // Gets file owner
fileperms        // Gets file permissions
filesize         // Gets file size
filetype         // Gets file type
glob             // Finds pathnames matching pattern
is_dir           // Tells if path is directory
is_executable    // Tells if file is executable
is_file          // Tells if path is regular file
is_link          // Tells if path is symbolic link
is_readable      // Tells if file is readable
is_uploaded_file // Tells if file was uploaded via HTTP POST
is_writable      // Tells if file is writable
is_writeable     // Alias of is_writable()
linkinfo         // Gets information about link
lstat            // Gives information about file or symbolic link
```

### File Handlers
```php
fopen            // Opens file or URL
tmpfile          // Creates temporary file
bzopen           // Opens bzip2 compressed file
gzopen           // Opens gzip compressed file
SplFileObject->__construct // Creates file object
```
