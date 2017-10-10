print '---------------------------'
print '29 Create SYS JOBs '
print '---------------------------'
-- ------------------------------------------------------------------------------------------------
-- Jobs erstellen
-- ------------------------------------------------------------------------------------------------
-- neuen Backupjob erstellen
USE [msdb]
GO

/****** Object:  Job [SYS_BACKUP_FULL_NETWORKER]    Script Date: 28.07.2016 13:33:05 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 28.07.2016 13:33:05 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_BACKUP_FULL_NETWORKER', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Dieser Job f�hrt das t�gliche Fullbackup durch.
Der Job hat 5 Schritte:
1. Startzeit einf�gen
2. Rename ausf�hren
3. SQL Backup durchf�hren
4. AS Backup durchf�hren
5. Endzeit einf�gen und an Centralserver schicken
6. File f�r Networker bereitstellen', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Insert Starttime]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert Starttime', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
TRUNCATE TABLE backuplog

INSERT INTO backuplog(ID,Datum,BeginBackup)
values
(1,GETDATE(),GETDATE())
', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [RenameBackup]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'RenameBackup', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#----------------------------------------------------------------
# Rename Folder
#----------------------------------------------------------------
# Dieses Script �ndert den Namen des Backupfolders
# Die Pfad informationen werden aus der IT2_Sysadmin geholt
#----------------------------------------------------------------
# 10.09.14 Melih Bildik
#----------------------------------------------------------------

#Query f�r den Backupordner
$backupfolder_query = "SELECT value FROM IT2_SysAdmin.[dbo].[t_localsettings] WHERE definition = ''Backup full path''"
#Query f�r die Fehlermeldung im Eventlog
$errorlog_query = "EXEC xp_logevent 60000, ''Networker Kontrollfile ist noch vorhanden, der Ordner wurde nicht gel�scht. Bitte Kontrollieren'' , ERROR"
$errorlog_emptyfolder_query = "EXEC xp_logevent 60000, ''Das Backupverzeichnis war leer!! Bitte Kontrollieren!!!, Ein Notfall Ordner wurde angelegt'' , ERROR"

$backupfolder = (Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $backupfolder_query |Format-Table -HideTableHeaders |Out-String).Trim() #select-object -expand value

$backupfolder_copy = $backupfolder+1
$noNetworkBackupFolder =''noNetworkBackup''
$emptyBackupFolder = ''noSQLBackup''
$backupfolderBak = $backupfolder+''\*.bak''
$backupfolderFile = $backupfolder+''\savenow''
$today = (Get-Date -format dd-MM-yy)
$noNetworkBackupFolder = $noNetworkBackupFolder +$today
$emptyBackupFolder = $emptyBackupFolder +$today

IF (Test-Path $backupfolderFile)
{
Rename-Item -path $backupfolder -newName $noNetworkBackupFolder 
New-Item $backupfolder -type directory
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $errorlog_query 
return
}

IF(Test-Path $backupfolderBak)
{
Remove-Item $backupfolder_copy -recurse
Rename-Item -path $backupfolder -newName $backupfolder_copy
New-Item $backupfolder -type directory
}
ELSE
{
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $errorlog_emptyfolder_query
Rename-Item -path $backupfolder_copy -newName $emptyBackupFolder
New-Item $backupfolder_copy -type directory
}



', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute SQL Backup]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute SQL Backup', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_BACKUP_FULL', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Execute AS Backup]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute AS Backup', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#----------------------------------------------------------------
# AS Backup Script
#----------------------------------------------------------------
# Erstellt Sicherungen von den AS Datenbanken
#----------------------------------------------------------------
# 02.12.2014 	Kunabalasingam Kaureesan - Hauri
#----------------------------------------------------------------
# 02.12.2014	Kunabalasingam Kaureesan	Erstellung - Script
# 12.12.2014	Kunabalasingam Kaureesan 	�berarbeitung - Script
# 05.01.2015	Kunabalasingam Kaureesan 	�berarbeitung - Script
# 19.01.2015	Kunabalasingam Kaureesan 	�berarbeitung - Script 

	# Variable - Ermittlung: Hostnamen
    $hostname = Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "select SERVERPROPERTY (''MachineName'')" | Select-Object -Property column1 -ExpandProperty column1

	# Variable - Ermittlung: Cluster
    $cluster_check = Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "SELECT CONVERT(char(20), SERVERPROPERTY(''IsClustered''))" | Select-Object Column1 -ExpandProperty Column1

	# Variable - Ermittlung der laufenden AS & SQL Instanzen
    [array]$run_as_instances =  Get-Service -Name "*olap*" | Where-Object {$_.status -eq "Running"} | Select-Object Name -ExpandProperty Name
	[array]$run_sql_instances = Get-Service -Name "mssql*" | Where-Object {$_.Status -eq "Running" -and $_.Name -notlike "*FDLauncher*" -and $_.Name -notlike "*OLAP*"} | Select-Object Name -ExpandProperty Name 
  
	# Variable - Ermittlung: BackupPfad
    $backupfolder_query = "select value from it2_sysadmin.[dbo].[t_localsettings] where definition = ''Backup full path''"
    $backupfolder = Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $backupfolder_query | Select-Object -Property Value -ExpandProperty Value

#----------------------------------------------------------------
# Start Funktion - Erstellung: Backup
#----------------------------------------------------------------
    function create-backup ($ins_con_name)
    {   
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | out-null
        $serverAS = New-Object Microsoft.AnalysisServices.Server

		# Verbindungsaufbau - AS Instanz & Abfrage AS Datenbanken
        $serverAS.Connect($ins_con_name) | Out-Null
        $asDatabases = $serverAS.Databases

        $timestamp = (Get-Date).ToString("dd_MM_yyyy_HHmm")
		$date_for_centralreport = Get-Date

		# Kontrolle - Variable: asDatabases = Leer - Errormeldung im SQL Server Log
        if($asDatabases.Count -eq 0)
        {
            Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "EXEC xp_logevent 60000, ''Auf der folgenden Instanz:$ins_con_name besteht die Moeglichkeit fuer folgende Probleme: Der Service Account hat keine Berechtigung fuer die Abfrage der AS Datenbanken oder es bestehen keine AS Datenbanken auf der erwaehnten Instanz. Die genannte Instanz wurde bei der AS Sicherung nicht beruecksichtigt.'' , ERROR"
        }
		try
		{
        	foreach($asDatabase in $asDatabases)
        	{
            	$ins_name = $ins_con_name.Replace(''\'',''_'')
            	$asDatabase.Backup("$backupfolder\$ins_name--$asDatabase--$timestamp.abf")
        	}
		}
		catch
		{
				# Kontrolle - Fehlverhalten w�hrend Backupprozess - Errormeldung im SQL Server Log
			    $ErrorMessage = $_.Exception.Message
				Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "EXEC xp_logevent 60000, ''Beim erstellen des ASBackups auf der Instanz: $ins_con_name passierte ein Terminating-Fehler, bitte melden Sie sich beim MSSQL Engineering.'' , ERROR"
		}
		
		# Eintrag - CENTRALSERVER
		try
		{
			foreach($asDatabase in $asDatabases)
			{
				Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[as_backup_log] (job_executed_instance_name,affected_as_instance_name,asdb_name,backup_path,backup_date) VALUES (''$(ESCAPE_SQUOTE(SRVR))'',''$ins_con_name'',''$asDatabase'',''$backupfolder'',''$date_for_centralreport'');" -ErrorAction Stop
			}
		}
		catch
		{
			# Kontrolle -  Fehlverhalten w�hrend CENTRALSERVER Eintrag - Errormeldung im SQL Server Log
			Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query "EXEC xp_logevent 60000, ''Bei der Erstellung des ASSicherungseintrags auf dem CENTRALSERVER, f�r die Datenbanken der Instanz: $ins_con_name ist aufgrund eines Terminating-Fehlers fehlgeschlagen. Bitte melden Sie sich beim MSSQL Engineering.'' , ERROR"
		}
		#Verbindungsabbau - AS Instanz
        $serverAS.Disconnect($ins_con_name)
    }
#----------------------------------------------------------------
# Ende Funktion - Erstellung: Backup
#----------------------------------------------------------------

	# Kontrolle - Inhalt Variable: run_as_instances
    if(!$run_as_instances)
    {
        return
    }

	# Erstellung - Connection String: AS Instanzen
    for($i = 0; $i -lt $run_as_instances.Count; $i++)
    {
        if($run_as_instances[$i] -like "MSOLAP$*")
        {
            $run_as_instances[$i] = "$hostname\" + $run_as_instances[$i].substring(7)
        }
        else
        {
            $run_as_instances[$i] = $hostname
        }
    }

	# Erstellung - Connection String: SQL Instanzen
    for($i = 0; $i -lt $run_sql_instances.Count; $i++)
    {
        if($run_sql_instances[$i] -like "MSSQL$*")
        {
            $run_sql_instances[$i] = "$hostname\" + $run_sql_instances[$i].substring(6)
        }
        else
        {
            $run_sql_instances[$i] = $hostname
        }
    }

	# Erstellung - Backup bei: AS Instanz gleich Instanzname (JOB Ausf�hrung - abh�ngig)
    for($i = 0; $i -lt $run_as_instances.Count; $i++)
    {
        if($run_as_instances[$i] -eq "$(ESCAPE_SQUOTE(SRVR))")
        {
			# Aufruf - Funktion: create-backup - AS Datenbanksicherung
			create-backup $run_as_instances[$i]
        }
    }

	# Kontrolle - Clusterbedingung
    if($cluster_check.Trim() -eq 0)
    {
		# Erstellung - Backup bei: AS Instanzen ohne SQL Instanzen
        if($run_sql_instances[0] -eq "$(ESCAPE_SQUOTE(SRVR))")
        {
            $no_sql_instances = Compare-Object -ReferenceObject $run_sql_instances -DifferenceObject $run_as_instances | Where-Object {$_.SideIndicator -eq "=>"} | Select-Object InputObject -ExpandProperty InputObject

            if(!$no_sql_instances)
            {
                return
            }
		
		    foreach($no_sql_instance in $no_sql_instances)
            {
				# Aufruf - Funktion: create-backup - AS Datenbanksicherung
                create-backup $no_sql_instance
            }
        }
    }', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [insert Endtime and insert Data in Centralserver]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'insert Endtime and insert Data in Centralserver', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'UPDATE backuplog
SET EndBackup = getdate()
WHERE ID = 1

DECLARE 
@duration int,
@start datetime,
@end datetime

SET @start = (SELECT BeginBackup FROM backuplog WHERE ID = 1)
SET @end = (SELECT EndBackup FROM backuplog WHERE ID = 1)
SET @duration = DATEdiff(second,@start,@end)

UPDATE backuplog
SET Duration = @duration
WHERE ID = 1

-- Alte Daten aus der Centralserver DB l�schen
DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[backupduration] WHERE Server=@@SERVERNAME and Datum < GETDATE()-14
	
--Aktuelle Daten in Centralserver DB schreiben
INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[backupduration](Server,Datum,StartTime,EndTime,Duration)
SELECT @@SERVERNAME,Datum,CONVERT(time,BeginBackup),CONVERT(time,EndBackup),Duration FROM backuplog where ID = 1
', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Networker Kontrollfile]    Script Date: 28.07.2016 13:33:05 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Networker Kontrollfile', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# Networker Kontrollfile
#----------------------------------------------------------------
# Dieses Script erstellt das Kontrollfile f�r networker
# Die Pfad informationen werden aus der IT2_Sysadmin geholt
#----------------------------------------------------------------
# 13.10.14 Melih Bildik
#----------------------------------------------------------------

# Query f�r lokalen Backup Pfad 
$query_backuppath = "SELECT value FROM IT2_SysAdmin..t_localsettings WHERE definition = ''Backup full path''"

# Query auslesen
$backup_path = (Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $query_backuppath) |select-object -expand value  

# Kontrollfile schreiben, bei einem Fehler wird der Job mit einem Fehler beendet

New-Item -Path "$backup_path " -Name "savenow" -ItemType "file" -force  -ErrorVariable FileError 

if ($FileError)
{
throw (''$FileError'') 
}

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140918, 
		@active_end_date=99991231, 
		@active_start_time=220000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/21/2009 09:50:43 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_BACKUP_TLOG', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Backup Transaction Log aller Datenbanken', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [bck_tlog]    Script Date: 10/21/2009 09:50:43 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'bck_tlog', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_BACKUP_TLOG', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'bck_tlog', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20070115, 
		@active_end_date=99991231, 
		@active_start_time=3000, 
		@active_end_time=220000
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 06/08/2010 09:40:10 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
 
END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_CHECKDB', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Führt ein CheckDB über alle DBs durch', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [exec USP_CHECKDB]    Script Date: 06/08/2010 09:40:10 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'exec USP_CHECKDB', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_CHECKDB', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Wöchentlich', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20100608, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/21/2009 09:50:43 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_DELETE_LOGS', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Löscht Backup history', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [delete]    Script Date: 10/21/2009 09:50:43 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'delete', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_DELETE_LOGS', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dailydelete', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20080708, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/21/2009 09:50:43 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_INDEX_REBUILD', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Startet die Storage Procedure usp_index_reorg ohne Parameter (default)', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Index_REBUILD]    Script Date: 10/21/2009 09:50:44 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Index_REBUILD', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_INDEX_REBUILD', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20070213, 
		@active_end_date=99991231, 
		@active_start_time=1000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/21/2009 09:50:44 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_REFRESH_STATISTICS', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Update der Statistiken', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [REFRESH_STATISTICS]    Script Date: 10/21/2009 09:50:44 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'REFRESH_STATISTICS', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_REFRESH_STATISTICS', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'REFRESH_STATISTICS', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=2, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20090511, 
		@active_end_date=99991231, 
		@active_start_time=100, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 10/21/2009 09:50:44 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_SQLSERVERERRORLOGSWITCH', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Dieses Job switch täglich die SQL Server Error Logs. Somit werden die Logfiles nicht zu gross wachsen.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SYS_SQLServerErrorLogSwitch]    Script Date: 10/21/2009 09:50:44 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SYS_SQLServerErrorLogSwitch', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec sp_cycle_errorlog', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'mittenacht', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20070817, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

/****** Object:  Job [SYS_LOGON_ERROS]    Script Date: 03/05/2010 12:52:12 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 03/05/2010 12:52:13 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_LOGON_ERRORS', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Reports Logon Errors', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Insert into table Logon_errors]    Script Date: 03/05/2010 12:52:13 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert into table Logs', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec USP_LOGON_ERRORS', 
		@database_name=N'IT2_SysAdmin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'logon_errrors', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20100305, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

--------------------------------------------------------------------------------
-- BackupCheck
--------------------------------------------------------------------------------
-- Dieses Script installiert das BackupCheck 
--
--------------------------------------------------------------------------------
-- Database:              P95_DBAReports
-- Verstion:              1.1
-- Date:                  01.09.2010
-- Autor:                 Melih Bildik, IT226
-- Copyright:             ©smartdynamic AG 2010
--------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor					Version		Date		What
-- Bildik Melih, IT226		1.0				erste Version
-- Bildik Melih,  IT226		1.1		01.09.10	Anpassungen Zieldatenbank neuer Step im Job
-- Bugmann Roger, IT226		1.2		10.09.10	Insert Serverliste auf Centralserver P95_DBA_Reports
-- Bugmann Roger, IT226		1.3		10.01.11	Delete aus Serverliste
-- Bugmann Roger, IT226		1.4		10.06.15	EXEC USP_CONFIG_TRACKER hinzugefügt
-- Bugmann Roger, IT226		1.5		18.08.15	Execute Prozeduren eigene Steps erstellt
-- Bildik Melih, IT222		1.6		23.09.15	No_Backup check eingebaut
---------------------------------------------------------------------------------


-- job erstellen SYS_BACKUP_CHECK
USE [msdb]
GO


IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SYS_BACKUP_CHECK')
EXEC msdb.dbo.sp_delete_job @job_name = N'SYS_BACKUP_CHECK' , @delete_unused_schedule=1
GO
USE [msdb]
GO

/****** Object:  Job [SYS_BACKUP_CHECK]    Script Date: 18.08.2015 14:31:34 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 18.08.2015 14:31:34 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_BACKUP_CHECK', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Dieser Job erfasst alle Datenbanken, welche seit 1 Tag keinen Backup mehr hatten,
Die Daten werden auf dem CentralServer erfasst', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Backup Daten erfassen und schreiben]    Script Date: 18.08.2015 14:31:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup Daten erfassen und schreiben', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'delete from [CENTRALSERVER].[P95_DBAReports].[dbo].[backuplog]
where [Server] = @@SERVERNAME
and Datum < GETDATE()

insert into [CENTRALSERVER].[P95_DBAReports].[dbo].[backuplog]([Server],Datenbankname,LastBackup,Datum,type,ReadOnly)
select @@SERVERNAME, s.name,b.backup_start_date,GETDATE(),type,s.is_read_only
        from     sys.databases        s
                LEFT OUTER JOIN msdb..backupset b
                ON s.name = b.database_name
                AND b.backup_start_date = (SELECT MAX(backup_start_date)
                                                                        FROM msdb..backupset
                                                                        WHERE database_name = b.database_name
                                                                        AND type != ''L'')         -- full database backups only, not log backups
        WHERE   s.name <> ''tempdb''
        and s.name not in (select dbname from IT2_SysAdmin.dbo.no_backup) -- Die no_backups müssen nicht geschickt werden
        and s.state = 0 
        ORDER BY         s.name', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect SysInfo]    Script Date: 18.08.2015 14:31:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect SysInfo', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC IT2_SysAdmin.dbo.USP_COLLECT_SERVERDATA
GO

', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Config Tracker]    Script Date: 18.08.2015 14:31:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Config Tracker', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC IT2_SysAdmin.dbo.USP_CONFIG_TRACKER
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Longindex Logins Datagrowth]    Script Date: 18.08.2015 14:31:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Longindex Logins Datagrowth', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC IT2_SysAdmin.dbo.USP_GET_LONGINDEXNAME
GO
EXEC IT2_SysAdmin.dbo.USP_GET_LOGINS
GO
EXEC IT2_SysAdmin.dbo.USP_DATAGROWTH
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Failed Jobs]    Script Date: 18.08.2015 14:31:34 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Failed Jobs', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC IT2_SysAdmin.dbo.USP_FAILED_JOBS
GO', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Täglich', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20100608, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE [msdb]
GO

/****** Object:  Job [SYS_NETWORKER_CHECK]    Script Date: 26.11.2014 16:19:02 ******/
IF EXISTS (select name from sysjobs WHERE name = 'SYS_NETWORKER_CHECK')
BEGIN
EXEC msdb.dbo.sp_delete_job @job_name='SYS_NETWORKER_CHECK', @delete_unused_schedule=1
END
GO

