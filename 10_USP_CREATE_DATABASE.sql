USE IT2_SysAdmin
GO
-- 10 Procedure USP_CREATE_DATABASE
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name LIKE 'USP_CREATE_DATABASE') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_CREATE_DATABASE','$(pstdvers)',GETDATE(),'1.14')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.14', modified = GETDATE() WHERE tab_proc_name = 'USP_CREATE_DATABASE'
GO
PRINT '---------------------------------------
10 create [USP_CREATE_DATABASE]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_CREATE_DATABASE' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_CREATE_DATABASE]
GO
-- ------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_CREATE_DATABASE]
    /* Benutzer Angaben, Parameter(n) */
    @db_name          VARCHAR(150) = ''
  , @usr_size         VARCHAR(1)  = ''
  , @it_service		  VARCHAR(100)  = ''
  , @serv_desc		  VARCHAR(100)  = ''
-- ------------------------------------------------------------------
-- Object Name:           usp_create_database
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Synonym:               on master db : usp_create_database
-- Verstion:              1.3
-- Date:                  2007-02-28 10:00
-- Autor:                 Laurent Finger, IT226
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Die Prozedure erstellt neue Datenbanken parametrisiert nach dem
-- Server Spezificationen (table t_localsettings der Datenbank
-- IT2_SysAdmin).
-- ------------------------------------------------------------------
-- Parameter:
-- ==========
-- DatenbankName
-- DatenbankGr?sse:
--              'S' =  4 files a  16MB
--              'M' =  8 files a 128MB
--              'L' = 16 files a 256MB
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor					Version		Date		What
-- Laurent Finger, IT2					1.0			20070206	first pubicated version
-- Laurent Finger, IT2					1.1			20070209	change file group name from data back to user01 like sql2000
-- Laurent Finger, IT2					1.2			20070228	set AUTO_UPDATE_STATISTICS_ASYNC on
-- Laurent Finger, IT2					1.3			20070507	correct the pathes from the data files variables
-- Roger Bugmann, IT226					1.04		20100201	Neue Versionierung
-- Roger Bugmann, IT226					1.05		20100831	Create Dummy Table hinzugef?gt
--																Parameter f?r Primary ge?ndert (@pri_size = 50 -- [MB],
--																set @pri_maxsize = 200 -- [MB], set @pri_filegrowth = 20 --[MB])
-- Sven Herren, IT234					1.06		20110421	Code schlanker / dynamischer gemacht, an der funktionalit?t nichts ge?ndert
-- Melih Bildik, IT226					1.07		03.01.12	Fileerweiterung bei S DBs auf 16MB angepasst, bei S auf 256MB
-- Roger Bugmann IT226					1.08beta	24.02.2012	extended properties tests.
-- Roger Bugmann IT226					1.08		06.08.2012	extended properties erweitert, Procedure mit zus?tzlichen Parametern versehen (Service, Service Description).
-- Roger Bugmann IT226					1.09		25.04.2013	Kleinere Bugfixes
-- Melih Bildik IT222 					1.10		23.02.15	Anpassungen der Werte
-- Roger Bugmann IT222					1.11		02.06.2015	Korrektur Primary und S Datafiles startsize und filegroth auf 16MB angepasst
-- Kunabalasingam Kuareesan, IT234		1.12		07.07.16	Fork for SQL Server 2016
-- Melih Bildik IT222					1.XX		27.09.16	Workaround für Andreas, bis es richtig korrigiert wird
-- Kunabalasingam Kuareesan, IT234		1.13		03.10.16	Filegroup USER01 wird entfernt & Anpassung der Datenfiles gemäss KO_SQLServer2016
-- Kunabalasingam Kuareesan, IT234		1.14		22.11.16	Den Datenwachstum (Betroffene Variable: "@pri_filegrowth" & "@file_filegrowth") der MDF- und NDF-Files auf 128 MB angepasst, für die Datenbank-Size M 
--                                            		22.11.16	Der DBA Owner wird auf SA gesetzt 
-- ------------------------------------------------------------------------------------------------
  AS
    -- --------------------------------------------------------------
    -- first check if every user infos are given
    -- --------------------------------------------------------------
    IF @db_name = ''
      BEGIN
        PRINT 'Kein Datenbankname angegeben'
        RETURN -- exit the storage procedure
      END
    IF @it_service = ''
      BEGIN
        PRINT 'Kein Service angegeben!'
        RETURN -- exit the storage procedure
      END
    IF @serv_desc = ''
      BEGIN
        PRINT 'Keine Beschreibung zum Service angegeben!'
        RETURN -- exit the storage procedure
      END      
      

	-- --------------------------------------------------------------
    -- Declare internal variables
    -- --------------------------------------------------------------
    DECLARE
    -- Settings the number of user data files
      @cre_db_stmt           VARCHAR(8000) -- complete create database statment
    , @db_datafiles_nbr      INT           -- number or user data files needed
    , @ifilegroup            INT           -- iterator for file groups
    , @strfilegroup          VARCHAR(10)   -- string representation for iterator
    , @cre_db_stmt_settings  VARCHAR(8000) -- statement to do the settings of the database
    , @returncode            INT
    , @db_size               INT           -- total of database user files
    , @db_size_growth        INT           -- total of database user files growth
    , @stmt                  VARCHAR(8000) -- other statments
    , @cr_tab		         VARCHAR(400) -- Create Dummy Table variable
    -- --------------------------------------------------------------
    -- assign values to the variables
    -- --------------------------------------------------------------
    -- default Wert f?r @usr_size
    IF @usr_size = ''              /* falls keine User Eingabe, w?hle 'S' */
      SET @usr_size = 'S'

    IF @usr_size <> 'S' and @usr_size <> 'M' and @usr_size <> 'L'
      BEGIN
        PRINT 'Falsche Datenbankgr?sse angebeben nur S, M oder L m?glich'
        RETURN -- exit the storage procedure
      END

    -- --------------------------------------------------------------
    -- variables declarations
    -- --------------------------------------------------------------
    DECLARE
      -- Settings size for all user data files and log files
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
    -- --------------------------------------------------------------
    -- file sizes
    -- --------------------------------------------------------------
  
    -- Settings size for all data files
    IF @usr_size = 'S'
      BEGIN
		SET @pri_size             = 16  -- [MB]
		SET @pri_maxsize          = 1024 -- [MB]
		SET @pri_filegrowth       = 16  -- [MB]
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
		SET @pri_maxsize          = 2048 -- [MB]
		SET @pri_filegrowth       = 128  -- [MB]
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
		SET @pri_maxsize          = 4096 -- [MB]
		SET @pri_filegrowth       = 256  -- [MB]
        SET @file_size            = 256
        SET @file_maxsize         = 4096
        SET @file_filegrowth      = 256
        SET @log_size             = 2048
        SET @log_maxsize          = 16384
        SET @log_filegrowth       = 1024
        SET @db_datafiles_nbr     = 15
      END
    -- --------------------------------------------------------------
    -- file names and pathes
    -- --------------------------------------------------------------
    -- Settings for the primary datafile
    SET @pri_name             = @db_name+'_primary'
    SET @pri_file_name        = @db_name+'_primary.mdf'
    SELECT @pri_path          = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Primary file path'
    SET @pri_path             = @pri_path+'\'
    -- Settings for the logfile as data filegroup
    SET @log_name             = @db_name+'_log'
    SET @log_file_name        = @db_name+'_tlog.ldf'
    SELECT @log_path          = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Tlog file path'
    SET @log_path             = @log_path+'\'
    
