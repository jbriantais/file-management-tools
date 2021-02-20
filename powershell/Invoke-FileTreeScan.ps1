########################################################################
# Script name: Invoke-FileTreeScan.ps1
# Author: Johan Briantais
# Date: 20/02/2021
# Source repository:
#  https://gitlab.worldline.tech/johan.briantais/file-management-tools
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
########################################################################

using namespace System.Windows.Forms

# Check the directory to scan
function Test-ScanDir {
	param (
		[string]$ScanDir
	)
	if ($ScanDir -eq "") {
		throw "No directory selected"
	}
	if (-not (Test-Path $ScanDir -PathType Container)) {
		throw "Invalid directory [$ScanDir]"
	}
	Write-Host "Selected directory to scan: $ScanDir"
	return $ScanDir
}

# Select the reports to generate
function Read-Options {
	# Design of the dialog to select reports to generate
	[xml]$SelectReportsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Select reports" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" UseLayoutRounding="True"
		SizeToContent="WidthAndHeight" TextOptions.TextFormattingMode="Display">
	<StackPanel Margin="10,7,10,7">
		<StackPanel.Resources>
			<Style TargetType="{x:Type TextBlock}">
				<Setter Property="Margin" Value="7,5,7,5"/>
				<Setter Property="TextWrapping" Value="Wrap"/>
			</Style>
			<Style TargetType="{x:Type CheckBox}">
				<Setter Property="Margin" Value="7,5,7,5"/>
			</Style>
			<Style TargetType="{x:Type RadioButton}">
				<Setter Property="Margin" Value="7,5,7,5"/>
			</Style>
			<Style TargetType="{x:Type Button}">
				<Setter Property="Margin" Value="7,5,7,5"/>
				<Setter Property="Padding" Value="20,3,20,3"/>
			</Style>
		</StackPanel.Resources>
		<TextBlock>Which reports do you want to generate?</TextBlock>
		<CheckBox Name="FilesAndDirectories">List and details of files and directories</CheckBox>
		<CheckBox Name="DuplicateFiles">Duplicate files *</CheckBox>
		<TextBlock>* Warning: depending on the volume, process may last hours and generate high network traffic.
			<LineBreak/>If runing on a network file system, it may be preferable to do some cleanup of large files first.</TextBlock>
		<TextBlock>What do you want to do with these reports?</TextBlock>
		<UniformGrid HorizontalAlignment="Left" Rows="1" Columns="2">
			<RadioButton Name = "Save" GroupName = "Action" IsChecked="True">Save to CSV files</RadioButton>
			<RadioButton Name = "Display" GroupName = "Action">Display on screen</RadioButton>
		</UniformGrid>
		<UniformGrid HorizontalAlignment="Right" Rows="1" Columns="2">
			<Button Name="OKButton" IsDefault="True">OK</Button>
			<Button IsCancel="True">Cancel</Button>
		</UniformGrid>
	</StackPanel>
</Window>
"@
	# Build the SelectReportsWindow
	[System.Xml.XmlNodeReader]$SelectReportsReader = New-Object System.Xml.XmlNodeReader $SelectReportsXaml
	Add-Type -AssemblyName PresentationFramework
	[System.Windows.Window]$SelectReportsWindow = [Windows.Markup.XamlReader]::Load($SelectReportsReader)
	# Add an event for OKButton
	$SelectReportsWindow.FindName("OKButton").add_click({
		$SelectReportsWindow.DialogResult = $true
	})
	# Display the dialog to select reports
	if (!$SelectReportsWindow.Showdialog()) {
		throw "Process canceled"
	}
	# Get options values from the dialog
	[pscustomobject] $SelectedOptions = @{
		Reports = foreach ($Report in @("FilesAndDirectories","DuplicateFiles")) {
			if ($SelectReportsWindow.FindName($Report).IsChecked) {
				$Report
			}
		}
		Save = $SelectReportsWindow.FindName("Save").IsChecked
	}
	# Check options values
	if (!$SelectedOptions.Reports) {
		throw "No report selected"
	}
	Write-Host "Selected reports: " $SelectedOptions.Reports
	Write-Host "Save to CSV files: " $SelectedOptions.Save
	return $SelectedOptions
}

# Get the report path
function Get-ReportPath {
	param (
		[string]$Report
	)
	return "$ScanDir\FileTreeScanReport-$Report.csv"
}

