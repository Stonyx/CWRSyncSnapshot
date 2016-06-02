# Copyright (C) 2009-2016 Stonyx
# http://www.stonyx.com
#
# This script is free software. You can redistribute it and/or modify it under the terms of the GNU General
# Public License Version 3 (or at your option any later version) as published by The Free Software Foundation.
#
# This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# If you did not received a copy of the GNU General Public License along with this script see 
# http://www.gnu.org/copyleft/gpl.html or write to The Free Software Foundation, 675 Mass Ave, Cambridge,
# MA 02139, USA.

# ------------------------------
# RSnapshot Type Script
# ------------------------------
# Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File
#          Optional_Additional_CWRSync_Arguments...

# ----- CWRSync Command -----

$CWRSYNC = '.\bin\rsync.exe'

# ----- CWRSync Options -----

# Explanation of the default options:
# a = archive mode which equals rlptgoD
#   r = recurse into directories
#   l = copy symlinks as symlinks
#   p = preserve permissions
#   t = preserve modification times
#   g = preserve group
#   o = preserve owner
#   D = preserve device and special files
# c = skip based on checksum, not mod-time & size
# v = increase verbosity
# x = don't cross filesystem boundaries
# H = preserve hard links
# S = handle sparse files efficiently
$CWRSYNC_OPTIONS = "-acvxHS"

# ----- Script -----

# Make things pretty
Write-Host ""

# Process the source argument
if (!($args[0]))
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File"
  Write-Host "  Optional_Additional_CWRSync_Arguments ..."
  Write-Host ""
  Write-Host "Source directory not specified."
  Write-Host ""
  Exit 1
}
try
{
  $SOURCE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0])
}
catch
{
  Write-Host "Specified source directory (`"$args[0]`") is not valid."
  Write-Host ""
  Exit 1
}
if (!(Test-Path $SOURCE -pathType Container))
{
  Write-Host "Specified source directory (`"$SOURCE`") doesn't exist."
  Write-Host ""
  Exit 1
}

# Process the target argument
if (!($args[1]))
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File"
  Write-Host "  Optional_Additional_CWRSync_Arguments ..."
  Write-Host ""
  Write-Host "Target directory not specified."
  Write-Host ""
  Exit 1
}
try
{
  $TARGET = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[1])
}
catch
{
  Write-Host "Specified target directory (`"$args[1]`") is not valid."
  Write-Host ""
  Exit 1
}
if (!(Test-Path $TARGET -pathType Container))
{
  Write-Host "Specified target directory (`"$TARGET`") doesn't exist."
  Write-Host ""
  Exit 1
}

# Process the snapshot count argument
if (!($args[2]))
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File"
  Write-Host "  Optional_Additional_CWRSync_Arguments ..."
  Write-Host ""
  Write-Host "Number of snapshots to keep not specified."
  Write-Host ""
  Exit 1
}
$SNAPSHOT_COUNT = $args[2]
if (!($SNAPSHOT_COUNT -match "^\d+$"))
{
  Write-Host "Specified number of snapshots to keep has to be a numeric value."
  Write-Host ""
  Exit 1
}

# Process the log file argument
if (!($args[3]))
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File"
  Write-Host "  Optional_Additional_CWRSync_Arguments ..."
  Write-Host ""
  Write-Host "Log file not specified."
  Write-Host ""
  Exit 1
}
try
{
  $LOG_FILE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[3])
}
catch
{
  Write-Host "Specified log file (`"$args[3]`") is not valid."
  Write-Host ""
  Exit 1
}

# Process the lock file argument
if (!$args[4])
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Log_File Lock_File"
  Write-Host "  Optional_Additional_CWRSync_Arguments ..."
  Write-Host ""
  Write-Host "Lock file not specified."
  Write-Host ""
  Exit 1
}
try
{
  $LOCK_FILE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[4])
}
catch
{
  Write-Host "Specfieid lock file (`"$args[4]`") is not valid."
  Write-Host ""
  Exit 1
}

# Process the CWRSync command
try
{
  $CWRSYNC = Resolve-Path $CWRSYNC
}
catch
{
  Write-Host "Unable to find the CWRSync executable."
  Write-Host ""
  Exit 1
}

