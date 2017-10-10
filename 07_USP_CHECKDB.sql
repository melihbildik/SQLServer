USE IT2_SysAdmin
GO
-- 07 Procedure USP_CHECKDB
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_CHECKDB') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_CHECKDB','$(pstdvers)',GETDATE(),'1.02')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.02', modified = GETDATE() WHERE tab_proc_name = 'USP_CHECKDB'
GO
PRINT '---------------------------------------
07 create [USP_CHECKDB]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_CHECKDB' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_CHECKDB]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE  PROCEDURE [dbo].[USP_CHECKDB] 
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_CHECKDB
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Synonym:               on master db : none
-- Verstion:              1.0
-- Date:                  25.05.09
-- Autor:                 Melih Bildik, IT226 (smartdynamic AG)
-- Copyright:             ©Die Schweizerische Post 2009
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Führt ein CheckDB für alle Datenbanken aus
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
-- Autor			Version		Date		What
-- Melih Bildik, IT2		1.0		25.05.09	first pubicated version
-- Roger Bugmann, IT226		1.01		20100201	Neue Versionierung
-- Roger Bugmann, IT226		1.02		201208025	Dbname varchar(150)
-- ------------------------------------------------------------------------------------------------
  AS
    -- --------------------------------------------------------------------------------------------
    -- variables declaration 
    -- --------------------------------------------------------------------------------------------
    DECLARE  @dbname       VARCHAR(150)
          ,  @dbid		   INT
          ,	 @hidb		   INT
          ,  @error		   VARCHAR(2000)
  
      -- ------------------------------------------------------------------------------------------
      -- execute statments 
      -- ------------------------------------------------------------------------------------------
     SELECT @hidb = MAX(database_id ),@dbid = 0
		FROM sys.databases
		WHILE @dbid <= @hidb
		BEGIN
		 SET @dbname = NULL
		  SELECT @dbname = name FROM sys.databases
			WHERE database_id = @dbid
			AND state = 0 
			 
			IF @dbname IS NOT NULL
				BEGIN TRY
					DBCC CheckDB( @dbname )
					PRINT @dbname
				END TRY
				
				BEGIN CATCH
					-- Errorhandling
					--print error_message()
					INSERT INTO logs(db, [message], action_time,[type],[source])
					VALUES(@dbname, ERROR_message(), GETDATE(),'ERROR','CHECKDB')
					-- WindowsEventlog Eintrag erstellen
					SELECT @error = ERROR_MESSAGE()
					EXEC xp_logevent 60000, @error , ERROR
				END CATCH
			SET @dbid = @dbid + 1
		END
 
  -- ----------------------------------------------------------------------------------------------
  -- EOF
  -- ----------------------------------------------------------------------------------------------
GO