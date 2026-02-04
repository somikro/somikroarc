# somikroarc

**A comprehensive shell-based archiving and integrity verification tool for Linux**

somikroarc is a powerful Bash script that creates integrity-verifiable archives of entire filesystem trees with multiple generation and auditing modes. It combines the robustness of cryptographic hash verification with flexible archiving options to ensure data integrity throughout the archive lifecycle.

## Features

- 🔐 **Cryptographic Integrity Verification** - Generate and verify hash codes for directory trees using SHA-256, SHA-1, or MD5 algorithms
- 📦 **Flexible Archive Creation** - Create bzip2-compressed ZIP archives with optional integrated hash verification
- ✅ **Multiple Audit Modes** - Verify directory or archive integrity using CRC checks or cryptographic hashes
- 🔄 **Combined Verification Mode** - Automatically verify archives immediately after creation for error-free operation
- 🖥️ **GUI Integration** - Desktop integration with YAD-based graphical interface and custom styling
- 📊 **Comprehensive Logging** - Detailed logging with tabular output for tracking operations
- ⚡ **RAM-based Operations** - Utilizes tmpfs/RAM disk for fast archive extraction during auditing
- ⚙️ **Configurable** - Extensive configuration options via INI-style config file

## Prerequisites

somikroarc requires the following commands to be available on your system:

- `zip` - Archive creation
- `unzip` - Archive extraction
- `hashdeep` - Cryptographic hash generation and verification
- `yad` - YAD (Yet Another Dialog) version 14.1+ for GUI
- `bzip2` - Compression

On Debian/Ubuntu systems, install dependencies with:

```bash
sudo apt install zip unzip hashdeep yad bzip2
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/somikro/somikroarc.git
cd somikroarc
```

2. Make the script executable:
```bash
chmod +x somikroarc.sh
```

3. (Optional) Copy to your local bin directory:
```bash
mkdir -p ~/bin
cp somikroarc.sh ~/bin/
```

4. (Optional) Install desktop integration files:
```bash
mkdir -p ~/.config/somikro/icons
cp somikro.conf ~/.config/somikro/
cp icons/* ~/.config/somikro/icons/
cp somikroarc.desktop ~/.local/share/applications/
cp somikroarc_audit.desktop ~/.local/share/applications/
```

5. Configure the tool by editing `~/.config/somikro/somikro.conf` and adjusting paths to match your system (replace `<user>` placeholders with your username).

## Usage

### Basic Syntax

```bash
./somikroarc.sh [-c] [-a] [-h] [-V] [-L] [-C creationMode] [-A auditingMode] [-H hashfileMode] [-t testmode] [-v loglevel] directory|zip-archive
```

### Command-Line Options

#### Main Operations
- **-c** - Create mode: generate hash file and/or zip archive from given directory
- **-a** - Audit mode: verify the integrity of the given directory or zip archive

#### Mode Parameters
- **-C creationMode** - Specify creation behavior:
  - `1` = Create archive only (no hash file)
  - `2` = Create hash file and archive
  - `3` = Create hash file and archive, then verify (default, recommended)
  - `4` = Create hash file only (no archive)

- **-A auditingMode** - Specify auditing method:
  - `1` = Audit archive using CRC checks
  - `2` = Audit archive using hash file verification
  - `3` = Audit directory using hash file verification (default)

- **-H hashfileMode** - Hash file location:
  - `1` = Place hash file outside directory
  - `2` = Place hash file inside directory (default)
  - Negative values (e.g., `-2`) = Create hidden hash file (e.g., `.hashfile`)

#### Additional Options
- **-s** - Hash algorithm: `sha256`, `sha1`, or `md5` (default: `sha1`)
- **-v** - Verbosity level for log messages (0-3)
- **-V** - Display version information
- **-L** - Enable full logging to logfile
- **-t** - Test mode (for development/debugging)
- **-h** - Display help message

### Examples

#### Create an archive with verification
Create a hash file and archive, then automatically verify the archive:
```bash
somikroarc.sh -c -C 3 /path/to/mydir
```
This creates `mydir.zip` and verifies its integrity.

#### Create hash file only
Generate only a cryptographic hash file for a directory:
```bash
somikroarc.sh -c -C 4 /path/to/mydir
```

#### Audit an existing archive
Verify the integrity of an archive using its embedded hash file:
```bash
somikroarc.sh -a -A 2 /path/to/mydir.zip
```

#### Audit a directory
Verify a directory's integrity against its hash file:
```bash
somikroarc.sh -a -A 3 /path/to/mydir
```

#### Use SHA-256 hashing
Create an archive with SHA-256 hash verification:
```bash
somikroarc.sh -c -C 3 -s sha256 /path/to/mydir
```

#### Process multiple directories via GUI
Launch with multiple directories for batch processing:
```bash
somikroarc.sh -c -C 3 /path/to/dir1 /path/to/dir2 /path/to/dir3
```

## Configuration

The configuration file is located at `~/.config/somikro/somikro.conf` and uses INI-style formatting. Key configuration options include:

```ini
[somikroarc]
# Log file location
logloc = "/home/username/.logs/somikro"

# Temporary directory for operations
tmpdir = "/home/username/tmp"

# RAM disk settings for fast auditing
ramdir = "/tmp/ramdir"
ramdirSize = "1024M"
ramonly = 1

# Default modes
hm = 2          # hashfileMode
am = 3          # auditingMode  
cm = 3          # creationMode

# Hash algorithm
halg = "sha1"   # Options: sha256, sha1, md5
```

**Note:** Shell expansion is not supported in the config file. Use absolute paths only (no `$HOME` or `~`).

## How It Works

### Archive Creation Process
1. Scans the specified directory tree
2. Generates cryptographic hashes for all files using `hashdeep`
3. Creates a hash file containing file paths and hash values
4. Creates a bzip2-compressed ZIP archive including the hash file
5. (Optional) Automatically extracts and verifies the archive to ensure integrity

### Audit Process
1. Extracts the archive to a temporary location (preferably RAM disk for speed)
2. Reads the embedded hash file
3. Recalculates hashes for all extracted files
4. Compares calculated hashes against stored values
5. Reports any mismatches or corrupted files

### RAM Disk Usage
For optimal performance during auditing, somikroarc uses RAM-based temporary storage:
1. First checks for `/dev/shm` (shared memory tmpfs)
2. If unavailable or insufficient, creates a tmpfs mount at `ramdir` location
3. Falls back to disk-based `tmpdir` if `ramonly` is set to 0

## Desktop Integration

The project includes `.desktop` files for integration with Linux desktop environments:

- **somikroarc.desktop** - Launch archive creation from file manager
- **somikroarc_audit.desktop** - Launch audit operations from file manager

These allow right-click context menu integration for easy access to somikroarc functionality.

## Logging

somikroarc provides comprehensive logging:

- **Console output** - Real-time progress information (file descriptor 4)
- **Log files** - Detailed operation logs in `~/.logs/somikro/`
- **Tabular logs** - Machine-readable tab-separated logs for analysis (`somikroarc.tab`)

Enable full logging with the `-L` flag.

## Project Structure

```
somikroarc/
├── somikroarc.sh              # Main script
├── ini.class.sh               # INI file parser library
├── somikro.conf               # Configuration template
├── somikroarc.css             # GUI styling
├── somikroarc.desktop         # Desktop entry for creation
├── somikroarc_audit.desktop   # Desktop entry for auditing
├── icons/                     # GUI icons
│   ├── somikro.png
│   ├── somikro_audit.png
│   ├── Done.png
│   ├── Error.png
│   └── Delete.png
├── LICENSE                    # GNU GPL 3.0
└── README.md                  # This file
```

## License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

## Credits and Acknowledgments

somikroarc builds upon excellent open-source software:

- **INI Parser** - [bash_iniparser](https://github.com/axelhahn/bash_iniparser) by Axel Hahn (GNU GPL 3.0)
- **YAD** - [Yet Another Dialog](https://github.com/v1cont/yad) by Victor Ananjevsky (v14.1+)
- **Core Tools** - zip, unzip, hashdeep, bzip2 from Debian repositories

Many thanks to all contributors to these projects!

## Version History

**Current Version:** 1.15  
**Release Date:** 2025-11-25 20:38  
**Author:** somikro

## Support and Contributing

For bug reports, feature requests, or contributions, please visit the project repository or contact the author.

---

**somikroarc** - Ensuring data integrity through cryptographic verification and reliable archiving.
