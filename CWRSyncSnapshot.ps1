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
# RSnapshot type script
# ------------------------------
# Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Optional_Log_File 
#          Custom_Lock_File

# ----- RSync Command -----

$RSYNC = "$(Resolve-Path '.\bin\rsync.exe')"

# ----- RSync Options -----

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
$RSYNC_OPTIONS = "-acvxHS"

# ----- Script -----

# Initialize needed variables
if ($args[0])
{
  $SOURCE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0])
}
if ($args[1])
{
  $TARGET = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[1])
}
$SNAPSHOT_COUNT = $args[2]
if ($args[3])
{
  LOG_FILE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[3])
}
if ($args[4])
{
  LOCK_FILE = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[4])
}
else
{
  $LOCK_FILE = "C:\CWRSyncSnapshopLock"
}

# Make things pretty
Write-Host ""

# Make sure the passed in arguments make sense
if (!($SOURCE))
{
  Write-Host "Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Optional_Log_File"
  Write-Host "         Custom_Lock_File"
  Write-Host ""
  Write-Host "No source directory specified."
  Write-Host ""
  Exit 1
}
if (!(Test-Path $SOURCE -pathType Container))
{
  Write-Host "Specified source directory (`"$SOURCE`") doesn't exist."
  Write-Host ""
  Exit 1
}
if (!($TARGET))
{
  Write-Host "Usage: RSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Optional_Log_File"
  Write-Host "         Custom_Lock_File"
  Write-Host ""
  Write-Host "No target directory specified."
  Write-Host ""
  Exit 1
}
if (!(Test-Path $TARGET -pathType Container))
{
  Write-Host "Specified target directory (`"$TARGET`") doesn't exist."
  Write-Host ""
  Exit 1
}
if (!($SNAPSHOT_COUNT))
{
  Write-Host "Usage: RSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep Optional_Log_File"
  Write-Host "         Custom_Lock_File"
  Write-Host ""
  Write-Host "Number of snapshots to keep not specified."
  Write-Host ""
  Exit 1
}
if (!($SNAPSHOT_COUNT -match "^\d+$"))
{
  Write-Host "Specified number of snapshots to keep has to be a numeric value."
  Write-Host ""
  Exit 1
}
if ($SNAPSHOT_COUNT -lt 1)
{
  Write-Host "Specified number of snapshots to keep can not be less than one."
  Write-Host ""
  Exit 1
}

# Get the 

# Make sure no other instance of this script is running
if (Test-Path $LOCK_FILE -pathType Leaf)
{
  Write-Host "Another instance of the CWRSyncSnapshot script is already running.  Press Ctrl+C to cancel this script or"
  Write-Host "if no other copy of CWRSyncSnapshot is actually running delete the `"$LOCK_FILE`" file."
  Write-Host ""
  Write-Host -noNewLine "Waiting for the other instance of CWRSyncSnapshot to finish ..."
  Write-Output "CWRSyncSnapshot: Waiting for another instance of RSyncSnapshot to finish." >> $LOG_FILE

  # Check every 15 seconds if the other instance is done
  Start-Sleep 15
  while (Test-Path $LOCK_FILE -pathType Leaf)
  {
    Write-Host -noNewLine "."
    Start-Sleep 15
  }

  # Make things pretty
  Write-Host ""
  Write-Host ""
}

# Create the lock file
New-Item $LOCK_FILE -type file | Out-Null

# Delete the oldest snapshot if it exists
if (Test-Path $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT"))
{
  Write-Host "Removing oldest snapshot (number $SNAPSHOT_COUNT) ..."
  Write-Output "CWRSyncSnapshot: Removing oldest snapshot (number $SNAPSHOT_COUNT)." >> $LOG_FILE
  Remove-Item $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") -recurse -force
}
else
{
  Write-Host "Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist."
  Write-Output "CWRSyncSnapshot: Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist." >> $LOG_FILE
}

# Make each snapshot one snapshot older
while ($SNAPSHOT_COUNT -gt 0)
{
  # Reduce SNAPSHOP_COUNT by 1 (since we've already dealt with one snapshot above)
  $SNAPSHOT_COUNT -= 1

  # Check if the snapshot might be a file instead of a directory since this happens if rsync failed to 
  #   run correctly the last time ...
  if (Test-Path $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") -pathType Leaf)
  {
    Write-Host "Removing invalid snapshot (number $SNAPSHOT_COUNT) ..."
    Write-Output "CWRSyncSnapshot: Removing invalid snapshot (number $SNAPSHOT_COUNT)." >> $LOG_FILE
    Remove-Item $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") -force
  }
  # ... or if it's a directory ...
  elseif (Test-Path $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") -pathType Container)
  {
    Write-Host "Moving snapshot number $SNAPSHOT_COUNT to $($SNAPSHOT_COUNT + 1) ..."
    Write-Output "CWRSyncSnapshot: Moving snapshot number $SNAPSHOT_COUNT to $($SNAPSHOT_COUNT + 1)." >> $LOG_FILE
    Move-Item $(Join-Path $TARGET "\Snapshot.$SNAPSHOT_COUNT") $(Join-Path $TARGET "\Snapshot.$($SNAPSHOT_COUNT + 1)")
  }
  # ... or do the following if it doesn't exist at all
  else
  {
    Write-Host "Snapshot number $SNAPSHOT_COUNT doesn't exist."
    Write-Output "CWRSyncSnapshot: Snapshot number $SNAPSHOT_COUNT doesn't exist." >> $LOG_FILE
  }
}

# Create the rsync command
$RSYNC_COMMAND = "$RSYNC $RSYNC_OPTIONS "
if (Test-Path $(Join-Path $TARGET "\Snapshot.1") -pathType Container)
{
  $RSYNC_COMMAND += "`"--link-dest=../Snapshot.1`" "
}
if ($LOG_FILE)
{
  $RSYNC_COMMAND += "`"--log-file=/cygdrive/$($LOG_FILE.Replace(':', '').Replace('\', '/'))`" "
}
$RSYNC_COMMAND += "`"/cygdrive/$($SOURCE.Replace(':', '').Replace('\', '/'))`" "
$RSYNC_COMMAND += "`"/cygdrive/$($(Join-Path $TARGET "\Snapshot.0").Replace(':', '').Replace('\', '/'))`""

# Do the actual backup using rsync
Write-Host "Backing up `"$SOURCE`" to snapshot number 0 using the following command:"
Write-Host $RSYNC_COMMAND
Write-Host ""
Write-Output "CWRSyncSnapshot: Backing up `"$SOURCE`" to snapshot number 0 using the following command:" `
  >> $LOG_FILE
Write-Output "CWRSyncSnapshot: $RSYNC_COMMAND" >> $LOG_FILE
Invoke-Expression ($RSYNC_COMMAND)

# Remove lock file
Remove-Item $LOCK_FILE -force

# Make things pretty
Write-Host ""

# All done
Exit 0