-- --------------------------------------------------------------
-- create database with 1 primary file, x secondary files, 1 Tlog file
-- --------------------------------------------------------------
SET @cre_db_stmt='
CREATE DATABASE ['+@db_name+'] 
  ON PRIMARY 
    ( NAME         = '''+@pri_name+'''
    , FILENAME     = '''+@pri_path+@pri_file_name+'''
    , SIZE         = '+@pri_size+'MB
    , FILEGROWTH   = '+@pri_filegrowth+'MB
    , MAXSIZE      = '+@pri_maxsize+'MB)
	,'
  
-- --------------------------------------------------------------
-- create secondary file(s)
-- --------------------------------------------------------------  
  SET @ifilegroup = 1
  WHILE @ifilegroup <= @db_datafiles_nbr
	 BEGIN
		SET @strfilegroup       = RIGHT('00'+ CONVERT(VARCHAR,@ifilegroup),2)
		SET @data_name          = @db_name+'_data'+ @strfilegroup
		SET @data_file_name     = @db_name+'_data'+ @strfilegroup + '.ndf'
		SELECT @data_path       = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Primary file path'
		
		IF @ifilegroup > 1
			BEGIN
				SET @cre_db_stmt=@cre_db_stmt+','
			END
			
  		SET @cre_db_stmt=@cre_db_stmt+    '(   NAME       = '''+@data_name+'''
  		                                     , FILENAME   = '''+@data_path+'\'+@data_file_name+'''
  		                                     , SIZE       = '+@file_size+'MB
  		                                     , FILEGROWTH = '+@file_filegrowth+'MB
  		                                     , MAXSIZE    = '+@file_maxsize+'MB)'
  	   SET @ifilegroup=@ifilegroup+1
	END
-- -----------------------------------------------------------------
-- Log File definition
-- -----------------------------------------------------------------
 SET @cre_db_stmt=@cre_db_stmt+'
  LOG ON 
    (   NAME       = '''+@log_name+'''
      , FILENAME   = '''+@log_path+@log_file_name+'''
      , SIZE       = '+@log_size+'MB
      , FILEGROWTH = '+@log_filegrowth+'MB
      , MAXSIZE    = '+@log_maxsize+'MB)
      '
