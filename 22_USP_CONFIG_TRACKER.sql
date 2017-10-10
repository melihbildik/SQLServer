USE [IT2_SysAdmin]
GO

-- 22 Procedure USP_CONFIG_TRACKER
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name LIKE 'USP_CONFIG_TRACKER') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_CONFIG_TRACKER','$(pstdvers)',GETDATE(),'1.05')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.05', modified = GETDATE() WHERE tab_proc_name = 'USP_CONFIG_TRACKER'
GO
PRINT '---------------------------------------
22 create [USP_CONFIG_TRACKER]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_CONFIG_TRACKER' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_CONFIG_TRACKER]
GO

CREATE PROCEDURE [dbo].[USP_CONFIG_TRACKER]
-----------------------------------------------------------------------
-- USP_CONFIG_TRACKER
-----------------------------------------------------------------------
-- Projekt Beschreibung
-----------------------------------------------------------------------
-- Database:              IT2_SysAdmin
-- Version:               1.0
-- Date:                  07.05.2015
-- Autor:                 Kunabalasingam Kaureesan - Hauri
-- Copyright:             Die Schweizerische Post
-----------------------------------------------------------------------
-- Parameter:
-- ==========
-- Parameter der Prozedur aufzählen und beschreiben
-----------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor						Version	Date		What
-- Kunabalasingam Kaureesan		1.00	07.05.2015	Erstellung der Prozedur
-- Kunabalasingam Kaureesan		1.01	18.05.2015	Ergänzung - Bereinigung IT2_SysAdmin Tables: Älter als 90 Tage
-- Kunabalasingam Kaureesan		1.02	21.05.2015	Ergänzung - Cluster Part - Initial Tables FILEGROUPS
-- Bugmann Roger				1.03	02.07.2015  Die Upload Statements in Variabeln verpackt
-- Kunabalasingam Kaureesan		1.04	23.11.2016	Die Variable "@version" SQL Server 2016 tauglich gemacht
--										23.11.2016  Änderungen an den Jobschedules verfolgen
--										23.11.2016	SQL Server 2016 besitzt ein neues Attribut "is_autogrow_all_files" in der Tabelle "sys.filegroups". Diese wird beim Upload, auf den CENTRALSERVER entfernt.
-- Kunabalasingam Kaureesan		1.05	16.03.2017	Folgende CIS Informationen werden neu gesammelt: Über verweiste Benutzer und über CLR ASSEMBLY

-----------------------------------------------------------------------

AS
BEGIN

-- ----------------------------------------------------------------------------------------------
-- DECLARATION Variables 
-- ----------------------------------------------------------------------------------------------
  DECLARE @version NVARCHAR(25)
  DECLARE @dbname NVARCHAR (150)
  DECLARE @stmt  NVARCHAR(4000)

-- ------------------------------------------------------------------------------------------------
--	Serverversion
-- ------------------------------------------------------------------------------------------------
  SET @version = CONVERT(sysname,SERVERPROPERTY('ProductVersion'))

  SELECT @version = CASE
		WHEN @version LIKE '13.0%' THEN '2016'
		WHEN @version LIKE '12.0%' THEN '2014'
		WHEN @version LIKE '11.0%' THEN '2012'
		WHEN @version LIKE '10.%' THEN '2008'
		WHEN @version LIKE '9.0%' THEN '2005'
	END
	
-- ----------------------------------------------------------------------------------------------
--	CHECK Connection - CENTRALSERVER
-- ----------------------------------------------------------------------------------------------
  EXEC sp_testlinkedserver CENTRALSERVER

  BEGIN TRY
  
-- ----------------------------------------------------------------------------------------------
--	INITIAL Table - IT2_Sysadmin 
-- ----------------------------------------------------------------------------------------------
----  CREATE IT2_SysAdmin.dbo.server_configurations & ADD Column Changedate 
--  IF  NOT EXISTS (SELECT * FROM sys.objects 
--		WHERE object_id = OBJECT_ID(N'[dbo].[server_configurations]') AND type in (N'U'))
--  SELECT *,GETDATE() as changedate INTO IT2_SysAdmin.dbo.server_configurations FROM sys.configurations

----  CREATE IT2_SysAdmin.dbo.server_databases & ADD Column Changedate
--  IF  NOT EXISTS (SELECT * FROM sys.objects 
--		WHERE object_id = OBJECT_ID(N'[dbo].[server_databases]') AND type in (N'U'))
--  SELECT *,GETDATE() as changedate INTO IT2_SysAdmin.dbo.server_databases FROM sys.databases

