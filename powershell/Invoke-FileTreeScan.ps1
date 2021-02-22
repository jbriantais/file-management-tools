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
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Exit the script when the user cancels operation from a dialog
function Exit-Dialog {
	Write-Host "Process cancelled"
	exit
}

# Retrive and check the options values
function Set-Options {
	param (
		[System.Windows.Window]$OptionsWindow,
		[pscustomobject]$Options
	)
	# Get the values from the dialog
	$Options.ScanDir = $OptionsWindow.FindName("ScanDir").Text
	$Options.Reports = foreach ($Report in @("FilesAndDirectories","DuplicateFiles")) {
		if ($OptionsWindow.FindName($Report).IsChecked) {
			$Report
		}
	}
	$Options.Save = $OptionsWindow.FindName("Save").IsChecked
	# Check the values
	[string]$ValidationMessage = ""
	if (!$Options.ScanDir) {
		$ValidationMessage += "No directory selected`n"
	} elseif (!(Test-Path $Options.ScanDir -PathType Container)) {
		$ValidationMessage += "Invalid directory [" + $Options.ScanDir + "]`n"
	}
	if (!$Options.Reports) {
		$ValidationMessage += "No report selected`n"
	}
	# Display a message and return validation result
	if ($ValidationMessage) {
		Write-Host $ValidationMessage
		$null = [MessageBox]::Show($ValidationMessage,"Invalid options",[MessageBoxButtons]::OK,[MessageBoxIcon]::Warning)
	}
	return ![bool]$ValidationMessage
}

# Display the options dialog
function Read-Options {
	# Design of the dialog
	[xml]$OptionsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Title="Options" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" UseLayoutRounding="True"
		SizeToContent="WidthAndHeight" TextOptions.TextFormattingMode="Display">
	<StackPanel Margin="10,7,10,7">
		<StackPanel.Resources>
			<Style TargetType="{x:Type TextBlock}">
				<Setter Property="Margin" Value="7,5,7,5"/>
				<Setter Property="TextWrapping" Value="Wrap"/>
			</Style>
			<Style TargetType="{x:Type TextBox}">
				<Setter Property="Margin" Value="7,5,7,5"/>
				<Setter Property="Padding" Value="3,3,3,3"/>
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
		<TextBlock>Which directory do you want to scan?</TextBlock>
		<DockPanel>
			<Button Name="BrowseButton" DockPanel.Dock="Right">Browse...</Button>
			<TextBox Name="ScanDir"/>
		</DockPanel>
		<TextBlock>Which reports do you want to generate?</TextBlock>
		<CheckBox Name="FilesAndDirectories">List and details of files and directories</CheckBox>
		<CheckBox Name="DuplicateFiles">Duplicate files *</CheckBox>
		<TextBlock>* Warning: depending on the volume, process may last hours and generate high network traffic.
			<LineBreak/>If runing on a network file system, it may be preferable to do some cleanup of large files first.</TextBlock>
		<TextBlock>What do you want to do with these reports?</TextBlock>
		<UniformGrid HorizontalAlignment="Left" Rows="1" Columns="2">
			<RadioButton Name="Save" GroupName="Action" IsChecked="True">Save to CSV files</RadioButton>
			<RadioButton Name="Display" GroupName="Action">Display on screen</RadioButton>
		</UniformGrid>
		<UniformGrid HorizontalAlignment="Right" Rows="1" Columns="2">
			<Button Name="OKButton" IsDefault="True">OK</Button>
			<Button IsCancel="True">Cancel</Button>
		</UniformGrid>
	</StackPanel>
</Window>
"@
	# Initialize the options
	[pscustomobject]$Options = [pscustomobject]@{
		ScanDir = $null
		Reports = $null
		Save = $null
	}
	# Build the window
	[System.Xml.XmlNodeReader]$OptionsReader = New-Object System.Xml.XmlNodeReader $OptionsXaml
	[System.Windows.Window]$OptionsWindow = [Windows.Markup.XamlReader]::Load($OptionsReader)
	# Add an event for BrowseButton
	$OptionsWindow.FindName("BrowseButton").add_click({
		$OptionsWindow.FindName("ScanDir").Text = & $PSScriptRoot\Read-FolderBrowserDialog.ps1
	})
	# Add an event for OKButton
	$OptionsWindow.FindName("OKButton").add_click({
		if (Set-Options $OptionsWindow $Options) {
			$OptionsWindow.DialogResult = $true
		}
	})
	# Display the dialog
	if (!$OptionsWindow.Showdialog()) {
		Exit-Dialog
	}
	# Trace the options values
	Write-Host "Selected directory to scan: " + $Options.ScanDir
	Write-Host "Selected reports: " $Options.Reports
	Write-Host "Save to CSV files: " $Options.Save
	return $Options
}

