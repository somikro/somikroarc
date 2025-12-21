# somikroarc
A shell script to add hash codes to directory trees for integrity verification, creating zip archives including that hash codes, providing verification of data integrity for files in directories and archives created. A combined mode is provided where an archive is automatically fully verified after creation to ensure error free archive creation


## Usage

```bash
./somikroarc.sh [-c] [-a] [-h] [-V] [-L] [-C creationMode] [-A auditingMode] [-H hashfileMode] [-t testmode] [-v loglevel] directory|zip-archive
```

somikroarc.sh creates or audits an archive of a directory tree with integrity verification

### Options

- **-c**: create a hash value file and/or zip-archive from given directory
- **-C**: creationMode 1=archive only, 2=hashfile and archive, 3=hashfile and archive verified, 4 hashfile only
- **-a**: audit the integrity of the given directory or zip-archive
- **-A**: auditingMode 1=archive by crc, 2=archive by hashfile, 3=directory by hashfile
- **-v**: loglevel of messages
- **-V**: list version of the program
- **-L**: full logging in logfile
- **-H**: hashfileMode 1=out-of-dir , 2=in dir, negative nr produces a hidden hash values file
- **-s**: hash algorithms out of sha256 sha1 md5
- **-t**: running in test mode - testmode is a number
- **-h**: Display this help message

### Examples

```bash
somikroarc.sh -c -C 3 mydir_to_archive
somikroarc.sh -a -A 2 mydir_to_archive.zip
```

---
*somikroarc.sh by somikro, Version 1.15, 2025-11-25 20:38*