---- CREATE IT2_SysAdmin.dbo.server_datafiles & ADD Column Insertdate
--  IF  NOT EXISTS (SELECT * FROM sys.objects 
--		WHERE object_id = OBJECT_ID(N'[dbo].[server_datafiles]') AND type in (N'U'))
--  SELECT DB_NAME(database_id) AS database_name, database_id, [file_id], type_desc, data_space_id, name AS logical_file_name, physical_name, (SIZE*8/1024) AS size_mb, 
--			CASE max_size
--                 WHEN -1 THEN 'unlimited'
--                 ELSE CAST((CAST (max_size AS BIGINT)) * 8 / 1024 AS VARCHAR(10))
--			END AS max_size_mb,
--			CASE is_percent_growth
--                 WHEN 1 THEN CAST(growth AS VARCHAR(3)) + ' %'
--                 WHEN 0 THEN CAST(growth*8/1024 AS VARCHAR(10)) + ' mb'
--			END AS growth_increment,
--			is_percent_growth, GETDATE() as changedate
--  INTO IT2_SysAdmin.dbo.server_datafiles
--  FROM sys.master_files
--  ORDER BY 1, type_desc DESC, [file_id];

--  CREATE IT2_SysAdmin.dbo.server_filegroups & ADD Column Insertdate
--  USE IT2_SysAdmin
--  IF  NOT EXISTS (SELECT * FROM sys.objects 
--		WHERE object_id = OBJECT_ID(N'[dbo].[server_filegroups]') AND type in (N'U'))
--		BEGIN
--			SELECT 'IT2_Sysadmin' as [database], *, GETDATE() as changedate INTO server_filegroups FROM IT2_SysAdmin.sys.filegroups
--			ALTER TABLE server_filegroups
--			ALTER COLUMN [database] varchar(150)
			
--			IF @version >= 2012
--			BEGIN
--			DECLARE db_cursor CURSOR FOR
--				SELECT name FROM sys.databases
--						WHERE (state_desc = 'Online' AND name NOT IN ('IT2_SysAdmin') AND name NOT IN (
--							SELECT DISTINCT
--							dbcs.database_name AS [DatabaseName]
--							FROM master.sys.availability_groups AS AG
--							LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
--							ON AG.group_id = agstates.group_id
--							INNER JOIN master.sys.availability_replicas AS AR
--							ON AG.group_id = AR.group_id
--							INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
--							ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
--							INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
--							ON arstates.replica_id = dbcs.replica_id
--							LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
--							ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
--							WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1
--						)) 
--			END
--			ELSE
--			BEGIN
--				DECLARE db_cursor CURSOR FOR
--					SELECT name FROM sys.databases
--						WHERE (state_desc = 'Online' AND name NOT IN ('IT2_SysAdmin') )
--			END
						