-- --------------------------------------------------------------------
-- Database settings
-- --------------------------------------------------------------------
SET @cre_db_stmt_settings ='
  --EXEC dbo.sp_dbcmptlevel @dbname='+@db_name+', @new_cmptlevel=90
  IF (1 = FULLTEXTSERVICEPROPERTY(''IsFullTextInstalled''))
    begin
      EXEC ['+@db_name+'].[dbo].[sp_fulltext_database] @action = ''disable''
    end
  ALTER DATABASE ['+@db_name+'] SET ANSI_NULL_DEFAULT OFF 
  ALTER DATABASE ['+@db_name+'] SET ANSI_NULLS OFF 
  ALTER DATABASE ['+@db_name+'] SET ANSI_PADDING OFF 
  ALTER DATABASE ['+@db_name+'] SET ANSI_WARNINGS OFF 
  ALTER DATABASE ['+@db_name+'] SET ARITHABORT OFF 
  ALTER DATABASE ['+@db_name+'] SET AUTO_CLOSE OFF 
  ALTER DATABASE ['+@db_name+'] SET AUTO_CREATE_STATISTICS ON 
  ALTER DATABASE ['+@db_name+'] SET AUTO_SHRINK OFF 
  ALTER DATABASE ['+@db_name+'] SET AUTO_UPDATE_STATISTICS ON 
  ALTER DATABASE ['+@db_name+'] SET CURSOR_CLOSE_ON_COMMIT OFF 
  ALTER DATABASE ['+@db_name+'] SET CURSOR_DEFAULT  GLOBAL 
  ALTER DATABASE ['+@db_name+'] SET CONCAT_NULL_YIELDS_NULL OFF 
  ALTER DATABASE ['+@db_name+'] SET NUMERIC_ROUNDABORT OFF 
  ALTER DATABASE ['+@db_name+'] SET QUOTED_IDENTIFIER OFF 
  ALTER DATABASE ['+@db_name+'] SET RECURSIVE_TRIGGERS OFF 
  ALTER DATABASE ['+@db_name+'] SET AUTO_UPDATE_STATISTICS_ASYNC ON 
  ALTER DATABASE ['+@db_name+'] SET DATE_CORRELATION_OPTIMIZATION OFF 
  ALTER DATABASE ['+@db_name+'] SET PARAMETERIZATION SIMPLE 
  ALTER DATABASE ['+@db_name+'] SET READ_WRITE 
  ALTER DATABASE ['+@db_name+'] SET RECOVERY FULL 
  ALTER DATABASE ['+@db_name+'] SET MULTI_USER 
  ALTER DATABASE ['+@db_name+'] SET PAGE_VERIFY CHECKSUM  
  '
--  print @cre_db_stmt
--  print @cre_db_stmt_settings

  EXEC (@cre_db_stmt)
  EXEC (@cre_db_stmt_settings)

  SET @cre_db_stmt_settings ='
  USE ['+@db_name+']
  EXEC dbo.sp_changedbowner @loginame = N''sa'', @map = false
  '
  EXEC (@cre_db_stmt_settings)

-- --------------------------------------------------------------------
-- Create Dummy table for CMDB (20100831)
-- --------------------------------------------------------------------
SET @cr_tab = 'create table ['+@db_name+'].dbo.DUMMY_TABLE ( dummy_id int, dummy varchar(2))'
EXEC (@cr_tab)
-- --------------------------------------------------------------
-- Add Extendedproperties
-- --------------------------------------------------------------
	DECLARE @creator varchar(50)
	DECLARE @exec_add varchar(2000)
		SELECT @creator= SUSER_NAME()
		SET @exec_add = 'EXEC ['+@db_name+'].sys.sp_addextendedproperty @name=N''Creator'', @value= '''+@creator+''' '
		EXEC (@exec_add)
		SET @exec_add = 'EXEC ['+@db_name+'].sys.sp_addextendedproperty @name=N''IT_Service'', @value= '''+@it_service+''' '
		EXEC (@exec_add)
		SET @exec_add = 'EXEC ['+@db_name+'].sys.sp_addextendedproperty @name=N''Description'', @value= '''+@serv_desc+''' '
		EXEC (@exec_add)
-- --------------------------------------------------------------------
-- Backup system databases and new database
-- --------------------------------------------------------------------
	EXEC USP_BACKUP_FULL 'master'
	EXEC USP_BACKUP_FULL 'msdb'
	EXEC USP_BACKUP_FULL 'model'
	EXEC USP_BACKUP_FULL @db_name
-- --------------------------------------------------------------------
-- Feedback to the user
-- --------------------------------------------------------------------
PRINT ''
PRINT ''
PRINT '-- ----------------------------------------------------------------------------------------------------------------------------------------------'
PRINT 'Folgende Datenbank ist erstellt worden:'
PRINT ''
PRINT '(falls keine Datenbank Information sichtbar sind, bitte auf "Results" Tab wechslen...'
EXEC sp_helpdb @db_name
PRINT''
PRINT''
PRINT''
PRINT''
PRINT 'Folgende Datenbanken sind voll gesichert (Full Backup) worden'
PRINT '  - master'
PRINT '  - msdb'
PRINT '  - model'
PRINT '  - '+@db_name
PRINT '-- ----------------------------------------------------------------------------------------------------------------------------------------------'
PRINT '"That''s All Folks!"' 
-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------

GO
