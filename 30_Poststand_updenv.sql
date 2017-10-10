PRINT '---------------------------------------
30 update [IT2_SysAdmin]
---------------------------------------'
GO

USE IT2_SysAdmin
GO

-- Delete History Tabelle löschen (Backup auf cifs_share Leiche)
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'backup_delete_history') 

		DROP TABLE backup_delete_history;
	
-- Backuplog Tabelle löschen und neu anlegen

DROP TABLE [dbo].[backuplog]

CREATE TABLE [dbo].[backuplog](
	[ID] [int] NULL,
	[Datum] [datetime] NULL,
	[BeginBackup] [datetime] NULL,
	[EndBackup] [datetime] NULL,
	[Duration] [int] NULL
) ON [PRIMARY]

GO

-- Tabelle für Datenbanken ohne Backup 
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'no_backup')
	BEGIN
		CREATE TABLE [dbo].[no_backup](
			[dbname] [varchar](max) NOT NULL,
			[user] [nvarchar](50) NULL,
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
		
		ALTER TABLE [dbo].[no_backup] ADD  CONSTRAINT [DF_no_backup_user]  DEFAULT (suser_sname()) FOR [user]
		
		ALTER TABLE [dbo].[no_backup] ADD  CONSTRAINT [DF_no_backup_insdate]  DEFAULT (getdate()) FOR [insdate]
	END
ELSE IF NOT EXISTS  (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'no_backup' AND COLUMN_NAME ='user')
	BEGIN
		ALTER TABLE [IT2_SysAdmin].[dbo].[no_backup]
			ADD [user] [nvarchar](50) NULL CONSTRAINT [DF_no_backup_user]  DEFAULT (suser_sname()),
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL CONSTRAINT [DF_no_backup_insdate]  DEFAULT (getdate())
	END

-- Tabelle für Datenbanken ohne Rebuild Index 
  IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'no_rebuildindex')
	BEGIN
		CREATE TABLE [dbo].[no_rebuildindex](
			[dbname] [varchar](max) NOT NULL,
			[user] [nvarchar](50) NULL,
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
		
		ALTER TABLE [dbo].[no_rebuildindex] ADD CONSTRAINT [DF_no_rebuildindex_user]  DEFAULT (suser_sname()) FOR [user]
		
		ALTER TABLE [dbo].[no_rebuildindex] ADD CONSTRAINT [DF_no_rebuildindex_insdate]  DEFAULT (getdate()) FOR [insdate]
	END
  ELSE IF NOT EXISTS  (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'no_rebuildindex' AND COLUMN_NAME ='user')
	BEGIN
		ALTER TABLE [IT2_SysAdmin].[dbo].[no_rebuildindex]
			ADD [user] [nvarchar](50) NULL CONSTRAINT [DF_no_rebuildindex_user]  DEFAULT (suser_sname()),
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL CONSTRAINT [DF_no_rebuildindex_insdate]  DEFAULT (getdate())
	END

-- Tabellen für Hardening
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
--	INITIAL Table - IT2_Sysadmin 
-- ----------------------------------------------------------------------------------------------
----  CREATE IT2_SysAdmin.dbo.server_configurations & ADD Column Changedate 
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_configurations]') AND type in (N'U'))
  SELECT *,GETDATE() as changedate INTO IT2_SysAdmin.dbo.server_configurations FROM sys.configurations

----  CREATE IT2_SysAdmin.dbo.server_databases & ADD Column Changedate
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_databases]') AND type in (N'U'))
  SELECT *,GETDATE() as changedate INTO IT2_SysAdmin.dbo.server_databases FROM sys.databases

---- CREATE IT2_SysAdmin.dbo.server_datafiles & ADD Column Insertdate
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_datafiles]') AND type in (N'U'))
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
  INTO IT2_SysAdmin.dbo.server_datafiles
  FROM sys.master_files
  ORDER BY 1, type_desc DESC, [file_id];

