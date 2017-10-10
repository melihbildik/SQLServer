USE IT2_SysAdmin
GO
-- 06 Procedure USP_INDEX_REORGANIZE
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_INDEX_REORGANIZE') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_INDEX_REORGANIZE','$(pstdvers)',GETDATE(),'2.03')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '2.03', modified = GETDATE() WHERE tab_proc_name = 'USP_INDEX_REORGANIZE'
GO
PRINT '---------------------------------------
06 create [USP_INDEX_REORGANIZE]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_INDEX_REORGANIZE' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_INDEX_REORGANIZE]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_INDEX_REORGANIZE]
 @databasename VARCHAR(100) = ''  /* if defined, only this database will be done */
AS
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_INDEX_REORGANIZE
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Verstion:              2
-- Date:                  25.11.09
-- Autor:                 Melih Bildik smartdynamic AG
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Diese SP reorganisiert alle Indexe einer Datenbank
-- als Parameter kann der Datenbankname mitgegeben werden
-- Wird kein Parameter mitgegeben sind alle Datenbanken betroffen
--
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- @databasename Name der Datenbank bei der alle Indexe reorganisiert werden sollen
-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor                			Version		Date		What
-- Melih Bildik						2.0			25.11.09	Erstellt
-- Roger Bugmann, IT226				2.01		20100201	Neue Versionierung
-- Roger Bugmann, IT226				2.02		20130425	AO Gruppen Anpassungen
-- Kunabalasingam Kaureesan, IT234	2.03		20151207	Abfrage ProdctVersion >= 11.% in Database Cursor: cur_db
-- ------------------------------------------------------------------------------------------------
  BEGIN
  -- ----------------------------------------------------------------------------------------------
  -- script settings
  -- ----------------------------------------------------------------------------------------------
  SET NOCOUNT ON
  SET QUOTED_IDENTIFIER ON
  SET ANSI_NULLS ON
  SET TEXTSIZE 10000
  SET ARITHABORT ON
  -- ----------------------------------------------------------------------------------------------
  -- variables declaration
  -- ----------------------------------------------------------------------------------------------
  DECLARE @dbname        SYSNAME       /* db name from cursor */
        , @db_id         SMALLINT      /* db id */
        , @db_name       NVARCHAR(128) /* db name from func db_name() */
        , @object_id     INT
        , @owner         SYSNAME       /* owner of the table */
        , @table_name    SYSNAME
        , @table_id      INT
        , @txt           VARCHAR(4000) /* text only */ 
        , @stmt          VARCHAR(4000) /* statment to be runned */
        , @idx_name      VARCHAR(256)
        , @idx_id        INT
        , @idx_cnt       INT           /* count how many partitions per index */
        , @partition_nbr INT           /* partition number from an index */
        , @ispagelock    BIT           /* 0 is activated 1 is deactivated */

  -- ------------------------------------------------------------------------------------------------
  -- temptabelle für die statements
  -- ------------------------------------------------------------------------------------------------
  CREATE TABLE #cmd (db VARCHAR(100), cmd VARCHAR(4000))  /*tmp table to store final statments to rebuild/reorganize indexes*/


  -- ===================================================================================
  -- Alle nötigen Daten holen
  -- ===================================================================================
  /* cursor für alle Datenbanken */
  IF @databasename = ''
    BEGIN	
		IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 	
			BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
				DECLARE cur_db INSENSITIVE CURSOR FOR
					SELECT name FROM sys.databases 
								WHERE state = 0 /* status online */ 
								AND name NOT IN ('master', 'model', 'tempdb')
								AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
								OR name IN (SELECT a.database_name	FROM sys.availability_databases_cluster a
																	JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																		WHERE primary_replica = @@SERVERNAME)
					ORDER BY name
			END
		ELSE
			BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
				DECLARE cur_db INSENSITIVE CURSOR FOR
					SELECT name FROM sys.databases 
								WHERE state = 0 /* status online */ 
								AND name NOT IN ('master', 'model', 'tempdb')
					ORDER BY name
			END
    END
  ELSE
    BEGIN
      DECLARE cur_db INSENSITIVE CURSOR 
      FOR SELECT name  
          FROM sys.databases 
          WHERE state = 0 /* status online */ 
          AND name = @databasename
    END
  OPEN cur_db
  FETCH NEXT FROM cur_db INTO @dbname
  WHILE @@FETCH_STATUS = 0
    BEGIN -- a
      SET @db_id = DB_ID(@dbname)
      SET @db_name = DB_NAME(@db_id)
      /* cursor für jeden index der jeweiligen db */
      SET @stmt = 'use ['+@db_name+'];
                   DECLARE cur_objects CURSOR FOR
                   select count(*)
                        , i.name
                        , i.index_id
                        , o.name
                        , o.object_id
                        , s.name
                        , indexproperty(o.object_id, i.name, ''IsPageLockDisallowed'')
                   from sys.partitions p
                      , sys.indexes i
                      , sys.objects o
                      , sys.schemas s
                   where p.index_id >0
                     and p.index_id=i.index_id
                     and i.object_id=o.object_id
                     and p.object_id=o.object_id
                     and o.type = ''U''
                     and s.schema_id=o.schema_id
                   group by i.name, i.index_id, o.name, o.object_id, s.name
                   order by i.name, i.index_id'
     --PRINT @stmt
      EXEC (@stmt)
      OPEN cur_objects
      FETCH NEXT FROM cur_objects INTO @idx_cnt, @idx_name, @idx_id, @table_name, @table_id, @owner, @ispagelock
      WHILE @@FETCH_STATUS = 0
        BEGIN -- 
            INSERT INTO #cmd (db, cmd) VALUES(@db_name, 'alter index ['+@idx_name+'] on ['+@owner+'].['+@table_name+'] REORGANIZE ')
			FETCH NEXT FROM cur_objects INTO @idx_cnt, @idx_name, @idx_id, @table_name, @table_id, @owner, @ispagelock
         END
          
       -- END -- b end cursor cur_objects
      CLOSE cur_objects
      DEALLOCATE cur_objects
      FETCH NEXT FROM cur_db INTO @dbname
    END -- end a cursor db
  CLOSE cur_db
  DEALLOCATE cur_db

  -- ===================================================================================
  -- execute reorganize commands
  -- ===================================================================================
  DECLARE cur_stmt CURSOR FOR
  SELECT db, cmd FROM #cmd
  OPEN cur_stmt
  FETCH NEXT FROM cur_stmt into @dbname, @txt
  WHILE @@FETCH_STATUS = 0
    BEGIN
      SET @stmt = 'USE ['+@dbname+']; '+@txt
       --print @stmt
       BEGIN TRY
        EXEC (@stmt)
       END TRY
       BEGIN CATCH
       	--print error_message()
		INSERT INTO logs(db, [message], action_time,[type],[source])
			VALUES(@db_name, ERROR_message()+@stmt, GETDATE(),'ERROR','IndexREORGANIZE')
       END CATCH
      FETCH NEXT FROM cur_stmt INTO @dbname, @txt
    END
  CLOSE cur_stmt
  DEALLOCATE cur_stmt
  --
  -- drop temp table
  --
 DROP TABLE #cmd
END -- end of procedure
-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO