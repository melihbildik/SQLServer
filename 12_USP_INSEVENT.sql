USE IT2_SysAdmin
GO
-- 12 Procedure USP_INSEVENT
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_INSEVENT') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_INSEVENT','$(pstdvers)',GETDATE(),'1.02')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.02', modified = GETDATE() WHERE tab_proc_name = 'USP_INSEVENT'
GO
PRINT '---------------------------------------
12 create [USP_INSEVENT]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_INSEVENT' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_INSEVENT]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_INSEVENT]
    @errornr    INT           = '' -- is a number upper 70000, see error number convention on "intranet seiten"
  , @dbapplname VARCHAR(50)   = '' -- should be the name of the db or the application which generate the problem
  , @msg        VARCHAR(4000) = '' -- is free text which schould explain to user where is the problem and how solve it
  , @severity   VARCHAR(20)   = '' -- is the windows severity settings see parameter description
-- ------------------------------------------------------------------
-- Object Name:           usp_insevent
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Synonym:               on master db : usp_insevent
-- Verstion:              1.0
-- Date:                  2007-02-06 17:00
-- Autor:                 Laurent Finger, IT226
-- Copyright:             ©Die Schweizerische Post 2007
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Diese storage procedure standartisiert und vereifacht das Schreiben
-- von Fehler Meldungen in das Windows eventlog und in die Tabelle
-- logs der Datenbank IT2_SysAdmin.
-- ------------------------------------------------------------------
-- Parameter:
-- ==========
--   - Fehler Meldung Nummer (muss gemäss "intranet Seite")
--   - Datenbank Name oder Applikation Name
--   - Gewünschte Meldung, was schief gegangen ist und wie es lösen
--   - Severity Level für Windows Event Log
--       - Null = wird nichts ins eventlog geschrieben
--       - i = informational (blaue Meldungen)
--       - w = warings (gelbe Meldungen)
--       - e = error (rote Meldungen, die kommen ins HP Open View...)
-- ------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor			Version		Date		What
-- Laurent Finger, IT2		1.00		20070207	first pubicated version   
-- Roger Bugmann, IT226		1.02		20100201	Neue Versionierung
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
      @stmt               VARCHAR(8000)
  -- ----------------------------------------------------------------
  -- check parameters
  -- ----------------------------------------------------------------
  IF @errornr < 70000
    or @dbapplname = ''
    or @msg = ''
    or (@severity not in (null, 'i', 'w', 'e'))
    BEGIN
      EXEC MASTER..xp_logevent 70000, 'storage procedure sp_insevent ist mit inkorektes parameter gestarted worden', ERROR
      INSERT INTO it2_sysadmin..logs
         (proc_id, loginame, usrname, action_time, db, message)
         (SELECT   @@SPID
                 , SYSTEM_USER
                 , USER
                 , CURRENT_TIMESTAMP
                 , 'storage procedure sp_insevent'
                 , 'die sp ist mit inkorektes parameter gestarted worden'
         )
      RETURN -- exit of the sp
    END
  -- ----------------------------------------------------------------
  -- variables declarations
  -- ----------------------------------------------------------------
  DECLARE @winmsg VARCHAR(4000)
  SET @winmsg = @dbapplname +': '+@msg
  -- ----------------------------------------------------------------
  -- set values to variables
  -- ----------------------------------------------------------------
  IF @severity = 'i'
    SET @severity = 'INFORMATIONAL'
  IF @severity = 'w'
    SET @severity = 'WARNING'
  IF @severity = 'e'
    SET @severity = 'ERROR'
  -- print @severity
  -- ----------------------------------------------------------------
  -- check if logs table in it2_sysadmin db is already created
  -- ----------------------------------------------------------------
  IF NOT EXISTS
    (SELECT * FROM IT2_sysadmin.dbo.sysobjects
     WHERE id = object_id(N'[IT2_SysAdmin].[dbo].[logs]'))
     BEGIN
       SET @stmt='
         CREATE TABLE [dbo].[logs](
	         [logid] [int] IDENTITY(1,1) NOT NULL,
	         [proc_id] [int] NULL,
	         [loginame] [varchar](50) NULL,
	         [usrname] [varchar](50)  NULL,
	         [action_time] [smalldatetime] NOT NULL,
	         [db] [varchar](50) NULL,
	         [message] [varchar](4000) NULL,
	         [errNr] [int] NULL,
          CONSTRAINT [PK_logs] PRIMARY KEY CLUSTERED 
         (
	        [logid] ASC
         ) ON [USER01]
         ) ON [USER01]'
       EXEC (@stmt)
       EXEC master..xp_logevent 70000, 'Die Tabelle logs in die Datenbank IT2_Sysadmin existiert nicht, die Storage Procedure master..sp_insevent hat die kreiert' , 'Informational'
     END
  -- ----------------------------------------------------------------
  -- insert string into windows eventlog
  -- ----------------------------------------------------------------
  IF @severity IS NOT NULL
  EXEC master..xp_logevent @errornr, @winmsg , @severity
  -- ----------------------------------------------------------------
  -- insert values into it2_sysadmin logs table
  -- ----------------------------------------------------------------
  INSERT INTO it2_sysadmin..logs
         (proc_id, loginame, usrname, action_time, db, message, errnr)
         (SELECT   @@SPID
                 , SYSTEM_USER
                 , USER
                 , CURRENT_TIMESTAMP
                 , @dbapplname
                 , @msg
                 , @errornr
         )
-- ----------------------------------------------------------------
-- EOF
-- ----------------------------------------------------------------
GO