--			OPEN db_cursor   
--				FETCH NEXT FROM db_cursor INTO @dbname   
--				WHILE @@FETCH_STATUS = 0
--				BEGIN
--					SET @stmt = 'INSERT INTO IT2_SysAdmin.dbo.server_filegroups SELECT '''+@dbname+''',*, GETDATE() FROM ['+@dbname+'].sys.filegroups'
--					EXEC (@stmt)
--					FETCH NEXT FROM db_cursor INTO @dbname
--				END
--			CLOSE db_cursor   
--			DEALLOCATE db_cursor
--		END
--
--  CREATE IT2_SysAdmin.dbo.job_schedule & ADD Column Insertdate
--  IF  NOT EXISTS (SELECT * FROM sys.objects 
--		WHERE object_id = OBJECT_ID(N'[dbo].[job_schedule]') AND type in (N'U'))
--  SELECT SJ.name as 'job_name', SS.schedule_id, SS.name as 'schedule_name', SS.[enabled] as 'job_enabled', SS.freq_type, SS.freq_interval, SS.freq_subday_type ,SS.freq_subday_interval, SS.freq_relative_interval, SS.freq_recurrence_factor, 
--   SS.active_start_date, SS.active_end_date, SS.active_start_time, SS.active_end_time, SS.date_created, SS.schedule_uid, GETDATE() as changedate
--   INTO IT2_SysAdmin.dbo.job_schedule
--  FROM msdb.dbo.sysschedules AS SS
--	  INNER JOIN [msdb].[dbo].[sysjobschedules] as SJS
--		  on SS.schedule_id = SJS.schedule_id
--	  INNER JOIN [msdb].[dbo].[sysjobs] SJ
--		  on SJ.job_id = SJS.job_id
--  WHERE SJ.name LIKE 'SYS%' 
--	  AND SJ.name NOT IN ('syspolicy_purge_history')

-- ------------------------------------------------------------------------------------------------
--	REMOVE - Old Entries - FROM IT2_SysAdmin Tables
-- ------------------------------------------------------------------------------------------------
DELETE FROM IT2_SysAdmin.dbo.server_configurations  WHERE changedate < DATEADD(day, -90, GETDATE())
DELETE FROM IT2_SysAdmin.dbo.server_databases  WHERE changedate < DATEADD(day, -90, GETDATE())
DELETE FROM IT2_SysAdmin.dbo.server_datafiles  WHERE changedate < DATEADD(day, -90, GETDATE())
DELETE FROM IT2_SysAdmin.dbo.server_filegroups  WHERE changedate < DATEADD(day, -90, GETDATE())
DELETE FROM IT2_SysAdmin.dbo.job_schedule  WHERE changedate < DATEADD(day, -90, GETDATE())

-- ------------------------------------------------------------------------------------------------
--	COMPARE - Configurations - ADD Differences
-- ------------------------------------------------------------------------------------------------
  /* CONTROL - TABLE EXISTS*/
  IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[server_configurations]') AND type in (N'U'))
  BEGIN

  SELECT sc.* INTO #server_configurations_temp FROM server_configurations AS sc 
	INNER JOIN
			(SELECT name, MAX(changedate) AS Maxchangedate
			FROM server_configurations
			GROUP BY name) AS groupedsc
	ON sc.name = groupedsc.name
	AND sc.changedate = groupedsc.Maxchangedate
	ALTER TABLE #server_configurations_temp DROP COLUMN changedate	
	
  INSERT INTO server_configurations
  SELECT *,GETDATE() FROM sys.configurations
  EXCEPT
  SELECT *,GETDATE() FROM #server_configurations_temp

  DROP TABLE #server_configurations_temp

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - Configurations - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = '
  DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[server_configurations_new] WHERE server = @@SERVERNAME
		
  INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[server_configurations_new]
  SELECT @@SERVERNAME AS servername ,sc.* FROM server_configurations AS sc 
	INNER JOIN
			(SELECT name, MAX(changedate) AS Maxchangedate
			FROM server_configurations
			GROUP BY name) AS groupedsc
	ON sc.name = groupedsc.name
	AND sc.changedate = groupedsc.Maxchangedate
  '
  EXEC (@stmt)
  END

-- ------------------------------------------------------------------------------------------------
--	COMPARE - Databases - ADD Differences
-- ------------------------------------------------------------------------------------------------
  /* CONTROL - TABLE EXISTS*/
  IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[server_databases]') AND type in (N'U'))
  BEGIN

  SELECT sd.* INTO #server_databases_temp FROM server_databases sd
       INNER JOIN
             (SELECT name, MAX(changedate) AS Maxchangedate
             FROM server_databases 
             GROUP BY name) groupedsd
       ON sd.name = groupedsd.name
       AND sd.changedate = groupedsd.Maxchangedate 
       ALTER TABLE #server_databases_temp DROP COLUMN changedate

  INSERT INTO server_databases
  SELECT *,GETDATE() FROM sys.databases
  EXCEPT
  SELECT *,GETDATE() FROM #server_databases_temp

  DROP TABLE #server_databases_temp

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - Databases - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = 'DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[server_databases_'+@version+'_new] WHERE server = @@SERVERNAME'
  EXEC (@stmt)

  SET @stmt = 'INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[server_databases_'+@version+'_new] 
  SELECT @@SERVERNAME AS servername, sd.* FROM server_databases sd
       INNER JOIN
             (SELECT name, MAX(changedate) AS Maxchangedate
             FROM server_databases 
             GROUP BY name) groupedsd
       ON sd.name = groupedsd.name
       AND sd.changedate = groupedsd.Maxchangedate' 
  EXEC (@stmt)
  END

-- ------------------------------------------------------------------------------------------------
--	COMPARE - Master_files - ADD Differences
-- ------------------------------------------------------------------------------------------------
  /* CONTROL - TABLE EXISTS*/
  IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[server_datafiles]') AND type in (N'U'))
  BEGIN

  SELECT sd.* INTO #server_master_files_temp FROM server_datafiles sd
       INNER JOIN
             (SELECT logical_file_name, MAX(changedate) AS Maxchangedate
             FROM server_datafiles 
             GROUP BY logical_file_name) groupedsd
       ON sd.logical_file_name = groupedsd.logical_file_name
       AND sd.changedate = groupedsd.Maxchangedate 
       ALTER TABLE #server_master_files_temp DROP COLUMN changedate

  INSERT INTO server_datafiles
  SELECT DB_NAME(database_id) AS database_name, database_id, [file_id], type_desc, data_space_id, name AS logical_file_name, physical_name, (SIZE*8/1024) AS size_mb, 
		CASE max_size
            WHEN -1 THEN 'unlimited'
            ELSE CAST((CAST (max_size AS BIGINT)) * 8 / 1024 AS VARCHAR(10))
		END AS max_size_mb,
		CASE is_percent_growth
            WHEN 1 THEN CAST(growth AS VARCHAR(3)) + ' %'
            WHEN 0 THEN CAST(growth*8/1024 AS VARCHAR(10)) + ' mb'
		END AS growth_increment,
			is_percent_growth, GETDATE() as changedate
		FROM sys.master_files
  EXCEPT
  SELECT *,GETDATE() FROM #server_master_files_temp

  DROP TABLE #server_master_files_temp

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - Master_files - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = '
  DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[server_datafiles_new] WHERE server = @@SERVERNAME

  INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[server_datafiles_new]
  SELECT @@SERVERNAME AS servername, sd.* FROM server_datafiles sd
       INNER JOIN
             (SELECT logical_file_name, MAX(changedate) AS Maxchangedate
             FROM server_datafiles 
             GROUP BY logical_file_name) groupedsd
       ON sd.logical_file_name = groupedsd.logical_file_name
       AND sd.changedate = groupedsd.Maxchangedate
  '
  EXEC (@stmt)
  END

-- ------------------------------------------------------------------------------------------------
--	COMPARE - Filegroups - ADD Differences
-- ------------------------------------------------------------------------------------------------
  /* CONTROL - TABLE EXISTS*/
  IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[server_filegroups]') AND type in (N'U'))
  BEGIN

  SELECT sf.* INTO #server_filegroups_temp FROM server_filegroups sf
       INNER JOIN
             (SELECT [database], name, MAX(changedate) AS Maxchangedate
             FROM server_filegroups 
             GROUP BY [database], name) groupedsd
       ON sf.[database] = groupedsd.[database]
	   AND sf.name = groupedsd.name
       AND sf.changedate = groupedsd.Maxchangedate 
       ALTER TABLE #server_filegroups_temp DROP COLUMN changedate
	   
  SELECT * INTO #server_filegroups FROM #server_filegroups_temp WHERE 1=2
  
  IF @version >= 2012
  BEGIN
  DECLARE db_cursor CURSOR FOR
  SELECT name FROM sys.databases
	WHERE state_desc = 'Online' AND name NOT IN (
			SELECT DISTINCT
			dbcs.database_name AS [DatabaseName]
			FROM master.sys.availability_groups AS AG
			LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
			ON AG.group_id = agstates.group_id
			INNER JOIN master.sys.availability_replicas AS AR
			ON AG.group_id = AR.group_id
			INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
			ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
			INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
			ON arstates.replica_id = dbcs.replica_id
			LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
			ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
			WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1
			)
  END
  ELSE
  BEGIN
	DECLARE db_cursor CURSOR FOR
	SELECT name FROM sys.databases
	WHERE state_desc = 'Online'
  END
		OPEN db_cursor   
		FETCH NEXT FROM db_cursor INTO @dbname 
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @stmt = 'INSERT INTO #server_filegroups SELECT '''+@dbname+''',* FROM ['+@dbname+'].sys.filegroups'
			EXEC (@stmt)
		FETCH NEXT FROM db_cursor INTO @dbname
		END
	CLOSE db_cursor   
  DEALLOCATE db_cursor

  INSERT INTO server_filegroups
  SELECT *, GETDATE() FROM #server_filegroups
  EXCEPT
  SELECT *, GETDATE() FROM #server_filegroups_temp

  DROP TABLE #server_filegroups
  DROP TABLE #server_filegroups_temp

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - Filegroups - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = 'DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[server_filegroups_new] WHERE server = @@SERVERNAME'
  EXEC (@stmt)
  SELECT * INTO #server_filegroups_INSERT FROM server_filegroups
  IF EXISTS (SELECT * FROM tempdb.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = N'is_system' AND TABLE_NAME like '#server_filegroups_INSERT%')
  BEGIN
	ALTER TABLE #server_filegroups_INSERT DROP COLUMN is_system
  END
  
  IF EXISTS (SELECT * FROM tempdb.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = N'is_autogrow_all_files' AND TABLE_NAME like '#server_filegroups_INSERT%')
  BEGIN
	ALTER TABLE #server_filegroups_INSERT DROP COLUMN is_autogrow_all_files
  END

  SET @stmt = 'INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[server_filegroups_new]
  SELECT @@SERVERNAME AS servername, sf.* FROM #server_filegroups_INSERT sf
       INNER JOIN
             (SELECT [database], name, MAX(changedate) AS Maxchangedate
             FROM server_filegroups 
             GROUP BY [database], name) groupedsd
       ON sf.[database] = groupedsd.[database]
	   AND sf.name = groupedsd.name
       AND sf.changedate = groupedsd.Maxchangedate'
  EXEC (@stmt)
  DROP TABLE #server_filegroups_INSERT
  END

-- ------------------------------------------------------------------------------------------------
--	COMPARE - Job_schedules - ADD Differences
-- ------------------------------------------------------------------------------------------------
SELECT js.* INTO #job_schedule_temp FROM IT2_SysAdmin.dbo.job_schedule as js
INNER JOIN
	(SELECT job_name, schedule_name, MAX(changedate) AS Maxchangedate 
	FROM IT2_SysAdmin.dbo.job_schedule
	GROUP BY job_name, schedule_name) as groupedjs
	ON js.job_name = groupedjs.job_name
	AND js.schedule_name = groupedjs.schedule_name
	AND js.changedate = groupedjs.Maxchangedate
	ALTER TABLE #job_schedule_temp DROP COLUMN changedate

INSERT INTO IT2_SysAdmin.dbo.job_schedule
SELECT SJ.name as 'job_name', SS.schedule_id, SS.name as 'schedule_name', SS.[enabled] as 'job_enabled', SS.freq_type, SS.freq_interval, SS.freq_subday_type ,SS.freq_subday_interval, SS.freq_relative_interval, SS.freq_recurrence_factor, 
 SS.active_start_date, SS.active_end_date, SS.active_start_time, SS.active_end_time, SS.date_created, SS.schedule_uid, GETDATE() 
 FROM msdb.dbo.sysschedules AS SS
	INNER JOIN [msdb].[dbo].[sysjobschedules] as SJS
		on SS.schedule_id = SJS.schedule_id
	INNER JOIN [msdb].[dbo].[sysjobs] SJ
		on SJ.job_id = SJS.job_id
WHERE SJ.name LIKE 'SYS%' 
	AND SJ.name NOT IN ('syspolicy_purge_history')
EXCEPT
SELECT *, GETDATE() FROM #job_schedule_temp

DROP TABLE #job_schedule_temp

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - Job_schedules - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = '
  DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule] WHERE server = @@SERVERNAME

  INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
  SELECT @@SERVERNAME AS servername, js.* FROM IT2_SysAdmin.dbo.job_schedule as js
	INNER JOIN
			(SELECT job_name, schedule_name, MAX(changedate) AS Maxchangedate 
			FROM IT2_SysAdmin.dbo.job_schedule
			GROUP BY job_name, schedule_name) as groupedjs
	ON js.job_name = groupedjs.job_name
	AND js.schedule_name = groupedjs.schedule_name
	AND js.changedate = groupedjs.Maxchangedate
  '
  EXEC (@stmt)
  
-- ------------------------------------------------------------------------------------------------
--	GET - ORPHANDED_USERS - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  IF OBJECT_ID('tempdb..#orphaned_users') IS NOT NULL
	DROP TABLE #orphaned_users
  CREATE TABLE [#orphaned_users](
		[instance_name] [nvarchar](128) NULL,
		[db_name] [nvarchar](128) NULL,
		[user_name] [sysname] NOT NULL,
		[SID] [varbinary](85) NULL) 

-- Get all ONLINE databases
  IF @version >= 2012
  BEGIN
		  DECLARE db_cursor CURSOR FOR
		  SELECT name FROM sys.databases
			WHERE state_desc = 'Online' AND name NOT IN (
					SELECT DISTINCT
					dbcs.database_name AS [DatabaseName]
					FROM master.sys.availability_groups AS AG
					LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states AS agstates
					ON AG.group_id = agstates.group_id
					INNER JOIN master.sys.availability_replicas AS AR
					ON AG.group_id = AR.group_id
					INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
					ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
					INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
					ON arstates.replica_id = dbcs.replica_id
					LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
					ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
					WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1
					)
  END
  ELSE
  BEGIN
			DECLARE db_cursor CURSOR FOR
			SELECT name FROM sys.databases
			WHERE state_desc = 'ONLINE'
  END

-- Foreach database, create entries
  IF @version >= 2012
  BEGIN
	  OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @dbname 
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @stmt = '
				USE ['+@dbname+']
				INSERT INTO [#orphaned_users](
				[instance_name],
				[db_name],
				[user_name],
				[SID]
				) 
					SELECT @@SERVERNAME AS ''instance_name'', DB_NAME() AS ''db_name'', dp.name AS user_name, dp.SID
					FROM sys.database_principals AS dp  
					LEFT JOIN sys.server_principals AS sp  
						ON dp.SID = sp.SID  
					WHERE sp.SID IS NULL  
						AND authentication_type_desc = ''INSTANCE''
				'
				EXEC (@stmt)
			FETCH NEXT FROM db_cursor INTO @dbname
			END
	  CLOSE db_cursor   
	  DEALLOCATE db_cursor
  END
  ELSE
  BEGIN
	  OPEN db_cursor   
			FETCH NEXT FROM db_cursor INTO @dbname 
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @stmt = '
				USE ['+@dbname+']
				INSERT INTO [#orphaned_users](
				[instance_name],
				[db_name],
				[user_name],
				[SID]
				) 
					SELECT @@SERVERNAME AS ''instance_name'', DB_NAME() AS ''db_name'', name AS ''user_name'', [sid] AS ''SID'' 
					FROM sys.sysusers 
						WHERE issqluser = 1 AND 
							([sid] IS NOT NULL AND sid <> 0x0) AND 
							(LEN([sid]) <= 16) AND SUSER_SNAME([sid]) IS NULL
				'
				EXEC (@stmt)
			FETCH NEXT FROM db_cursor INTO @dbname
			END
	  CLOSE db_cursor   
	  DEALLOCATE db_cursor
  END

-- ------------------------------------------------------------------------------------------------
--	UPLOAD - ORPHANDED_USERS - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = 'DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[cis_orphaned_users] WHERE [instance_name] = @@SERVERNAME
  
			INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[cis_orphaned_users] (
			[instance_name]
           ,[db_name]
           ,[user_name]
           ,[SID])
		   SELECT * FROM #orphaned_users'
  
  EXEC (@stmt)

  IF OBJECT_ID('tempdb..#orphaned_users') IS NOT NULL
		DROP TABLE #orphaned_users
		
-- ------------------------------------------------------------------------------------------------
--	GET & UPLOAD - CLR_ASSEMBLY - CENTRALSERVER
-- ------------------------------------------------------------------------------------------------
  SET @stmt = 'DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[cis_clr_assembly] WHERE [server] = @@SERVERNAME

			   INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[cis_clr_assembly]
						   ([server]
						   ,[name]
						   ,[permission_set_desc])
			   SELECT @@SERVERNAME as ''server'', name, permission_set_desc
					FROM sys.assemblies 
					WHERE is_user_defined = 1
						AND permission_set_desc NOT LIKE ''SAFE_ACCESS'''
  
  EXEC (@stmt)
    
  
--END OF ERROR HANDLING
  END TRY
  BEGIN CATCH
		INSERT INTO [IT2_SysAdmin].[dbo].[logs](db, [message], action_time,[type],[source]) 
		VALUES('IT2_SysAmin', ERROR_MESSAGE(), GETDATE(),'ERROR','CONFIG_TRACKER') 
		PRINT ERROR_MESSAGE()
  END CATCH
  
END
GO
