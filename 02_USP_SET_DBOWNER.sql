USE IT2_SysAdmin
GO
-- 02 Procedure USP_SET_DBOWNER
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_SET_DBOWNER') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_SET_DBOWNER','$(pstdvers)',GETDATE(),'1.04')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.04', modified = GETDATE() WHERE tab_proc_name = 'USP_SET_DBOWNER'
GO
PRINT '---------------------------------------
02 create [USP_SET_DBOWNER]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_SET_DBOWNER' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_SET_DBOWNER]
GO
-- ------------------------------------------------------------------------------------------------
-- Prozeduren erstellen
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_SET_DBOWNER] 
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_SET_DBOWNER
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Synonym:               on master db : USP_SET_DBOWNER
-- Verstion:              1.0
-- Date:                  2007-02-26 16:00
-- Autor:                 Laurent Finger, IT226
-- Copyright:             ©Die Schweizerische Post 2007
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Set SA als DB Owner für alle User Datenbanken.
-- Erstellt der aktuelle db owner als Benutzer mit db_owner Rolle in der Datenbank
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
-- Laurent Finger, IT2				1.0			20070226	first pubicated version
-- Roger Bugmann, IT226				1.01		20100201	Neue Versionierung
-- Roger Bugmann, IT226				1.02		20130425	HA Group Check
-- Roger Bugmann, IT226				1.03		20140624	[] bei dbname, wegen Datenbanken mit Leerschlag im Namen
-- Kunabalasingam Kaureesan, IT234	1.04		20151207	Abfrage ProdctVersion >= 11.% in Database Cursor: cur_db
-- ------------------------------------------------------------------------------------------------
  AS
    -- --------------------------------------------------------------------------------------------
    -- variables declaration 
    -- --------------------------------------------------------------------------------------------
    DECLARE	@dbname       AS sysname
          , @stmt         AS VARCHAR(4000)
          , @stmtusr      AS VARCHAR(4000)
          , @owner        AS VARCHAR(1000)
          , @msg          AS VARCHAR(4000)
    -- --------------------------------------------------------------------------------------------
    -- loggings settings
    -- --------------------------------------------------------------------------------------------
      DECLARE @applname   AS  VARCHAR(50)   /* application name for usp_ins/del-event */
            , @logkeep    AS  INT           /* days to keekp log infos */
      -- Settings
      SET @applname = 'DB Owner setzen'
      SET @logkeep = 360 /* days */
    -- --------------------------------------------------------------------------------------------
    -- runnings settings
    -- --------------------------------------------------------------------------------------------
    SET NOCOUNT ON
    -- --------------------------------------------------------------------------------------------
    -- Databases cursor
    -- --------------------------------------------------------------------------------------------
    IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 
		BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
			DECLARE cur_db INSENSITIVE CURSOR FOR
				SELECT SUSER_SNAME(owner_sid), name
					FROM master.sys.databases
					WHERE NAME NOT IN ('master', 'msdb', 'model', 'tempdb')
					AND state = 0 /* state 0 = online */
					AND SUSER_SNAME(owner_sid) <> 'sa'
					AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
					OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
							JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
								WHERE primary_replica = @@SERVERNAME
								AND SUSER_SNAME(owner_sid) <> 'sa')
				ORDER by name
		
		END	
	ELSE		
		BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
			DECLARE cur_db INSENSITIVE CURSOR FOR
				SELECT SUSER_SNAME(owner_sid), name
					FROM master.sys.databases
					WHERE NAME NOT IN ('master', 'msdb', 'model', 'tempdb')
					AND state = 0 /* state 0 = online */
					AND SUSER_SNAME(owner_sid) <> 'sa'
				ORDER BY name
		END
    -- cursor open
    OPEN cur_db
    -- first fetch of cursor
    FETCH NEXT FROM cur_db
    INTO @owner, @dbname
    -- start the main part
    WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @stmt = 'use ['+@dbname+']; exec sp_changedbowner ''sa'''
        SET @stmtusr = 'use ['+@dbname+']; exec sp_adduser @loginame = '''+@owner+''' , @name_in_db = '''+@owner+''', @grpname = ''db_owner'''
       
        EXEC (@stmt)
        EXEC (@stmtusr)
        FETCH NEXT FROM cur_db
        INTO @owner, @dbname
      END
    CLOSE cur_db
    DEALLOCATE cur_db
  -- ----------------------------------------------------------------------------------------------
  -- EOF
  -- ---------------------------------------------------------------------------------------------
GO