# Check the report path
function Test-ReportPath {
	param (
		[string]$Report
	)
	[string]$ReportPath = Get-ReportPath $Report
	if (Test-Path $ReportPath -PathType Container) {
		throw "Output report path [$ReportPath] is a directory"
	}
	[string]$BoxTitle = "Confirmation"
	if (Test-Path $ReportPath -PathType Leaf) {
		[string]$BoxMessage = "Output report file already exists [$ReportPath]. Do you want to replace it or to cancel the process?"
		[MessageBoxIcon]$BoxIcon = [MessageBoxIcon]::Warning
	} else {
		[string]$BoxMessage = "Output report file will be generated in [$ReportPath]. Do you want to proceed?"
		[MessageBoxIcon]$BoxIcon = [MessageBoxIcon]::Question
	}
	if ([MessageBox]::Show($BoxMessage,$BoxTitle,[MessageBoxButtons]::OKCancel,$BoxIcon) -eq [DialogResult]::Cancel) {
		throw "Process canceled"
	}
}

# Run the report: list and details of files and directories
function Get-FilesAndDirectories {
	param (
		[string]$ScanDir,
		[string]$ReportPath
	)
	Get-ChildItem -Recurse -Path $ScanDir | Where-Object FullName -ne $ReportPath | ForEach-Object {
		return [pscustomobject]@{
			Name = $_.Name
			Type = if ($_.PSIsContainer) {"<DIR>"} ElseIf ($_.Extension) {$_.Extension} Else {"<UNDEF>"}
			SizeInBytes = if ($_.PSIsContainer) {"<N/A>"} Else {$_.Length}
			NumberOfChildren = if ($_.PSIsContainer) {$_.GetFileSystemInfos().Count} Else {"<N/A>"}
			CreationTime = $_.CreationTime
			LastAccessTime = $_.LastAccessTime
			LastWriteTime = $_.LastWriteTime
			ParentDirectory = if ($_.PSIsContainer) {$_.Parent.FullName} Else {$_.Directory}
			FullPath = $_.FullName
		}
	}
}

# Run the report: duplicate files
function Get-DuplicateFiles {
	param (
		[string]$ScanDir,
		[string]$ReportPath
	)
	Get-ChildItem -Recurse -File -Path $ScanDir | Where-Object FullName -ne $ReportPath | Get-FileHash | Group-Object -Property Hash | Where-Object Count -gt 1 | ForEach-Object {
		foreach ($Duplicate in $_.Group) {
			[pscustomobject]@{
				FullPath = $Duplicate.Path
				Hash = $Duplicate.Hash
			}
		}
	}
}

# Main execution
try {
	# Display initial dialogs
	[string]$ScanDir = & $PSScriptRoot\Read-FolderBrowserDialog.ps1
	Test-ScanDir $ScanDir
	[pscustomobject] $SelectedOptions = Read-Options
	# Check the report paths
	if ($SelectedOptions.Save) {
		foreach ($Report in $SelectedOptions.Reports) {
			Test-ReportPath $Report
		}
	}
	# Run the reports
	Write-Host "Please wait until process has finished..."
	foreach ($Report in $SelectedOptions.Reports) {
		Write-Host "Generating $Report..."
		if ($SelectedOptions.Save) {
			[string]$ReportPath = Get-ReportPath $Report
			& Get-$Report $ScanDir $ReportPath | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | Out-File $ReportPath
		} else {
			& Get-$Report $ScanDir "" | Out-GridView -Wait -Title $Report
		}
	}
	# Display a message
	[string]$DoneTitle = "Done"
	Write-Host $DoneTitle
	if ($SelectedOptions.Save) {
		[string]$DoneMessage = "Reports saved under [$ScanDir]"
		Write-Host $DoneMessage
		$null = [MessageBox]::Show($DoneMessage,$DoneTitle,[MessageBoxButtons]::OK,[MessageBoxIcon]::Information)
	}
} catch {
	# Display errors
	[string]$ErrorTitle = "An error occurred!"
	[string]$ErrorMessage = $_.Exception.toString() + "`n" + $_.ScriptStackTrace.toString()
	Write-Warning -message ($ErrorTitle + "`n" + $ErrorMessage)
	$null = [MessageBox]::Show($ErrorMessage,$ErrorTitle,[MessageBoxButtons]::OK,[MessageBoxIcon]::Error)
}