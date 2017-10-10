PRINT '---------------------------------------
01 create [SDAG_AdminDB]
---------------------------------------'
GO
--------------------------------------------------------------------------------
-- 01 Create Script
--------------------------------------------------------------------------------
-- Dieses Script erstellt die komplette SDAG_AdminDB DB mit den entsprechenden SYS_Jobs, 
-- ohne restore aus einem BackupFile.
--------------------------------------------------------------------------------
-- Database:              SDAG_AdminDB
-- Version:               1.0
-- Date:                  19.09.17
-- Autor:                 Melih Bildik
-- Copyright:             smart dynamic AG
--------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Bildik Melih						1.00		19.09.17	erste Version

--------------------------------------------------------------------------------
DECLARE	@datalw		VARCHAR(20),
	@log01		VARCHAR(20),
	@backuplw	VARCHAR(20),
	@stmt		VARCHAR(4000),
	@pit		VARCHAR(4)

--------------------------------------------------------------------------------
-- !!!! Variabeln �bergabe durch Startscript !!!! -- 
--------------------------------------------------------------------------------
SET	@datalw		= '$(datalw)'		
SET	@log01		= '$(log01)'		
SET	@backuplw	= '$(backuplw)'		
SET	@pit		= '$(pit)' 			-- TEST,INTE,PROD 


--------------------------------------------------------------------------------
-- Datenbankerstellung
--------------------------------------------------------------------------------

CREATE DATABASE [SDAG_AdminDB] 


ALTER DATABASE [SDAG_AdminDB] SET ANSI_NULL_DEFAULT OFF 
ALTER DATABASE [SDAG_AdminDB] SET ANSI_NULLS OFF 
ALTER DATABASE [SDAG_AdminDB] SET ANSI_PADDING OFF 
ALTER DATABASE [SDAG_AdminDB] SET ANSI_WARNINGS OFF 
ALTER DATABASE [SDAG_AdminDB] SET ARITHABORT OFF 
ALTER DATABASE [SDAG_AdminDB] SET AUTO_CLOSE OFF 
ALTER DATABASE [SDAG_AdminDB] SET AUTO_CREATE_STATISTICS ON 
ALTER DATABASE [SDAG_AdminDB] SET AUTO_SHRINK OFF 
ALTER DATABASE [SDAG_AdminDB] SET AUTO_UPDATE_STATISTICS ON 
ALTER DATABASE [SDAG_AdminDB] SET CURSOR_CLOSE_ON_COMMIT OFF 
ALTER DATABASE [SDAG_AdminDB] SET CURSOR_DEFAULT  GLOBAL 
ALTER DATABASE [SDAG_AdminDB] SET CONCAT_NULL_YIELDS_NULL OFF 
ALTER DATABASE [SDAG_AdminDB] SET NUMERIC_ROUNDABORT OFF 
ALTER DATABASE [SDAG_AdminDB] SET QUOTED_IDENTIFIER OFF 
ALTER DATABASE [SDAG_AdminDB] SET RECURSIVE_TRIGGERS OFF 
ALTER DATABASE [SDAG_AdminDB] SET  DISABLE_BROKER 
ALTER DATABASE [SDAG_AdminDB] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
ALTER DATABASE [SDAG_AdminDB] SET DATE_CORRELATION_OPTIMIZATION OFF 
ALTER DATABASE [SDAG_AdminDB] SET TRUSTWORTHY OFF 
ALTER DATABASE [SDAG_AdminDB] SET ALLOW_SNAPSHOT_ISOLATION OFF 
ALTER DATABASE [SDAG_AdminDB] SET PARAMETERIZATION SIMPLE 
ALTER DATABASE [SDAG_AdminDB] SET READ_COMMITTED_SNAPSHOT OFF 
ALTER DATABASE [SDAG_AdminDB] SET READ_WRITE 
ALTER DATABASE [SDAG_AdminDB] SET RECOVERY FULL 
ALTER DATABASE [SDAG_AdminDB] SET MULTI_USER 
ALTER DATABASE [SDAG_AdminDB] SET PAGE_VERIFY CHECKSUM  
ALTER DATABASE [SDAG_AdminDB] SET DB_CHAINING OFF 

SELECT @stmt = '
CREATE TABLE [SDAG_AdminDB].[dbo].[t_localsettings](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[definition] [varchar](50) NOT NULL,
	[value] [varchar](4000) NOT NULL
) on [PRIMARY]'