/****** Object:  Job [SYS_NETWORKER_CHECK]    Script Date: 22.11.2016 14:27:39 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 22.11.2016 14:27:39 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SYS_NETWORKER_CHECK', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Report Problem]    Script Date: 22.11.2016 14:27:39 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Report Problem', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#----------------------------------------------------------------
# Report Problem to CENTRALSERVER
#----------------------------------------------------------------
# Dieses Script schreibt den Networker Fehler auf Centralserver
# Die Pfad informationen werden aus der IT2_Sysadmin geholt
#----------------------------------------------------------------
# 26.11.14 Roger Bugmann IT222 Erste Version
# 03.12.14 Roger BUgmann IT222 Erweitert mit Abfrage Nobackupfolder
#----------------------------------------------------------------

#Query für den Backupordner
$backupfolder_query = "SELECT value FROM IT2_SysAdmin.[dbo].[t_localsettings] WHERE definition = ''Backup full path''"
#Query für den Fehler welcher in die Tabelle networker_problem auf CENTRALSERVER geschrieben wird
$ok_query = "INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.networker_problem (server,problem,date) select @@SERVERNAME,''backup ok'',GETDATE()"
$errorlog_query = "INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.networker_problem (server,problem,date) select @@SERVERNAME,''existing savenow file'',GETDATE()"
$errorlog_emptyfolder_query = "INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.networker_problem (server,problem,date) select @@SERVERNAME,''emtpy backupfolder'',GETDATE()"
$delete_query = "DELETE FROM CENTRALSERVER.P95_DBAReports.dbo.noBackupFolder where server=@@SERVERNAME"

$backupfolder = (Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $backupfolder_query |Format-Table -HideTableHeaders |Out-String).Trim() #select-object -expand value


$backupfolderBak = $backupfolder+''\*.bak''
$backupfolderFile = $backupfolder+''\savenow''
$today = (Get-Date -format dd-MM-yy)
$NoBackupFolder = $backupfolder.Replace(''\Backup\Backup'',''\Backup'')+''\noNetworkBackup*''
$arraynobackup = @(Get-ChildItem $NoBackupFolder | Select-Object Name -ExpandProperty Name)

IF (Test-Path $backupfolderFile)
{
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $errorlog_query 
return
}

IF(Test-Path $backupfolderBak)
{
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $ok_query 
}
ELSE
{
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $errorlog_emptyfolder_query
}


#IF (Test-Path $NoBackupFolder)
IF ($arraynobackup.Count -ne 0 )
{
    Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $delete_query
    foreach ($NoBackupFolder in $arraynobackup)
    {
    $folder_query = "INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.noBackupFolder (server,folder) select @@SERVERNAME, ''$NoBackupFolder''"
    Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $folder_query
    }
}
ELSE 
{
Invoke-Sqlcmd -ServerInstance "$(ESCAPE_SQUOTE(SRVR))" -Query $delete_query   
}


', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'networker_8_oclock_check', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20141126, 
		@active_end_date=99991231, 
		@active_start_time=80000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'networker_955_oclock_check', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20161122, 
		@active_end_date=99991231, 
		@active_start_time=95500, 
		@active_end_time=235959 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO