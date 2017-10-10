USE IT2_SysAdmin
GO
-- 21 Procedure USP_DATAGROWTH
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_DATAGROWTH') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_DATAGROWTH','$(pstdvers)',GETDATE(),'1.03')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.03', modified = GETDATE() WHERE tab_proc_name = 'USP_DATAGROWTH'
GO
PRINT '---------------------------------------
21 create [USP_DATAGROWTH]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_DATAGROWTH' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_DATAGROWTH]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure USP_DATAGROWTH
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_DATAGROWTH
-- ------------------------------------------------------------------
-- Object Name:           USP_DATAGROWTH
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  31.01.13
-- Autor:                 Roger Bugmann, IT226  (Nicholas Williams)
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Die Prozedur f?gt das Datenwachstum in die Tabelle sqldatagrowth auf dem Centralserver ein
-- 
/*
Author:	Nicholas Williams
Date:	3rd February 2008
Desc:	Calculates Growth Info for all databases on a server that are being backed up. Relies on the backup tables, and as a result will only contain as many
		days history as do the backup tables(@iNoSamples). If a database is not being backup up the results will be NULL. (For example the Tempdb)
		This is a rewrite of something I did a few years ago, as I dont know where I saved the other code. bummer.
Email:	Nicholas.Williams@reagola.com	
*/
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
--
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor					Version		Date		What
-- Roger Bugmann, IT226		1.00		30.01.2013	erste Version
-- Roger Bugmann, IT226		1.01		21.02.2013	Anpassung für HA Gruppen (2012)
-- Roger Bugmann, IT226		1.02		27.04.2015	Abfrage ProdctVersion >= 11.% in Cursor für Datenbanken ab SQL Server 2012
-- Roger Bugmann, IT226		1.03		27.04.2015	DELETE und INSERT auf Centralserver in "EXECUTE" verpackt
-- ------------------------------------------------------------------------------------------------
AS

CREATE TABLE ##tbl_DataSize
		(
		Size	DECIMAL(20)
		)

CREATE TABLE #tbl_GrowthData
		(
		 DatabaseName					VARCHAR(150)
		,Begin_Date				       datetime
		,End_Date				       datetime
		,NoSampleDays					DECIMAL(20,3)
		,DataSizeMB					DECIMAL(20,3)
		,LogSizeMB					DECIMAL(20,3)
		,BackupSizeMB					DECIMAL(20,3)
		,TotalSpaceMB					DECIMAL(20,3)
		,DataGrowth					DECIMAL(20,3)
		,LogGrowth					DECIMAL(20,3)
		,GrowthPercentage				DECIMAL(20,3)
		)

DECLARE 
	 @iNoSamples		INT
	,@nMaxBackupSize	DECIMAL
	,@nMinBackupSize	DECIMAL
	,@nMaxLogSize		DECIMAL
	,@nMinLogSize		DECIMAL
	,@nMaxDataSize		DECIMAL
	,@nMinDataSize		DECIMAL
	,@vcDatabaseName	VARCHAR(150)
	,@dtMaxBackupTime	DATETIME
	,@dtMinBackupTime	DATETIME
	,@iMinBackupID		INT
	,@iMaxBackupID		INT

EXECUTE (' DELETE CENTRALSERVER.P95_DBAReports.dbo.sqldatagrowth where server=@@SERVERNAME ')

IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%'	
	BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
		DECLARE file_cursor CURSOR FOR
			SELECT name FROM sys.databases
						WHERE state = 0
						AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
						OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
															JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
															WHERE primary_replica = @@SERVERNAME)
			ORDER BY 1 
	END
ELSE
	BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
		DECLARE file_cursor CURSOR FOR
			SELECT name FROM sys.databases  
						WHERE state = 0
			ORDER BY 1 
	END
	
OPEN file_cursor

   FETCH NEXT FROM file_cursor INTO @vcDatabaseName

WHILE @@FETCH_STATUS = 0
BEGIN  

SET @dtMaxBackupTime = (SELECT MAX(backup_finish_date)FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D')
SET @dtMinBackupTime = (SELECT MIN(backup_finish_date)FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D')
SET @iNoSamples =	
	DATEDIFF 
		( 
		  dd
		 ,@dtMinBackupTime
		 ,@dtMaxBackupTime
		)

SET @nMaxBackupSize	= (SELECT backup_size FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D' AND backup_finish_date = @dtMaxBackupTime)
SET @nMinBackupSize	= (SELECT backup_size FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D' AND backup_finish_date = @dtMinBackupTime)

SET @iMaxBackupID	= (SELECT MAX(backup_set_id) FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D' AND backup_finish_date = @dtMaxBackupTime)
SET @iMinBackupID	= (SELECT MAX(backup_set_id) FROM msdb.dbo.backupset WHERE database_name = @vcDatabaseName AND [type] = 'D' AND backup_finish_date = @dtMinBackupTime)

SET @nMaxLogSize	= (SELECT ((CAST((SUM(file_size)) AS DECIMAL(20,3))) /  1048576) FROM msdb.dbo.backupfile	WHERE backup_set_id = @iMaxBackupID AND file_type = 'L')
SET @nMinLogSize	= (SELECT ((CAST((SUM(file_size)) AS DECIMAL(20,3))) /  1048576) FROM msdb.dbo.backupfile	WHERE backup_set_id = @iMinBackupID AND file_type = 'L')
SET @nMaxDataSize	= (SELECT ((CAST((SUM(file_size)) AS DECIMAL(20,3))) /  1048576) FROM msdb.dbo.backupfile	WHERE backup_set_id = @iMaxBackupID AND file_type = 'D')
SET @nMinDataSize	= (SELECT ((CAST((SUM(file_size)) AS DECIMAL(20,3))) /  1048576) FROM msdb.dbo.backupfile	WHERE backup_set_id = @iMinBackupID AND file_type = 'D')

EXEC ('
INSERT INTO ##tbl_DataSize
SELECT CAST((SUM(size)) as DECIMAL(20,3)) FROM ['+@vcDatabaseName+'].dbo.sysfiles'
)

INSERT INTO #tbl_GrowthData
	SELECT
		@vcDatabaseName DatabaseName
		,@dtMinBackupTime Begin_Date
		,@dtMaxBackupTime End_Date
		,@iNoSamples NoSampleDays
		,@nMaxDataSize
		,@nMaxLogSize
		,@nMaxBackupSize / 1048576
		,((Size * 8192) / 1048576) TotalSpaceUsed  
		,@nMaxDataSize - @nMinDataSize
		,@nMaxLogSize  - @nMinLogSize
		,(((@nMaxDataSize + @nMaxLogSize) - (@nMinDataSize+ @nMinLogSize)) / (@nMinDataSize+ @nMinLogSize)) * 100.00
	FROM ##tbl_DataSize

	TRUNCATE TABLE ##tbl_DataSize

   FETCH NEXT FROM file_cursor INTO @vcDatabaseName

END
CLOSE file_cursor
DEALLOCATE file_cursor

EXECUTE (' INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.sqldatagrowth 
(server,databasename,begin_date,end_date,nosampledays,datasize_mb,logsize_mb,backupsize_mb,totalspace_mb,datagrowth,loggrowth,growthpercentage)
	SELECT @@SERVERNAME,*
	FROM #tbl_GrowthData ')

DROP TABLE ##tbl_DataSize
DROP TABLE #tbl_GrowthData

SET NOCOUNT OFF
-- ------------------------------------------------------------------------------------------------
-- END procedure exec USP_DATAGROWTH
-- ------------------------------------------------------------------------------------------------
GO 