EXEC (@stmt)
--------------------------------------------------------------------------------
-- Defaultwerte f�r t_localsettings abf�llen
--------------------------------------------------------------------------------
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Full backup start time','220000')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Tlog backup start time','003000')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Primary file path',''+@datalw+'\Data')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Tlog file path',''+@log01+'\Tlog')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Backup full path',''+@backuplw+'\Backup')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Backup tlog path',''+@backuplw+'\Backup')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('Backup diff path',''+@backuplw+'\DIFFBackup')
INSERT INTO [SDAG_AdminDB].[dbo].[t_localsettings] ([definition],[value]) VALUES ('PIT',''+@pit+'')
GO

--------------------------------------------------------------------------------
-- Extended Properties SDAG_AdminDB
--------------------------------------------------------------------------------
DECLARE @creator VARCHAR(50)
SELECT @creator= SUSER_NAME()
EXEC [SDAG_AdminDB].sys.sp_addextendedproperty @name=N'Creator', @value= @creator
EXEC [SDAG_AdminDB].sys.sp_addextendedproperty @name=N'IT_Service', @value= '4837' 
EXEC [SDAG_AdminDB].sys.sp_addextendedproperty @name=N'Description', @value= 'Modul enthaelt alle Datenbanken, die nur zu IT-internen Zwecken dienen (it.s.mssql_internals)' 
GO

--------------------------------------------------------------------------------
-- Tabellen erstellen
--------------------------------------------------------------------------------
USE [SDAG_AdminDB]
GO
CREATE TABLE [dbo].[cmdb_db](
	[srvname] VARCHAR(50) NULL,
	[dbname] VARCHAR(150) NULL,
	[nameduser] VARCHAR(50) NULL,
	[schemas] VARCHAR(50) NULL,
	[dbsize] VARCHAR(50) NULL
) ON [PRIMARY]

GO


CREATE TABLE [dbo].[cmdb_schema](
	[srvname] VARCHAR(50) NULL,
	[dbname] VARCHAR(150) NULL,
	[schemaname] VARCHAR(256) NULL
) ON [PRIMARY]

GO

CREATE TABLE [dbo].[cmdb_server](
	[srvname] VARCHAR(50) NULL,
	[instname] VARCHAR(50) NULL,
	[srvintname] VARCHAR(50) NULL,
	[sqledition] VARCHAR(50) NULL,
	[sqlversion] VARCHAR(50) NULL,
	[sqlsp] VARCHAR(50) NULL,
	[dport] VARCHAR(10) NULL,
	[port] VARCHAR(10) NULL
) ON [PRIMARY]

GO

