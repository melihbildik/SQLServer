USE IT2_SysAdmin
GO
-- 14 Procedure USP_LOGON_ERRORS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_LOGON_ERRORS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_LOGON_ERRORS','$(pstdvers)',GETDATE(),'1.02')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.02', modified = GETDATE() WHERE tab_proc_name = 'USP_LOGON_ERRORS'
GO
PRINT '---------------------------------------
14 create [USP_LOGON_ERRORS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_LOGON_ERRORS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_LOGON_ERRORS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_LOGON_ERRORS]  
-- ------------------------------------------------------------------
-- Object Name:           USP_LOGON_ERRORS
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  04.03.10
-- Autor:                 Roger Bugmann, IT226 
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Login Failed werden Protokolliert
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- 
-- 
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor			Version		Date		What
-- Roger Bugmann, IT226		1.00		04.03.10	erste Version
-- Roger Bugmann, IT226		1.01		05.03.10	Begin try/catch, keine doppelten Daten
-- Roger Bugmann, IT226		1.02		16.04.13	Nur Login failed protokollieren
-- ------------------------------------------------------------------------------------------------
 AS
    -- --------------------------
    -- Declare internal variables
    -- --------------------------
DECLARE @errorlog TABLE (LogID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        LogDate DATETIME NULL, 
        ProcessInfo NVARCHAR(100) NULL,
        LogText NVARCHAR(4000) NULL) 

DECLARE @error VARCHAR(2000)

INSERT INTO @errorlog (LogDate, ProcessInfo, LogText)
EXEC master..xp_readerrorlog --0,1, 'Login','failed',null,null 

    -- --------------------------------
    -- Insert Into Tabele logon_errors
    -- --------------------------------
BEGIN TRY    
	INSERT INTO dbo.logs (proc_id,loginame, usrname, action_time, db, [message],errnr, [type],[source])
	SELECT LogID, SYSTEM_USER, USER, LogDate, ProcessInfo, LogText, '78999','WARNING','LOGON_ERRORS'
	FROM @errorlog
	WHERE CHARINDEX('Login failed', LogText ) = 1
	AND LogID NOT IN( SELECT proc_id FROM logs WHERE proc_id IS NOT null)
	ORDER BY LogID DESC 
END TRY
BEGIN CATCH
--	 insert into [IT2_SysAdmin].[dbo].logs (db, [message], action_time,[type],[source])
--						values('Logon', ERROR_message(), GETDATE(),'INFO','LOGON_ERRORS')
	INSERT INTO [IT2_SysAdmin].[dbo].logs (proc_id,loginame, usrname, action_time, db, [message],errnr, [type],[source])
         (SELECT   @@SPID
                 , SYSTEM_USER
                 , USER
                 , CURRENT_TIMESTAMP
                 , 'Logon'
                 , ERROR_MESSAGE()
                 , '78999'
                 , 'ERROR'
                 , 'LOGON_ERRORS')

			 -- WindowsEventlog Eintrag erstellen
			SELECT @error = ERROR_MESSAGE()
			EXEC xp_logevent 60000, @error , WARNING
END CATCH
            

-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO