USE IT2_SysAdmin
GO
-- 13 Procedure USP_GET_CMDB_INFOS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_GET_CMDB_INFOS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_GET_CMDB_INFOS','$(pstdvers)',GETDATE(),'6.04')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '6.04', modified = GETDATE() WHERE tab_proc_name = 'USP_GET_CMDB_INFOS'
GO
PRINT '---------------------------------------
13 create [USP_GET_CMDB_INFOS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_GET_CMDB_INFOS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_GET_CMDB_INFOS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure USP_GET_CMDB_INFOS
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_GET_CMDB_INFOS] 
-- ------------------------------------------------------------------------------------------------
  -- Object Name:           usp_getCmdbInfos
  -- Object Type:           storage procedure
  -- Database:              IT2_SysAdmin
  -- Synonym:               on master db : none
  -- Version:               4.1
  -- Date:                  2008-04-15 10:00
  -- Autor:                 Laurent Finger, IT226
  -- Copyright:             ©Die Schweizerische Post 2007
  -- ------------------------------------------------------------------------------------------------
  -- Used for:
  -- =========
  -- This sp collects infos into IT2_SysAdmin tables for cmdb application. The data will be collected
  -- from a central point.
  -- ------------------------------------------------------------------------------------------------
  -- Parameter:
  -- ==========
  -- none
  -- ------------------------------------------------------------------------------------------------
  -- Possible improvement
  -- ====================
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Last Modification:
  -- ==================
  -- Autor				Version		Date		What
  -- Laurent Finger, IT226		1.0		20070726	first pubicated version
  -- Laurent Finger, IT226		2.0		20080331	output on files so it's possible to collect data with SMS
  -- Bildik Melih, IT226		2.1		20080415	collect the databasesize in db.cmdb_db 
  -- Bildik Melih, IT226		2.2		20080415	Anpassungen bei der Übergabe zur WritetoFile SP. statt @@servername--> SELECT CONVERT(varchar(50), SERVERPROPERTY('servername'))				
  -- Bildik Melih, IT226		2.3		20080415	Anpassung Schemaextraktion, anzahl schemas wahr falsch
  -- Laurent Finger, IT226		2.4		20080418	declare cursor cur_schema over a # table to avoid
  -- 									the problem " Could not complete cursor operation because the set options have changed since 
  --									the cursor was declared. [SQLSTATE 42000] (Error 16958)."
  -- Bildik Melih IT226			4.0		28.04.09	Korrektur das nur die Schemas kommen, die auch eine Tabelle besitzen	
  -- Schmid Heinz, IT263		4.1		07.05.09	Anpassung Aufruf der angepassten SP usp_Write_String_To_File
  -- Melih Bildik IT226			5.0		18.05.09	SQL Server 2008/2005 Anpassungen (EchterServername, versionscheck)
  -- Roger Bugmann, IT226		5.1		20100201	Neue Versionierung
  -- Melih Bildik, IT226		6.00	31.01.12	Umbau ohne SQL2000 Unterstützung , Dbname varchar(150)
  -- Roger Bugmann, IT226		6.01	20.12.12	Select mit online Status ergänzt
  -- Roger Bugmann, IT226		6.02	22.01.13	Beim kreiren der Tabellen die Spalte DBName auf 150 Zeichen erweitert
  -- Roger Bugmann, IT226		6.03	21.03.13	Anpassungen an HA Groups
  -- Roger Bugmann, IT226		6.04	27.04.2015	Abfrage ProdctVersion >= 11.% in	cursor to get db names 
  -- ------------------------------------------------------------------------------------------------
    AS
      -- --------------------------------------------------------------------------------------------
      -- variables declaration 
      -- --------------------------------------------------------------------------------------------
      DECLARE @debugbit         BIT           -- 1 if print for debug porpose are on, 0 if no debug
            , @tcpport          VARCHAR(50)   -- output TCP/IP Port
            , @tcpipportdyn     VARCHAR(50)   -- is TCP/IP Port dynamic
            , @tcpipportdynbit  BIT           -- is TCP/IP Port dynamic bit
            , @servername       VARCHAR(50)   -- server name
            , @pathname         VARCHAR(50)   -- folder path name (MSSQL.?)
            , @instancename     VARCHAR(50)   -- sql server instance name
            , @srvintname       VARCHAR(50)   -- complete name of the instance (servername\instancename)
            , @sqledition       VARCHAR(50)   -- SQL Server Edition
            , @sqlversion       VARCHAR(50)   -- SQL Server Version
            , @sqlsrvicepack    VARCHAR(50)   -- SQL Server service pack
            , @keyname          VARCHAR(512)  -- key name
            , @dbname           VARCHAR(150)   -- database name
            , @schemaname       VARCHAR(50)   -- schema name
            , @schemaid         INT           -- schema id
            , @dbstatus         SQL_VARIANT   -- database status (online or not)
            , @stmt             VARCHAR(4000) -- statment
            , @stmtcur          VARCHAR(4000) -- statment for cursors
            , @usr              VARCHAR(100)  -- user (pext - post)
            , @resultfilename   VARCHAR(100)  -- output file name
            , @tempoutput       VARCHAR(500)  -- temp output variable to build the @txtoutput variable into a cursor
			, @dbsize           VARCHAR(100)  -- database size
            , @txtoutput        VARCHAR(MAX)  -- output data "SQL Server 2005"
		-- --------------------------------------------------------------------------------------------
      -- tables variables declaration 
      -- --------------------------------------------------------------------------------------------
      CREATE TABLE #tschemaname
         (schemaname VARCHAR(128))
      -- --------------------------------------------------------------------------------------------
      -- runnings settings
      -- --------------------------------------------------------------------------------------------
      SET NOCOUNT ON
      -- ----------------------------------------------------------------------------
      -- Set Values
      -- ----------------------------------------------------------------------------
      SET @debugbit = 0
      SELECT @servername    = CONVERT(VARCHAR(20), SERVERPROPERTY('machinename'))
      SELECT @instancename  = CONVERT(VARCHAR(20), ISNULL(SERVERPROPERTY('instancename'), 'MSSQLServer'))
      SELECT @srvintname    = CONVERT(VARCHAR(50), SERVERPROPERTY('servername'))
      SELECT @sqledition    = CONVERT(VARCHAR(50), SERVERPROPERTY('Edition'))
      SELECT @sqlversion    = CONVERT(VARCHAR(50), SERVERPROPERTY('ProductVersion'))
      SELECT @sqlsrvicepack = CONVERT(VARCHAR(50), SERVERPROPERTY('ProductLevel'))
      -- ----------------------------------------------------------------------------
      -- drop tables and create it new if not exists (rather than truncate it)
      -- ----------------------------------------------------------------------------
      /* server infos */
    
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_server]') AND type IN (N'U'))
       DROP TABLE [dbo].[cmdb_server]
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_server]') AND type IN (N'U'))
       CREATE TABLE [dbo].[cmdb_server]
          (  srvname     VARCHAR(50)
           , instname    VARCHAR(50)
           , srvintname  VARCHAR(50)
           , sqledition  VARCHAR(50)
           , sqlversion  VARCHAR(50)
           , sqlsp       VARCHAR(50)
           , dport       VARCHAR(10)
           , port        VARCHAR(10)
          )
    /* databases infos */
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_db]') AND type IN (N'U'))
       DROP TABLE [dbo].[cmdb_db]
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_db]') AND type IN (N'U'))
       CREATE TABLE [dbo].[cmdb_db]
          (  srvname   varchar(50)
           , dbname    varchar(150)
           , nameduser varchar(50)
           , schemas   varchar(50)
		   , dbsize    varchar(50)
          )
    /* schemas infos */
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_schema]') AND type IN (N'U'))
       DROP TABLE [dbo].[cmdb_schema]
    IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cmdb_schema]') AND type IN (N'U'))
       CREATE TABLE [dbo].[cmdb_schema]
          (  srvname    varchar(50)
           , dbname     varchar(150)
           , schemaname varchar(256)
          )

    /* get instance name */
    SET @keyname   = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    EXEC master..xp_regread 
        @rootkey='HKEY_LOCAL_MACHINE'
      , @key=@keyname
      , @value_name=@instancename
      , @value=@pathname OUTPUT
      --print @pathname
    /* get tcp/ip port is dynamic */
    SET @keyname = 'SOFTWARE\Microsoft\Microsoft SQL Server\'+@pathname+'\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
          -- print @keyname
    EXEC master..xp_regread 
        @rootkey='HKEY_LOCAL_MACHINE'
      , @key=@keyname
      , @value_name='TcpDynamicPorts'
      , @value=@tcpipportdyn OUTPUT
    IF @tcpipportdyn <> ''
      BEGIN
        SET @tcpipportdynbit = 1
        SET @tcpport = 0
      END
    ELSE
      BEGIN
        SET @tcpipportdynbit = 0
        /* get tcp/ip port number */
        set @keyname = 'SOFTWARE\Microsoft\Microsoft SQL Server\'+@pathname+'\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
            -- print @keyname
        EXEC master..xp_regread 
            @rootkey='HKEY_LOCAL_MACHINE'
          , @key=@keyname
          , @value_name='TcpPort'
          , @value=@tcpport OUTPUT
        END

  -- ----------------------------------------------------------------------------
  -- insert server infos
  -- ----------------------------------------------------------------------------
  INSERT INTO cmdb_server (srvname, instname, srvintname, sqledition, sqlversion, sqlsp, dport, port) VALUES (@servername, @instancename, @srvintname, @sqledition, @sqlversion, @sqlsrvicepack, @tcpipportdynbit, @tcpport)
  -- ----------------------------------------------------------------------------
  -- get databases and schemas infos
  -- ----------------------------------------------------------------------------
  /* cursor to get db names */
	IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 	
		BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
			DECLARE cur_db INSENSITIVE CURSOR FOR
				SELECT name FROM sys.databases
							WHERE NAME NOT IN ('master', 'msdb', 'model', 'tempdb')
							AND state = 0 /* state 0 = online */
							AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
							OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
																JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																WHERE primary_replica = @@SERVERNAME)
				ORDER BY 1
		END
	ELSE
		BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
			DECLARE cur_db INSENSITIVE CURSOR FOR
				SELECT name FROM sys.databases
							WHERE name NOT IN ('master', 'msdb', 'model', 'tempdb', 'IT2_SysAdmin')
							AND state_desc = 'ONLINE'
				ORDER BY 1
		END
  OPEN cur_db
  FETCH NEXT FROM cur_db INTO @dbname
  WHILE @@FETCH_STATUS = 0
     BEGIN
        INSERT INTO cmdb_db (srvname, dbname) VALUES (@srvintname, @dbname)
        --print 'after insert'
        SET @stmt = 'update IT2_SysAdmin..cmdb_db set nameduser = (select count(*) from ['+@dbname+'].sys.schemas where schema_id != USER_ID(''sys'') and  schema_ID < 16000 and name != ''guest'' and name != ''NT AUTHORITY\SYSTEM'' and name != ''INFORMATION_SCHEMA'') where dbname ='''+@dbname+''''
        --print @stmt
        EXEC (@stmt)
        SET @stmt = 'use ['+@dbname+']; update IT2_SysAdmin..cmdb_db set schemas = (select count(*) from ['+@dbname+'].sys.schemas where schema_id != USER_ID(''sys'') and name != ''guest'' and name != ''NT AUTHORITY\SYSTEM'' and name != ''INFORMATION_SCHEMA'' and schema_id <16000) where dbname = '''+@dbname+''''
        EXEC (@stmt)
		--Einfügen der Datenbankgrösse (melih)
		SET @stmt = 'update IT2_SysAdmin..cmdb_db set dbsize = (SELECT sum(size/128) FROM ['+@dbname+'].sys.database_files ) where dbname = '''+@dbname+''''
		EXEC (@stmt)
        -- -------------------------------------------
        -- get schema names
        -- -------------------------------------------
        SET @stmt = 'truncate table #tschemaname; use ['+@dbname+']; insert into #tschemaname select name from ['+@dbname+'].sys.schemas where schema_id != USER_ID(''sys'') and  schema_ID < 16000 and name != ''guest'' and name != ''NT AUTHORITY\SYSTEM'' and name != ''INFORMATION_SCHEMA'' and schema_id in (select schema_id from sys.tables)'
        EXEC (@stmt)
        DECLARE cur_schema INSENSITIVE CURSOR FOR select schemaname from #tschemaname
        OPEN cur_schema
        FETCH NEXT FROM cur_schema INTO @schemaname
        WHILE @@FETCH_STATUS = 0
           BEGIN
             insert into IT2_SysAdmin..cmdb_schema (srvname, dbname, schemaname) values (@srvintname,@dbname, @schemaname)
             -- exec (@stmt)
             FETCH NEXT FROM cur_schema INTO @schemaname
           END
           CLOSE cur_schema
           DEALLOCATE cur_schema
        FETCH NEXT FROM cur_db INTO @dbname
     END
  CLOSE cur_db
  DEALLOCATE cur_db
  DROP TABLE #tschemaname
    -- ----------------------------------------------------------------
    -- output to files
    -- ----------------------------------------------------------------
    -- server
    -- ------
    SELECT @resultfilename = 'cmdb_'+REPLACE((SELECT CONVERT(VARCHAR(50), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))), '\', '_')+'_'+@instancename+'_server_'+REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 126),'-', ''), ':', ''), 'T', ''), '.', '')+'.log'
		SELECT @resultfilename = 'cmdb_'+REPLACE((SELECT CONVERT(VARCHAR(50), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))), '\', '_')+'_'+@instancename+'_server_'+REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 126),'-', ''), ':', ''), 'T', ''), '.', '')+'.log'
		SELECT @stmt = 'execute IT2_SysAdmin..USP_WRITE_STRING_TO_FILE '''+srvname+';'+instname+';'+srvintname+';'+sqledition+';'+sqlversion+';'+sqlsp+';'+dport+';'+port+''',''C:\TEMP'','''+@resultfilename+'''' from IT2_SysAdmin..cmdb_server
		--print @stmt
		EXEC (@stmt)
    -- --
    -- db
    -- --
    SELECT @resultfilename = 'cmdb_'+replace((SELECT CONVERT(varchar(50), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))), '\', '_')+'_'+@instancename+'_db_'+REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 126),'-', ''), ':', ''), 'T', ''), '.', '')+'.log'
    SET @txtoutput = '' -- clear the variable
    /* cursor to get table data into one string */
    DECLARE cur_getdbdata CURSOR FOR SELECT srvname+';'+dbname+';'+nameduser+';'+schemas+';'+dbsize+CHAR(13)+CHAR(10)  FROM IT2_SysAdmin..cmdb_db
    OPEN cur_getdbdata
    FETCH NEXT FROM cur_getdbdata INTO @tempoutput
    WHILE @@fetch_status = 0
      BEGIN
         SET @txtoutput = isnull(@txtoutput, '')+@tempoutput
         FETCH NEXT FROM cur_getdbdata INTO @tempoutput
      END
    CLOSE cur_getdbdata
    DEALLOCATE cur_getdbdata
    EXECUTE IT2_SysAdmin..USP_WRITE_STRING_TO_FILE @txtoutput, 'C:\Temp', @resultfilename
    -- ------
    -- schema
    -- ------
    --select SERVERPROPERTY('servername')
    SELECT @resultfilename = 'cmdb_'+replace((SELECT CONVERT(VARCHAR(50), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))), '\', '_')+'_'+@instancename+'_schema_'+replace(replace(replace(replace(convert(varchar, getdate(), 126),'-', ''), ':', ''), 'T', ''), '.', '')+'.log'
    SET @txtoutput = '' -- clear the variable
    /* cursor to get table data into one string */
    DECLARE cur_getschemadata CURSOR FOR SELECT srvname+';'+dbname+';'+schemaname+CHAR(13)+CHAR(10) FROM IT2_SysAdmin..cmdb_schema
    OPEN cur_getschemadata
    FETCH NEXT FROM cur_getschemadata INTO @tempoutput
    WHILE @@fetch_status = 0
      BEGIN
         SET @txtoutput = isnull(@txtoutput, '')+@tempoutput
         FETCH NEXT FROM cur_getschemadata into @tempoutput
      END
    CLOSE cur_getschemadata
    DEALLOCATE cur_getschemadata
    EXECUTE IT2_SysAdmin..USP_WRITE_STRING_TO_FILE @txtoutput, 'C:\Temp', @resultfilename

-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO