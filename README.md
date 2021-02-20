# File Management Tools (BETA)

This project provides various tools to manage files.

---

## Windows PowerShell scripts

### Requirements

- Windows 7 or higher
- Windows PowerShell version 5.1 or higher

### Installation

1. Download [file-management-tools-master.zip](../../archive/master/file-management-tools-master.zip)
1. Extract the content in a local directory of your choice

### FileTreeScan

Scans a directory and all its subdirectories (recursively). It can produces two reports:
- FilesAndDirectories: list all files and directories, with details of each one (name, type, size, number of children, dates, parent directory, full path)
- DuplicateFiles: calculate a hash of each file and list all duplicates
The reports can be either saved to CSV files or displayed on screen.

Usage:
1. Double-click on `FileTreeScan.bat`
1. Follow instructions (a PowerShell console should stay open until the process is finished)
1. Open the new file `FileTreeScanReport.csv` in Excel

---

by Johan Briantais

This program is free software: you can redistribute it and/or modify
it under the terms of the [GNU General Public License](LICENSE) as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see [https://www.gnu.org/licenses/](https://www.gnu.org/licenses/).

![License](images/license.png)
