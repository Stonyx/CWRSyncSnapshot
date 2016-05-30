# Copyright (C) 2009-2016 Stonyx
# http://www.stonyx.com
#
# This script is free software. You can redistribute it and/or modify it
# under the terms of the GNU General Public License Version 2 (or at your
# option any later version) as published by The Free Software Foundation.
#
# This script is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# If you did not received a copy of the GNU General Public License along
# with this script see http://www.gnu.org/copyleft/gpl.html or write to
# The Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

# ------------------------------
# RSnapshot type script
# ------------------------------
# Usage: CWRSyncSnapshot Source_Directory Target_Directory Number_of_Snapshots_to_Keep
#           Optional_Log_File

# ----- Modifiable RSync Options -----

# Explanation of default options
# a = archive mode; equals rlptgoD
#    r = recurse into directories
#    l = copy symlinks as symlinks
#    p = preserve permissions
#    t = preserve modification times
#    g = preserve group
#    o = preserve owner
#    D = preserve device and special files
# c = skip based on checksum, not mod-time & size
# v = increase verbosity
# x = don't cross filesystem boundaries
# H = preserve hard links
# S = handle sparse files efficiently
$RSYNC_OPTIONS='-acvxHS'

# ----- Prepare Commands -----

# Uncomment the following section if running on FreeNAS and comment the next section
$RSYNC = '.\bin\rsync.exe'

# ----- Initialize Variables -----

$SOURCE = $args[0]
$TARGET = $args[1]
$SNAPSHOT_COUNT = $args[2]
$LOG_FILE = $args[3]
$LOCK_FILE = 'C:\.RSyncSnapshotLock'
$RSYNC_LOG_FILE = "--log-file=$LOG_FILE"
$RSYNC_LINK_TARGET = $null

# ----- Script -----
# Make things a bit more readable when we start echoing stuff
Write-Host ''

# Make sure passed variables make sense
if (!($SOURCE))
{
   Write-Host 'Usage: CWRSyncSnapshot Source_Directory Target_Directory'
   Write-Host '   Number_of_Snapshots_to_Keep Optional_Log_File'
   Write-Host ''
   Write-Host 'No source directory specified.'
   Write-Host ''
   Exit 1
}
if (!(Test-Path $SOURCE -pathType Container))
{
   Write-Host "Specified source directory (\"$SOURCE\") doesn't exist."
   Write-Host ''
   Exit 1
}

if (!($TARGET))
{
   Write-Host 'Usage: RSyncSnapshot Source_Directory Target_Directory'
   Write-Host '   Number_of_Snapshots_to_Keep Optional_Log_File'
   Write-Host ''
   Write-Host 'No target directory specified.'
   Write-Host ''
   Exit 1
}
if (!(Test-Path $TARGET -pathType Container))
{
   Write-Host "Specified target directory (\"$TARGET\") doesn't exist."
   Write-Host ''
   Exit 1
}

if (!($SNAPSHOT_COUNT))
{
   Write-Host 'Usage: RSyncSnapshot Source_Directory Target_Directory'
   Write-Host '   Number_of_Snapshots_to_Keep Optional_Log_File'
   Write-Host ''
   Write-Host 'Number of snapshots to keep not specified.'
   Write-Host ''
   Exit 1
}
if (!($SNAPSHOT_COUNT -match '^\d+$'))
{
   Write-Host 'Specified number of snapshots to keep has to be a numeric value.'
   Write-Host ''
   Exit 1
}
if ($SNAPSHOT_COUNT -lt 1)
{
   Write-Host 'Specified number of snapshots to keep can not be less than one.'
   Write-Host ''
   Exit 1
}

