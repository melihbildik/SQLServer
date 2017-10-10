USE [IT2_SysAdmin]
GO

-- 23 Procedure USP_DBFILE_EXTENDER
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_DBFILE_EXTENDER') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_DBFILE_EXTENDER','$(pstdvers)',GETDATE(),'1.00')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.00', modified = GETDATE() WHERE tab_proc_name = 'USP_DBFILE_EXTENDER'
GO
PRINT '---------------------------------------
23 create [USP_DBFILE_EXTENDER]
---------------------------------------'
GO

IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_DBFILE_EXTENDER' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_DBFILE_EXTENDER]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_DBFILE_EXTENDER]
-----------------------------------------------------------------------
-- USP_FILE_EXTENDER
-----------------------------------------------------------------------
-- Projekt Beschreibung
-----------------------------------------------------------------------
-- Database:              IT2_SysAdmin
-- Version:               1.0
-- Date:                  20.01.2017
-- Autor:                 Kunabalasingam Kaureesan - Hauri
-- Copyright:             Die Schweizerische Post
-----------------------------------------------------------------------
-- Used for:
-- ==========
-- Diese Prozedur modifiziert bei der genannten Datenbank die Grösse, 
-- das Wachstum und die maximale Grösse der Datenfiles (*.mdf,*.ndf und *.ldf), 
-- mittels der Datenbankgrössenangabe (S, M oder L) des Benutzers.
-- Die erforderliche Grössendefinition wird durch die Prozedur "USP_CREATE_DATABASE"
-- ermittelt.
--
-- Wenn die Datenbank aus je einem "*.mdf" und "*.ldf" File besteht,
-- wird mittels dieser Prozedur die fehlenden "*.ndf" Files angelegt und die
-- Grössen aller Files, analog zur Datenbankgrössendefinition angepasst.
--
-- Falls die Datenbank aus je einem "*.mdf" und "*.ldf" sowie mehreren "*.ndf" 
-- Files besteht, wird aufgrund der gewünschten Datenbankgrössenangabe
-- ein "PRINT" mit den erforderlichen Befehlen zur Erstellung der "*.ndf"
-- Files suggeriert. Die Grösse der bestehenden Files werden analog
-- zur Datenbankgrössendefinition angepasst.
-----------------------------------------------------------------------
-- Parameter:
-- ==========
-- @db_name:		(Zwingend) Der Datenbankname
-- @usr_size		(Zwingend) Die Datenbankgrössenangabe - Mögliche Auswahl (S, M oder L)
-----------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor						Version	Date		What
-- Kunabalasingam Kaureesan		1.00	20.01.2017	Erstellung der Prozedur
-----------------------------------------------------------------------

-- Add the parameters for the stored procedure here
		@db_name				SYSNAME = '',
		@usr_size				VARCHAR(1) = ''

  AS
  BEGIN
-- --------------------------------------------------------------
-- declare variables
-- --------------------------------------------------------------
  DECLARE 
		@version				NVARCHAR(25),
		@name					SYSNAME,
		@size					INT,
		@max_size				INT,
		@growth					INT,

		@existing_datafiles_ndf	INT,
		@db_datafiles_nbr		INT,
		@strfilegroup			VARCHAR(10),
		@ifilegroup				INT,
		@stmt					VARCHAR(8000)

-- Settings size for all user data files and log files
  DECLARE
        @pri_size              VARCHAR(10)   -- primary file size
      , @pri_maxsize           VARCHAR(10)   -- primary file max size
      , @pri_filegrowth        VARCHAR(10)   -- primary file growth
      , @file_size             VARCHAR(10)   -- all other data files size
      , @file_maxsize          VARCHAR(10)   -- all other data files max size
      , @file_filegrowth       VARCHAR(10)   -- all other data files growth
      , @log_size              VARCHAR(10)   -- log file size
      , @log_maxsize           VARCHAR(10)   -- log file max size
      , @log_filegrowth        VARCHAR(10)   -- log file growth
-- Settings for the logfile
      , @log_name              VARCHAR(80)
      , @log_file_name         VARCHAR(80)
      , @log_path              VARCHAR(80)
-- Settings for the primary datafile as primary filegroup
      , @pri_name              VARCHAR(80)
      , @pri_file_name         VARCHAR(80)
      , @pri_path              VARCHAR(80)
--  Settings for datafile as data filegroup
      , @data_name			   VARCHAR(80)
      , @data_file_name        VARCHAR(80)
      , @data_path             VARCHAR(80)