--  CREATE IT2_SysAdmin.dbo.server_filegroups & ADD Column Insertdate
--  USE IT2_SysAdmin
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_filegroups]') AND type in (N'U'))
		BEGIN
			SELECT 'IT2_Sysadmin' as [database], *, GETDATE() as changedate INTO server_filegroups FROM IT2_SysAdmin.sys.filegroups
			ALTER TABLE server_filegroups
			ALTER COLUMN [database] varchar(150)
			
			IF @version >= 2012
			BEGIN
			DECLARE db_cursor CURSOR FOR
				SELECT name FROM sys.databases
						WHERE (state_desc = 'Online' AND name NOT IN ('IT2_SysAdmin') AND name NOT IN (
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
						)) 
			END
			ELSE
			BEGIN
				DECLARE db_cursor CURSOR FOR
					SELECT name FROM sys.databases
						WHERE (state_desc = 'Online' AND name NOT IN ('IT2_SysAdmin') )
			END
						
			OPEN db_cursor   
				FETCH NEXT FROM db_cursor INTO @dbname   
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @stmt = 'INSERT INTO IT2_SysAdmin.dbo.server_filegroups SELECT '''+@dbname+''',*, GETDATE() FROM ['+@dbname+'].sys.filegroups'
					EXEC (@stmt)
					FETCH NEXT FROM db_cursor INTO @dbname
				END
			CLOSE db_cursor   
			DEALLOCATE db_cursor
END	

--  CREATE IT2_SysAdmin.dbo.job_schedule & ADD Column Insertdate
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[job_schedule]') AND type in (N'U'))
  SELECT SJ.name as 'job_name', SS.schedule_id, SS.name as 'schedule_name', SS.[enabled] as 'job_enabled', SS.freq_type, SS.freq_interval, SS.freq_subday_type ,SS.freq_subday_interval, SS.freq_relative_interval, SS.freq_recurrence_factor, 
		 SS.active_start_date, SS.active_end_date, SS.active_start_time, SS.active_end_time, SS.date_created, SS.schedule_uid, GETDATE() as changedate
  INTO IT2_SysAdmin.dbo.job_schedule
  FROM msdb.dbo.sysschedules AS SS
	  INNER JOIN [msdb].[dbo].[sysjobschedules] as SJS
		  on SS.schedule_id = SJS.schedule_id
	  INNER JOIN [msdb].[dbo].[sysjobs] SJ
		  on SJ.job_id = SJS.job_id
  WHERE SJ.name LIKE 'SYS%' 
	  AND SJ.name NOT IN ('syspolicy_purge_history')

-- Table for database used and free space
  IF NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[database_size]') AND type in (N'U'))
	BEGIN
	CREATE TABLE [IT2_SysAdmin].[dbo].[database_size]
	(
		[server] [nvarchar](150) NULL,
		[database] [nvarchar](130) NULL,
		[db_size_in_mb] [decimal](18, 2) NULL,
		[db_size_free_in_mb] [decimal](18, 2) NULL,
		[ins_date] [datetime] NULL
	)
	END

--------------------------------------------------------------------------------
-- HP_OVO_User User erstellen
--------------------------------------------------------------------------------
IF NOT EXISTS (select * from master.sys.sql_logins where name ='HP_OVO_User')
	BEGIN
		CREATE LOGIN HP_OVO_User WITH PASSWORD = 0x01006F0D034CB8ACFE35DA509DB13706CF7F0ACBB7F2BF9E9A10 HASHED, DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF 
		ALTER LOGIN HP_OVO_User ENABLE
		EXEC master..sp_addsrvrolemember @loginame = N'HP_OVO_User', @rolename = N'sysadmin' 
	END
ELSE
	BEGIN
		PRINT 'Account HP_OVO_User already exist'
	END
GO

--------------------------------------------------------------------------------
-- upd_sysadmin User löschen
--------------------------------------------------------------------------------
IF EXISTS (select * from IT2_SysAdmin.sys.database_principals where name ='upd_sysadmin')
BEGIN
	USE [IT2_SysAdmin]
	DROP USER [upd_sysadmin]
END

IF EXISTS (select * from sys.sql_logins where name ='upd_sysadmin')
BEGIN
	DROP LOGIN [upd_sysadmin]
END

--------------------------------------------------------------------------------
-- Errorlogs auf 99 Versionen setzen
--------------------------------------------------------------------------------
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 99
GO

--------------------------------------------------------------------------------
-- MSDB Datenbank grösse festlegen
--------------------------------------------------------------------------------
USE [master]
GO
IF ((SELECT size FROM [msdb].[sys].[database_files] WHERE name = 'MSDBData') < 65536) 
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBData', SIZE = 524288KB)

IF ((SELECT max_size FROM [msdb].[sys].[database_files] WHERE name = 'MSDBData') < 524288)
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBData', MAXSIZE = 4194304KB )

IF ((SELECT growth FROM [msdb].[sys].[database_files] WHERE name = 'MSDBData') < 8192)
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBData', FILEGROWTH = 65536KB )
	GO

IF ((SELECT size FROM [msdb].[sys].[database_files] WHERE name = 'MSDBLog') < 16384) 
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBLog', SIZE = 131072KB )

IF (((SELECT max_size FROM [msdb].[sys].[database_files] WHERE name = 'MSDBLog') < 524288) OR ((SELECT max_size FROM [msdb].[sys].[database_files] WHERE name = 'MSDBLog') = 268435456))  
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBLog', MAXSIZE = 4194304KB)

IF ((SELECT growth FROM [msdb].[sys].[database_files] WHERE name = 'MSDBLog') < 16384)
	ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBLog', FILEGROWTH = 131072KB )
	GO

--------------------------------------------------------------------------------
-- Sysparameter setzen
--------------------------------------------------------------------------------
EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE
GO			 
-- DEFAULT FILL FACTOR	90%
EXEC sys.sp_configure N'fill factor (%)', N'80'
GO
RECONFIGURE WITH OVERRIDE
GO
-- COMPRESS BACKUP
EXEC sys.sp_configure N'backup compression default', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO
-- OLE Automation
EXEC sys.sp_configure N'Ole Automation Procedures', N'1'
GO
RECONFIGURE WITH OVERRIDE
GO

EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE
GO

EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=10000, @jobhistory_max_rows_per_job=300
GO
