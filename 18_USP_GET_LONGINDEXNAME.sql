USE [IT2_SysAdmin]
GO
-- 18 Procedure USP_GET_LONGINDEXNAME
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_GET_LONGINDEXNAME') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_GET_LONGINDEXNAME','$(pstdvers)',GETDATE(),'1.03')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.03', modified = GETDATE() WHERE tab_proc_name = 'USP_GET_LONGINDEXNAME'
GO
PRINT '---------------------------------------
18 create [USP_GET_LONGINDEXNAME]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_GET_LONGINDEXNAME' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_GET_LONGINDEXNAME]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE  PROCEDURE [dbo].[USP_GET_LONGINDEXNAME] 
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_GET_LONGINDEXNAME
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Synonym:               
-- Version:               1.0
-- Date:                  29.05.2012
-- Autor:                 Melih Bildik, IT226
-- Copyright:             ?Die Schweizerische Post 2012
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Schickt alle Indexe mit einer Namen ?ber 100 Zeichen an den CentralServer
-- 
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- keine
-- ------------------------------------------------------------------------------------------------
-- Possible improvement
-- ====================
-- 
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Melih Bildik, smartdynamic		1.00		29.05.12	erstellt
-- Roger Bugmann, IT226				1.01		21.03.13	Angepassungen für HA Gruppen
-- Roger Bugmann, IT226				1.02		27.04.2015	Abfrage ProdctVersion >= 11.% in Database Cursor
-- Roger Bugmann, IT222				1.03		03.07.2015	Delete verpackt in EXECUTE
-- ------------------------------------------------------------------------------------------------
  AS
    -- --------------------------------------------------------------------------------------------
    -- variables declaration 
    -- --------------------------------------------------------------------------------------------
    DECLARE @dbname       AS VARCHAR(100)
          , @instance     AS VARCHAR(100)
          , @index		  AS VARCHAR(300)
		  , @stmt		  AS VARCHAR(1000)
    -- --------------------------------------------------------------------------------------------
    -- Alte Daten loeschen
    -- --------------------------------------------------------------------------------------------
	EXECUTE (' DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[longindexnames] WHERE instance = @@SERVERNAME ')
    -- --------------------------------------------------------------------------------------------
    -- Databases cursor
    -- --------------------------------------------------------------------------------------------
   	IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 	
		BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
			DECLARE cur_db CURSOR FOR
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
				SELECT name FROM master.sys.databases
							WHERE NAME NOT IN ('master', 'msdb', 'model', 'tempdb')
							AND state = 0 /* state 0 = online */
				ORDER by name 
		END
	
	OPEN cur_db
    -- first fetch of cursor
    FETCH NEXT FROM cur_db
    INTO @dbname
    -- start the main part
    WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @stmt = 'use ['+@dbname+'];
					 INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[longindexnames]
					   ([instance]
					   ,[database]
					   ,[table]
					   ,[indexname])
						select @@SERVERNAME,''['+@dbname+']'', OBJECT_NAME(object_id) as [table], name  from sys.indexes
						where len(name) > 50'
        
        EXEC (@stmt)
        FETCH NEXT FROM cur_db
        INTO @dbname
      END
    CLOSE cur_db
    DEALLOCATE cur_db
  -- ----------------------------------------------------------------------------------------------
  -- EOF
  -- ---------------------------------------------------------------------------------------------
GO