-- ------------------------------------------------------------------------------------------------
--	get serverversion
-- ------------------------------------------------------------------------------------------------
  SET @version = CONVERT(sysname,SERVERPROPERTY('ProductVersion'))

  SELECT @version = CASE
		WHEN @version LIKE '13.0%' THEN '2016'
		WHEN @version LIKE '12.0%' THEN '2014'
		WHEN @version LIKE '11.0%' THEN '2012'
		WHEN @version LIKE '10.%' THEN '2008'
		WHEN @version LIKE '9.0%' THEN '2005'
	END

-- --------------------------------------------------------------
-- define file sizes for S,M and L
-- --------------------------------------------------------------
-- for SQL Server 2016 and higher
  IF @usr_size = 'S'
	BEGIN
		SET @pri_size             = 16    -- [MB]
		SET @pri_maxsize          = 1024
		SET @pri_filegrowth       = 16
		SET @file_size            = 16
		SET @file_maxsize         = 1024
		SET @file_filegrowth      = 16
		SET @log_size             = 128
		SET @log_maxsize          = 1024
		SET @log_filegrowth       = 128
		SET @db_datafiles_nbr     = 3
	END
  IF @usr_size = 'M'
   BEGIN
		SET @pri_size             = 128  -- [MB]
		SET @pri_maxsize          = 2048
		SET @pri_filegrowth       = 128
        SET @file_size            = 128
        SET @file_maxsize         = 2048
        SET @file_filegrowth      = 128
        SET @log_size             = 512
        SET @log_maxsize          = 8192
        SET @log_filegrowth       = 512
        SET @db_datafiles_nbr     = 7
   END
  IF @usr_size = 'L'
   BEGIN
		SET @pri_size             = 256  -- [MB]
		SET @pri_maxsize          = 4096
		SET @pri_filegrowth       = 256
        SET @file_size            = 256
        SET @file_maxsize         = 4096
        SET @file_filegrowth      = 256
        SET @log_size             = 2048
        SET @log_maxsize          = 16384
        SET @log_filegrowth       = 1024
        SET @db_datafiles_nbr     = 15
   END

-- for SQL Server 2014 and lower
  IF(@version <= '2014')
	BEGIN
-- settings size for the primary file
		SET @pri_size             = 16  -- [MB]
		SET @pri_maxsize          = 256
		SET @pri_filegrowth       = 16

-- set the amount of "*.ndf" files
		IF @usr_size = 'S'
		  BEGIN
			SET @db_datafiles_nbr     = 4
		  END
		IF @usr_size = 'M'
		  BEGIN
			SET @db_datafiles_nbr     = 8
		  END
		IF @usr_size = 'L'
		  BEGIN
			SET @db_datafiles_nbr     = 16
		  END
	END

-- --------------------------------------------------------------
-- check if every user infos are given
-- --------------------------------------------------------------
  IF(@db_name = '')
	BEGIN
        PRINT 'Kein Datenbankname angegeben'
        RETURN -- exit the storage procedure
	END

  IF(@usr_size <> 'S' and @usr_size <> 'M' and @usr_size <> 'L')
	BEGIN
        PRINT 'Falsche Datenbankgr?sse angebeben nur S, M oder L m?glich'
        RETURN -- exit the storage procedure
	END
  
  IF NOT EXISTS (SELECT [name] FROM sys.databases WHERE [name] = @db_name and [state] = '0')
	BEGIN
		PRINT 'Die Datenbank existiert nicht, oder sie ist nicht Online'
        RETURN -- exit the storage procedure
	END
  
-- --------------------------------------------------------------
-- adjust .mdf Files
-- --------------------------------------------------------------
  DECLARE data_file_mdf CURSOR STATIC FOR 
	SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
		FROM sys.master_files
		WHERE DB_NAME(database_id) = @db_name AND [type] = '0' AND physical_name LIKE '%.mdf'
	
	OPEN data_file_mdf
        FETCH NEXT FROM data_file_mdf INTO  @name, @size, @max_size, @growth
        WHILE @@FETCH_STATUS = 0
			BEGIN
				BEGIN
					IF(@size < @pri_size)
					BEGIN
						SET @stmt = 'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', SIZE = '+@pri_size+'MB)'
						EXEC (@stmt)
					END

					IF(@max_size < @pri_maxsize)
					BEGIN
						SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', MAXSIZE = '+@pri_maxsize+'MB)'
						EXEC (@stmt)
					END

					IF(@growth < @pri_filegrowth)
					BEGIN
						SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', FILEGROWTH = '+@pri_filegrowth+'MB)'
						EXEC (@stmt)
					END

					IF(@name NOT LIKE +@db_name+'_primary')
					BEGIN
						SET @stmt = 'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', NEWNAME = '+@db_name+'_primary)'
						EXEC (@stmt)
					END
				END
				FETCH NEXT FROM data_file_mdf INTO @name, @size, @max_size, @growth
			END 
  CLOSE data_file_mdf
  DEALLOCATE data_file_mdf