# Make sure no other instance of this script is running
if (Test-Path $LOCK_FILE)
{
  Write-Host "Another instance of the CWRSyncSnapshot script is already running.  Press Ctrl+C to cancel this script or"
  Write-Host "if no other copy of CWRSyncSnapshot is actually running delete the `"$LOCK_FILE`" file."
  Write-Host ""
  Write-Host -noNewLine "Waiting for the other instance of CWRSyncSnapshot to finish ..."
  if ($LOG_FILE)
  {
    Write-Output "CWRSyncSnapshot: Waiting for another instance of CWRSyncSnapshot to finish." | `
      Out-File $LOG_FILE UTF8 -append
  }

  # Check every 15 seconds if the other instance is done
  Start-Sleep 15
  while (Test-Path $LOCK_FILE)
  {
    Write-Host -noNewLine "."
    Start-Sleep 15
  }

  # Make things pretty
  Write-Host ""
  Write-Host ""
}

# Create the lock file
$LOCK_FILE = New-Item $LOCK_FILE -itemType file

# Delete the oldest snapshot if it exists
if (Test-Path $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT"))
{
  Write-Host "Deleting oldest snapshot (number $SNAPSHOT_COUNT) ..."
  if ($LOG_FILE)
  {
    Write-Output "CWRSyncSnapshot: Deleting oldest snapshot (number $SNAPSHOT_COUNT)." | `
      Out-File $LOG_FILE UTF8 -append
  }
  Remove-Item $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") -recurse -force
}
else
{
  Write-Host "Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist."
  if ($LOG_FILE)
  {
    Write-Output "CWRSyncSnapshot: Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist." | `
      Out-File $LOG_FILE UTF8 -append
  }
}

# Make each snapshot one snapshot older
while ($SNAPSHOT_COUNT -gt 0)
{
  # Reduce SNAPSHOP_COUNT by 1 (since we've already dealt with one snapshot above)
  $SNAPSHOT_COUNT -= 1

  # Check if the snapshot exists
  if (Test-Path $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT"))
  {
    Write-Host "Moving snapshot number $SNAPSHOT_COUNT to $($SNAPSHOT_COUNT + 1) ..."
    if ($LOG_FILE)
    {
      Write-Output "CWRSyncSnapshot: Moving snapshot number $SNAPSHOT_COUNT to $($SNAPSHOT_COUNT + 1)." | `
        Out-File $LOG_FILE UTF8 -append
    }
    Move-Item $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") $(Join-Path $TARGET "\Snapshot.$($SNAPSHOT_COUNT + 1)") `
      -force
  }
  else
  {
    Write-Host "Snapshot number $SNAPSHOT_COUNT doesn't exist."
    if ($LOG_FILE)
    {
      Write-Output "CWRSyncSnapshot: Snapshot number $SNAPSHOT_COUNT doesn't exist." | `
        Out-File $LOG_FILE UTF8 -append
    }
  }
}

# Create the snapshot directory
$SNAPSHOT = New-Item $(Join-Path $TARGET "\Snapshot.0") -itemType directory

# Create the CWRSync command
$CWRSYNC_COMMAND = "$CWRSYNC $CWRSYNC_OPTIONS "
if (Test-Path $(Join-Path $TARGET "\Snapshot.1"))
{
  $CWRSYNC_COMMAND += "`"--link-dest=../Snapshot.1`" "
}
$CWRSYNC_COMMAND += "`"--log-file=/cygdrive/$($LOG_FILE.Replace(':', '').Replace('\', '/'))`" "
for ($i = 5; $i -lt $args.length; $i++)
{
  $CWRSYNC_COMMAND += "`"$args[$i]`" "
}
$CWRSYNC_COMMAND += "`"/cygdrive/$($SOURCE.Replace(':', '').Replace('\', '/'))`" "
$CWRSYNC_COMMAND += "`"/cygdrive/$($(Join-Path $TARGET "\Snapshot.0").Replace(':', '').Replace('\', '/'))`""

# Do the actual backup using CWRSync
Write-Host "Backing up `"$SOURCE`" to snapshot number 0 using the following command:"
Write-Host $CWRSYNC_COMMAND
Write-Host ""
if ($LOG_FILE)
{
  Write-Output "CWRSyncSnapshot: Backing up `"$SOURCE`" to snapshot number 0 using the following command:" | `
    Out-File $LOG_FILE UTF8 -append
  Write-Output "CWRSyncSnapshot: $CWRSYNC_COMMAND" | Out-File $LOG_FILE UTF8 -append
  Write-Output "" | Out-File $LOG_FILE UTF8 -append
}
Invoke-Expression ($CWRSYNC_COMMAND)

# Update the write time of the snapshot directory
$SNAPSHOT.lastWriteTime = Get-Date

# Remove the lock file
Remove-Item $LOCK_FILE -force

# Make things pretty
Write-Host ""
if ($LOG_FILE)
{
  Write-Output "" | Out-File $LOG_FILE UTF8 -append
}

# All done
Exit 0