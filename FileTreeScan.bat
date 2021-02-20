@echo off

echo ______________________________________________________________________
echo Script name: FileTreeScan.bat
echo Author: Johan Briantais
echo Date: 20/02/2021
echo Source repository:
echo  https://gitlab.worldline.tech/johan.briantais/file-management-tools
echo ______________________________________________________________________
echo This program is free software: you can redistribute it and/or modify
echo it under the terms of the GNU General Public License as published by
echo the Free Software Foundation, either version 3 of the License, or
echo (at your option) any later version.
echo ______________________________________________________________________
echo This program is distributed in the hope that it will be useful,
echo but WITHOUT ANY WARRANTY; without even the implied warranty of
echo MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
echo GNU General Public License for more details.
echo ______________________________________________________________________
echo You should have received a copy of the GNU General Public License
echo along with this program.  If not, see https://www.gnu.org/licenses/.
echo ______________________________________________________________________

powershell.exe -File powershell/Invoke-FileTreeScan.ps1