-- --------------------------------------------------------------
-- adjust *.ldf Files
-- --------------------------------------------------------------	
  DECLARE data_file_ldf CURSOR STATIC FOR 
	SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
		FROM sys.master_files
		WHERE DB_NAME(database_id) = @db_name AND [type] = '1' AND physical_name LIKE '%.ldf'

	OPEN data_file_ldf
        FETCH NEXT FROM data_file_ldf INTO @name, @size, @max_size, @growth
        WHILE @@FETCH_STATUS = 0
			BEGIN
				BEGIN
					IF(@size < @log_size)
					BEGIN
						SET @stmt = 'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', SIZE = '+@log_size+'MB)'
						EXEC (@stmt)
					END

					IF(@max_size < @log_maxsize OR @max_size = '2097152')
					BEGIN
						SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', MAXSIZE = '+@log_maxsize+'MB)'
						EXEC (@stmt)
					END

					IF(@growth < @log_filegrowth)
					BEGIN
						SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', FILEGROWTH = '+@log_filegrowth+'MB)'
						EXEC (@stmt)
					END
				END
				FETCH NEXT FROM data_file_ldf INTO @name, @size, @max_size, @growth
			END 
  CLOSE data_file_ldf
  DEALLOCATE data_file_ldf
	
-- --------------------------------------------------------------
-- add *.ndf Files
-- --------------------------------------------------------------
  IF NOT EXISTS (SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
						FROM sys.master_files
						WHERE DB_NAME(database_id) = @db_name AND [type] = '0' AND physical_name LIKE '%.ndf')
	BEGIN
		IF(@version <= '2014')
		BEGIN
			SET @stmt =		'USE '+@db_name+'
							IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE name = N''USER01'')
								ALTER DATABASE '+@db_name+' ADD FILEGROUP [USER01]					
							USE [IT2_SysAdmin]'
			EXEC (@stmt)
		END

		SET @ifilegroup = 1
		SET @stmt = 'ALTER DATABASE '+@db_name+' ADD FILE '

		  WHILE @ifilegroup <= @db_datafiles_nbr
			 BEGIN
				SET @strfilegroup       = RIGHT('00'+ CONVERT(VARCHAR,@ifilegroup),2)
				SET @data_name          = @db_name+'_data'+ @strfilegroup
				SET @data_file_name     = @db_name+'_data'+ @strfilegroup + '.ndf'
				
				IF(@version >= '2016')
					SELECT @data_path       = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Primary file path'
				ELSE
					SELECT @data_path       = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Data'+ @strfilegroup +' file path'
		
				IF @ifilegroup > 1
					BEGIN
						SET @stmt	= @stmt+','
					END

				SET @stmt		= @stmt+    '(   NAME       = '''+@data_name+'''
  		                                     , FILENAME   = '''+@data_path+'\'+@data_file_name+'''
  		                                     , SIZE       = '+@file_size+'MB
  		                                     , FILEGROWTH = '+@file_filegrowth+'MB
  		                                     , MAXSIZE    = '+@file_maxsize+'MB)'
												 
  				SET @ifilegroup=@ifilegroup+1
			END
			
			IF(@version <= '2014')
				BEGIN
					SET @stmt = @stmt +'TO FILEGROUP [USER01]
										USE '+@db_name+'
										IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N''USER01'') 
											ALTER DATABASE '+@db_name+' MODIFY FILEGROUP [USER01] DEFAULT				
										USE [IT2_SysAdmin]'
				END
-- the files will be created, after the following "EXEC"
			EXEC (@stmt)
	END
