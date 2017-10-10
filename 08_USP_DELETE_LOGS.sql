USE IT2_SysAdmin
GO
-- 08 Procedure USP_DELETE_LOGS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_DELETE_LOGS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_DELETE_LOGS','$(pstdvers)',GETDATE(),'1.01')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.01', modified = GETDATE() WHERE tab_proc_name = 'USP_DELETE_LOGS'
GO
PRINT '---------------------------------------
08 create [USP_DELETE_LOGS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_DELETE_LOGS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_DELETE_LOGS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_DELETE_LOGS]
-- ------------------------------------------------------------------
-- Object Name:           usp_delete_logs
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Version:		  2.0
-- Date:                  01.09.2009
-- Autor:                 Melih Bildik, IT226 (smartdynamic AG 2009)
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Diese SP löscht alle Logtabellen die durch die SystemScripts gefüllt werden
-- IT2SysAdminDB und MSDB
-- Die Daten werden 100 Tage aufbewahrt.
-- ------------------------------------------------------------------
-- Parameter:
-- ==========
-- ------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor			Version		Date		Description
-- Melih Bildik, IT226		1.0		01.09.2009	erste version
-- Roger Bugmann, IT226		1.01		20100201	Neue Versionierung
-- ------------------------------------------------------------------
  AS
  -- ----------------------------------------------------------------
  -- settings
  -- ----------------------------------------------------------------
  SET NOCOUNT ON
  -- ----------------------------------------------------------------
  -- variables
  -- ----------------------------------------------------------------
  DECLARE
      @stmt         VARCHAR(8000)
    , @winmsg       VARCHAR(4000)
    , @date			DATETIME
    , @error		VARCHAR(2000)
  -- ----------------------------------------------------------------
  -- Daten aus der IT2 DB löschen
  -- ----------------------------------------------------------------
  BEGIN TRY
	  DELETE FROM IT2_SysAdmin..logs
			 WHERE action_time < (GETDATE()-100) --datediff(day,@datum,getdate())
  END TRY
  
  BEGIN CATCH
    INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES('IT2_SysAdmin', ERROR_MESSAGE(), GETDATE(),'ERROR','LogDelete')
  -- WindowsEventlog Eintrag erstellen
	SELECT @error = ERROR_MESSAGE()
	EXEC xp_logevent 60000, @error , ERROR
  END CATCH

  
  -- ------------------------------------------------------------------------------------------------
  -- Daten aus der MSDB löschen
  -- ------------------------------------------------------------------------------------------------
BEGIN TRY
	SELECT @date = CONVERT(VARCHAR, DATEADD(DAY, -100, GETDATE()))
	EXEC msdb.dbo.sp_delete_backuphistory @oldest_date = @date
END TRY

BEGIN CATCH
	INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES('MSDB', ERROR_MESSAGE(), GETDATE(),'ERROR','LogDelete')
-- WindowsEventlog Eintrag erstellen
	SELECT @error = ERROR_MESSAGE()
	EXEC xp_logevent 60000, @error , ERROR
END CATCH
  
-- ----------------------------------------------------------------
-- EOF
-- ----------------------------------------------------------------
GO