# Get the report path
function Get-ReportPath {
	param (
		[string]$ScanDir,
		[string]$Report
	)
	return "$ScanDir\FileTreeScanReport-$Report.csv"
}

# Check the report path
function Test-ReportPath {
	param (
		[string]$ScanDir,
		[string]$Report
	)
	[string]$ReportPath = Get-ReportPath $ScanDir $Report
	if (Test-Path $ReportPath -PathType Container) {
		throw "Output report path [$ReportPath] is a directory"
	}
	if (Test-Path $ReportPath -PathType Leaf) {
		[string]$BoxMessage = "Output report file already exists [$ReportPath]. Do you want to replace it or to cancel the process?"
		[MessageBoxIcon]$BoxIcon = [MessageBoxIcon]::Warning
	} else {
		[string]$BoxMessage = "Output report file will be generated in [$ReportPath]. Do you want to proceed?"
		[MessageBoxIcon]$BoxIcon = [MessageBoxIcon]::Question
	}
	if ([MessageBox]::Show($BoxMessage,"Confirmation",[MessageBoxButtons]::OKCancel,$BoxIcon) -eq [DialogResult]::Cancel) {
		Exit-Dialog
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
			Type = if ($_.PSIsContainer) {"<DIR>"} elseif ($_.Extension) {$_.Extension} else {"<UNDEF>"}
			SizeInBytes = if ($_.PSIsContainer) {"<N/A>"} else {$_.Length}
			NumberOfChildren = if ($_.PSIsContainer) {$_.GetFileSystemInfos().Count} else {"<N/A>"}
			CreationTime = $_.CreationTime
			LastAccessTime = $_.LastAccessTime
			LastWriteTime = $_.LastWriteTime
			ParentDirectory = if ($_.PSIsContainer) {$_.Parent.FullName} else {$_.Directory}
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
	# Display the options dialog
	[pscustomobject]$Options = Read-Options
	# Check the reports paths
	if ($Options.Save) {
		foreach ($Report in $Options.Reports) {
			Test-ReportPath $Options.ScanDir $Report
		}
	}
	# Run the reports
	Write-Host "Please wait until process has finished..."
	foreach ($Report in $Options.Reports) {
		Write-Host "Generating $Report..."
		if ($Options.Save) {
			[string]$ReportPath = Get-ReportPath $Options.ScanDir $Report
			& Get-$Report $Options.ScanDir $ReportPath | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | Out-File $ReportPath
		} else {
			& Get-$Report $Options.ScanDir "" | Out-GridView -Wait -Title $Report
		}
	}
	# Display a message
	[string]$DoneTitle = "Done"
	Write-Host $DoneTitle
	if ($Options.Save) {
		[string]$DoneMessage = "Reports saved under [" + $Options.ScanDir + "]"
		Write-Host $DoneMessage
		$null = [MessageBox]::Show($DoneMessage,$DoneTitle,[MessageBoxButtons]::OK,[MessageBoxIcon]::Information)
	}
} catch {
	# Display errors
	[string]$ErrorTitle = "An error occurred!"
	[string]$ErrorMessage = $_.Exception.toString() + "`n" + $_.ScriptStackTrace.toString()
	Write-Warning -message ($ErrorTitle + "`n" + $ErrorMessage)
	$null = [MessageBox]::Show($ErrorMessage,$ErrorTitle,[MessageBoxButtons]::OK,[MessageBoxIcon]::Error)
	exit 1
}