-- --------------------------------------------------------------
-- adjust *.ndf Files
-- --------------------------------------------------------------
  ELSE
    BEGIN
	DECLARE data_file_ndf CURSOR STATIC FOR 
		SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
			FROM sys.master_files
			WHERE DB_NAME(database_id) = @db_name AND [type] = '0' AND physical_name LIKE '%.ndf'
			ORDER BY [name] asc

		OPEN data_file_ndf
			FETCH NEXT FROM data_file_ndf INTO @name, @size, @max_size, @growth
			WHILE @@FETCH_STATUS = 0
			BEGIN
					BEGIN
						IF(@size < @file_size)
						BEGIN
							SET @stmt = 'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', SIZE = '+@file_size+'MB)'
							EXEC (@stmt)
						END

						IF(@max_size < @file_maxsize OR @max_size = '2097152')
						BEGIN
							SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', MAXSIZE = '+@file_maxsize+'MB)'
							EXEC (@stmt)
						END

						IF(@growth < @file_filegrowth)
						BEGIN
							SET @stmt =  'ALTER DATABASE '+@db_name+' MODIFY FILE ( NAME = '''+@name+''', FILEGROWTH = '+@file_filegrowth+'MB)'
							EXEC (@stmt)
						END

					END
					FETCH NEXT FROM data_file_ndf INTO @name, @size, @max_size, @growth
			END 
	CLOSE data_file_ndf
	DEALLOCATE data_file_ndf

-- --------------------------------------------------------------
-- create print if *.ndf Files exists
-- --------------------------------------------------------------
		SET @existing_datafiles_ndf = (SELECT COUNT(*) FROM sys.master_files WHERE DB_NAME(database_id) = @db_name AND [type] = '0' AND physical_name LIKE '%.ndf')
	
		IF (@existing_datafiles_ndf < @db_datafiles_nbr)
			BEGIN
					
					BEGIN TRY
						SET @ifilegroup = (SELECT RIGHT((@name),2)) + 1
					END TRY
					BEGIN CATCH
						IF(ERROR_MESSAGE() LIKE '%Conversion failed when converting the nvarchar%')
						PRINT 'Error during extending the files.'
						RETURN -- exit the storage procedure
					END CATCH

					IF(@version <= '2014')
						BEGIN
							SET @stmt =		'-- Create FILEGROUP [USER01], if it does not exist
											USE '+@db_name+'
											IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE name = N''USER01'')
												ALTER DATABASE '+@db_name+' ADD FILEGROUP [USER01]					
											USE [IT2_SysAdmin]'
							PRINT(@stmt)
						END

					WHILE @ifilegroup <= @db_datafiles_nbr
						BEGIN
							SET @stmt = '-- Create *.ndf File
										ALTER DATABASE '+@db_name+' ADD FILE '

							SET @strfilegroup       = RIGHT('00'+ CONVERT(VARCHAR,@ifilegroup),2)
							SET @data_name          = @db_name+'_data'+ @strfilegroup
							SET @data_file_name     = @db_name+'_data'+ @strfilegroup + '.ndf'
								
							IF(@version >= '2016')
								SELECT @data_path       = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Primary file path'
							ELSE
								SELECT @data_path       = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Data'+ @strfilegroup +' file path'

			
								SET @stmt		= @stmt+    '(   NAME       = '''+@data_name+'''
  															 , FILENAME   = '''+@data_path+'\'+@data_file_name+'''
  															 , SIZE       = '+@file_size+'MB
  															 , FILEGROWTH = '+@file_filegrowth+'MB
  															 , MAXSIZE    = '+@file_maxsize+'MB)'
								
								IF(@version <= '2014')
									BEGIN
										SET @stmt = @stmt +'TO FILEGROUP [USER01]'
									END

							IF NOT EXISTS (SELECT * FROM sys.master_files WHERE DB_NAME(database_id) = @db_name AND name = @data_name)
								BEGIN
									PRINT @stmt
								END

							SET @ifilegroup=@ifilegroup+1
							SET @existing_datafiles_ndf = (SELECT COUNT(*) FROM sys.master_files WHERE DB_NAME(database_id) = @db_name AND [type] = '0' AND physical_name LIKE '%.ndf')
						END

						IF(@version <= '2014')
						BEGIN
							SET @stmt =		'-- SET FILEGROUP [USER01] as default
											USE '+@db_name+'
											IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N''USER01'') 
												ALTER DATABASE '+@db_name+' MODIFY FILEGROUP [USER01] DEFAULT				
											USE [IT2_SysAdmin]'
							PRINT (@stmt)
						END
				END
		END
		

END
GO