# Make sure no other instance of this script is running
if (Test-Path $LOCK_FILE)
{
   Write-Host 'Another instance of the CWRSyncSnapshot script is already running.'
   Write-Host 'Press Ctrl+C to cancel this script or if no other copy of CWRSyncSnapshot'
   Write-Host "is actually running delete the \"$LOCK_FILE\" file."
   Write-Host ''
   Write-Host -noNewLine 'Waiting for the other instance of RSyncSnapshot to finish ...'
   Write-Output 'CWRSyncSnapshot: Waiting for another instance of RSyncSnapshot to finish.' `
      >> $LOG_FILE

   # Check every 15 seconds if the other instance is done
   Start-Sleep 15
   while (Test-Path $LOCK_FILE)
   {
      Write-Host -noNewLine "."
      Start-Sleep 15
   }

   # Make things pretty
   Write-Host ''
   Write-Host ''
}

# Create lock file
Write-Output '' >> $LOCK_FILE

# Delete oldest snapshot if it exists
if (Test-Path "$TARGET\Snapshot.$SNAPSHOT_COUNT")
{
   Write-Host "Removing oldest snapshot (number $SNAPSHOT_COUNT) ..."
   Write-Output "CWRSyncSnapshot: Removing oldest snapshot (number $SNAPSHOT_COUNT)." `
      >> $LOG_FILE
   Remove-Item "$TARGET\Snapshot.$SNAPSHOT_COUNT" -recurse -force
}
else
{
   Write-Host "Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist."
   Write-Output "CWRSyncSnapshot: Oldest snapshot (number $SNAPSHOT_COUNT) doesn't exist." `
      >> $LOG_FILE
}

# Make each snapshot one snapshot older
while ($SNAPSHOT_COUNT -gt 0)
{
   # Reduce SNAPSHOP_COUNT by 1 (since we've already dealt with one snapshot above)
   $SNAPSHOT_COUNT -= 1

   # Check if the snapshot might be a file instead of a directory since
   #   this happens when rsync failed to run correctly the last time
   if (Test-Path "$TARGET\Snapshot.$SNAPSHOT_COUNT" -pathType Leaf)
   {
      Write-Host "Removing invalid snapshot (number $SNAPSHOT_COUNT) ..."
      Write-Output "CWRSyncSnapshot: Removing invalid snapshot (number $SNAPSHOT_COUNT)." `
         >> $LOG_FILE
      Remove-Item "$TARGET\Snapshot.$SNAPSHOT_COUNT" -force
   }
   else
   {
      # Check if it's a directory
      if (Test-Path "$TARGET\Snapshot.$SNAPSHOT_COUNT" -pathType Container)
      {
         Write-Host "Moving snapshot number $SNAPSHOT_COUNT to $($SNAPSHOT_COUNT + 1) ..."
         Write-Output "CWRSyncSnapshot: Moving snapshot number $SNAPSHOT_COUNT to `
            $($SNAPSHOT_COUNT + 1)." >> $LOG_FILE
         Move-Item "$TARGET\Snapshot.$SNAPSHOT_COUNT" "$TARGET\Snapshot.$($SNAPSHOT_COUNT + 1)"
      }
      else
      {
         # Do the following if it doesn't exist at all
         Write-Host "Snapshot number $SNAPSHOT_COUNT doesn't exist."
         Write-Output "CWRSyncSnapshot: Snapshot number $SNAPSHOT_COUNT doesn't exist." `
            >> $LOG_FILE
      }
   }
}

# See if the directory we wanna link to exists already
if (Test-Path "$TARGET\Snapshot.1" -pathType Container)
{
   $RSYNC_LINK_TARGET='--link-dest=..\Snapshot.1'
}

# Do the actual backup using rsync
Write-Host "Backing up \"$SOURCE\" to snapshot number 0 using the command below ..."
Write-Host "$RSYNC $RSYNC_OPTIONS $RSYNC_LINK_TARGET \\"
Write-Host "\"$RSYNC_LOG_FILE\" \"$SOURCE\" \"$TARGET\Snapshot.0\""
Write-Host ''
Write-Output "RSyncSnapshot: Backing up \"$SOURCE\" to snapshot number 0 using the command below:" `
   >> $LOG_FILE
Write-Output "RSyncSnapshot: $RSYNC $RSYNC_OPTIONS $RSYNC_LINK_TARGET \\" `
   >> $LOG_FILE
Write-Output "RSyncSnapshot: \"$RSYNC_LOG_FILE\" \"$SOURCE\" \"$TARGET\Snapshot.0\"" `
   >> $LOG_FILE
Invoke-Expression "$RSYNC $RSYNC_OPTIONS $RSYNC_LINK_TARGET $RSYNC_LOG_FILE $SOURCE $TARGET\Snapshot.0"

# Update the time of the snapshot directory
(Get-Item "$TARGET\Snapshot.0").LastWriteTime = Get-Date

# remove lock file
Remove-Item $LOCK_FILE -force

# make things pretty
Write-Host ''

# all done
Exit 0