CREATE TABLE [dbo].[logs](
	[logid] INT IDENTITY(1,1) NOT NULL,
	[proc_id] INT NULL,
	[loginame] VARCHAR(50) NULL,
	[usrname] VARCHAR(50) NULL,
	[action_time] SMALLDATETIME NOT NULL,
	[db] VARCHAR(150) NULL,
	[message] VARCHAR(4000) NULL,
	[errnr] INT NULL,
	[type] CHAR(50) NULL,
	[source] NCHAR(50) NULL,
 CONSTRAINT [PK_logs] PRIMARY KEY CLUSTERED 
(
	[logid] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

-- NEW Backuplog Tabelle
CREATE TABLE [dbo].[backuplog](
	[ID] [int] NULL,
	[Datum] [datetime] NULL,
	[BeginBackup] [datetime] NULL,
	[EndBackup] [datetime] NULL,
	[Duration] [int] NULL
) ON [PRIMARY]

GO

-- Tabelle Versioncheck
CREATE TABLE [dbo].[versioncheck](
	[vers_id] INT IDENTITY(1,1) NOT NULL,
	[tab_proc_name] VARCHAR(80) NOT NULL,
	[version] VARCHAR(30) NULL,
	[created] DATETIME NULL,
	[modified] DATETIME NULL,
	[procvers] VARCHAR(30) NULL,
 CONSTRAINT [pk_versid] PRIMARY KEY CLUSTERED 
(
	[vers_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY],
 CONSTRAINT [ix_versioncheck] UNIQUE NONCLUSTERED 
(
	[tab_proc_name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
-- Tabelle rebuild_log
CREATE TABLE [dbo].[rebuild_log](
	[db] NCHAR(150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[tablename] NCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[indexname] NCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[start] DATETIME NULL,
	[ende] DATETIME NULL,
	[dauer] NUMERIC(18, 0) NULL
) ON [PRIMARY]
GO 

-- Tabelle f�r Datenbanken ohne Backup 
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
		ALTER TABLE [SDAG_AdminDB].[dbo].[no_backup]
			ADD [user] [nvarchar](50) NULL CONSTRAINT [DF_no_backup_user]  DEFAULT (suser_sname()),
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL CONSTRAINT [DF_no_backup_insdate]  DEFAULT (getdate())
	END
	
-- Table for database used and free space
  IF NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[database_size]') AND type in (N'U'))
	BEGIN
	CREATE TABLE [SDAG_AdminDB].[dbo].[database_size]
	(
		[server] [nvarchar](150) NULL,
		[database] [nvarchar](130) NULL,
		[db_size_in_mb] [decimal](18, 2) NULL,
		[db_size_free_in_mb] [decimal](18, 2) NULL,
		[ins_date] [datetime] NULL
	)
	END

-- Tabelle f�r Datenbanken ohne Rebuild Index 
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
		ALTER TABLE [SDAG_AdminDB].[dbo].[no_rebuildindex]
			ADD [user] [nvarchar](50) NULL CONSTRAINT [DF_no_rebuildindex_user]  DEFAULT (suser_sname()),
			[description] [nvarchar](4000) NULL,
			[insdate] [datetime] NULL CONSTRAINT [DF_no_rebuildindex_insdate]  DEFAULT (getdate())
	END

-- Tabellen f�r Hardening 
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
--	INITIAL Table - SDAG_AdminDB 
-- ----------------------------------------------------------------------------------------------
----  CREATE SDAG_AdminDB.dbo.server_configurations & ADD Column Changedate 
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_configurations]') AND type in (N'U'))
  SELECT *,GETDATE() as changedate INTO SDAG_AdminDB.dbo.server_configurations FROM sys.configurations

----  CREATE SDAG_AdminDB.dbo.server_databases & ADD Column Changedate
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_databases]') AND type in (N'U'))
  SELECT *,GETDATE() as changedate INTO SDAG_AdminDB.dbo.server_databases FROM sys.databases

---- CREATE SDAG_AdminDB.dbo.server_datafiles & ADD Column Insertdate
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
  INTO SDAG_AdminDB.dbo.server_datafiles
  FROM sys.master_files
  ORDER BY 1, type_desc DESC, [file_id];

--  CREATE SDAG_AdminDB.dbo.server_filegroups & ADD Column Insertdate
--  USE SDAG_AdminDB
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[server_filegroups]') AND type in (N'U'))
		BEGIN
			SELECT 'SDAG_AdminDB' as [database], *, GETDATE() as changedate INTO server_filegroups FROM SDAG_AdminDB.sys.filegroups
			ALTER TABLE server_filegroups
			ALTER COLUMN [database] varchar(150)
			
			IF @version >= 2012
			BEGIN
			DECLARE db_cursor CURSOR FOR
				SELECT name FROM sys.databases
						WHERE (state_desc = 'Online' AND name NOT IN ('SDAG_AdminDB') AND name NOT IN (
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
						WHERE (state_desc = 'Online' AND name NOT IN ('SDAG_AdminDB') )
			END
						
			OPEN db_cursor   
				FETCH NEXT FROM db_cursor INTO @dbname   
				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @stmt = 'INSERT INTO SDAG_AdminDB.dbo.server_filegroups SELECT '''+@dbname+''',*, GETDATE() FROM ['+@dbname+'].sys.filegroups'
					EXEC (@stmt)
					FETCH NEXT FROM db_cursor INTO @dbname
				END
			CLOSE db_cursor   
			DEALLOCATE db_cursor
END

--  CREATE SDAG_AdminDB.dbo.job_schedule & ADD Column Insertdate
  IF  NOT EXISTS (SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'[dbo].[job_schedule]') AND type in (N'U'))
  SELECT SJ.name as 'job_name', SS.schedule_id, SS.name as 'schedule_name', SS.[enabled] as 'job_enabled', SS.freq_type, SS.freq_interval, SS.freq_subday_type ,SS.freq_subday_interval, SS.freq_relative_interval, SS.freq_recurrence_factor, 
		 SS.active_start_date, SS.active_end_date, SS.active_start_time, SS.active_end_time, SS.date_created, SS.schedule_uid, GETDATE() as changedate
  INTO SDAG_AdminDB.dbo.job_schedule
  FROM msdb.dbo.sysschedules AS SS
	  INNER JOIN [msdb].[dbo].[sysjobschedules] as SJS
		  on SS.schedule_id = SJS.schedule_id
	  INNER JOIN [msdb].[dbo].[sysjobs] SJ
		  on SJ.job_id = SJS.job_id
  WHERE SJ.name LIKE 'SYS%' 
	  AND SJ.name NOT IN ('syspolicy_purge_history')

--------------------------------------------------------------------------------
-- Defaultwerte f�r Versioncheck abf�llen
--------------------------------------------------------------------------------
INSERT INTO [SDAG_AdminDB].[dbo].[versioncheck] ([tab_proc_name],[created]) VALUES ('SDAG_AdminDB',GETDATE())  -- 01

GO



--------------------------------------------------------------------------------
-- MSDB Datenbank gr�sse festlegen
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
