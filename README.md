# somikroarc
A Bash script solution for generating verifiable archives of entire directory trees which lster can be audited to verify integrity of archived files

Usage: /home/devel/bin/somikroarc.sh [-c] [-a] [-h] [-V] [-L] [-C creationMode] [-A auditingMode] [-H hashfileMode] [-t testmode] [-v loglevel] directory|zip-archive
   somikroarc.sh creates or audits an archive of a directory tree with integrity verification
  -c: create a hash value file and/or zip-archive from given directory
  -C: creationMode 1=archive only, 2=hashfile and archive, 3=hashfile and archive verified, 4 hashfile only
  -a: audit the integrity of the given directory or zip-archive
  -A: auditingMode 1=archive by crc, 2=archive by hashfile, 3=directory by hashfile
  -v: loglevel of messages 
  -V: list version of the program
  -L: full logging in logfile
  -H: hashfileMode 1=out-of-dir , 2=in dir, negative nr produces a hidden hash values file
  -s: hash algorithms out of sha256 sha1 md5
  -t: running in test mode - testmode is a number
  -h: Display this help message
	Example : somikroarc.sh -c -C 3 mydir_to_archive
	Example : somikroarc.sh -a -A 2 mydir_to_archive.zip
somikroarc.sh by somikro, Version 1.15, V1.15 2025-11-25 20:38

