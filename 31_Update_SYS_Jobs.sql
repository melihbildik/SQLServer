print '---------------------------'
print '31 Update SYS JOBs '
print '---------------------------'
-- ------------------------------------------------------------------------------------------------
-- Jobs löschen und erstellen
-- ------------------------------------------------------------------------------------------------

-- alten Backupjob löschen
USE [msdb]
GO
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SYS_BACKUP_FULL')
EXEC msdb.dbo.sp_delete_job @job_name =N'SYS_BACKUP_FULL', @delete_unused_schedule=1
GO

-- alten RenameJob löschen
USE [msdb]
GO
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SYS_BACKUP_RENAME')
EXEC msdb.dbo.sp_delete_job @job_name=N'SYS_BACKUP_RENAME', @delete_unused_schedule=1
GO

-- alten SYS_GET_CMDB_INFOS löschen
USE [msdb]
GO
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'SYS_GET_CMDB_INFOS')
EXEC msdb.dbo.sp_delete_job @job_name=N'SYS_GET_CMDB_INFOS', @delete_unused_schedule=1
GO

-- SYS_NETWORKER_CHECK - Die Ausführung des Jobs wird ab Poststandards 1.11.XX um 08.00 Uhr und um 09.55 Uhr erfolgen.
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