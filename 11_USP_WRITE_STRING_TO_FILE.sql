USE IT2_SysAdmin
GO
-- 11 Procedure USP_WRITE_STRING_TO_FILE
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_WRITE_STRING_TO_FILE') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_WRITE_STRING_TO_FILE','$(pstdvers)',GETDATE(),'1.02')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.02', modified = GETDATE() WHERE tab_proc_name = 'USP_WRITE_STRING_TO_FILE'
GO
PRINT '---------------------------------------
11 create [USP_WRITE_STRING_TO_FILE]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_WRITE_STRING_TO_FILE' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_WRITE_STRING_TO_FILE]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_WRITE_STRING_TO_FILE]
  -- ------------------------------------------------------------------------------------------------
  -- Object Name:           USP_WRITE_STRING_TO_FILE
  -- Object Type:           stoered procedure
  -- Database:              IT2_SysAdmin
  -- Synonym:               on master db : none
  -- Version:               1.1
  -- Date:                  2008-04-15 10:00
  -- Autor:                 Bildik Melih, IT226
  -- Copyright:             ©Die Schweizerische Post 2008
  -- ------------------------------------------------------------------------------------------------
  -- Used for:
  -- =========
  -- This sp write a string to a file in the specified path
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Parameter:
  -- ==========
  -- String		(Textinhalt)
  -- Path		(Bsp: C:\Temp)
  -- Filename	
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Possible improvement
  -- ====================
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Last Modification:
  -- ==================
  -- Autor				Version		Date		What
  -- Bildik Melih, IT226		1.0		20080415	first pubicated version
  -- Schmid Heinz, IT263		1.1		20090507	rename sp 
  -- Roger Bugmann, IT226		1.02		20100201	Neue Versionierung
  -- ------------------------------------------------------------------------------------------------
 (  @string   VARCHAR(MAX) --8000 in SQL Server 2000
  , @path     VARCHAR(255)
  , @filename VARCHAR(100)
 )
AS
  DECLARE @objfilesystem	 INT
	      , @objtextstream   INT
	      , @objerrorobject  INT
	      , @strerrormessage VARCHAR(1000)
	      , @command         VARCHAR(1000)
	      , @hr              INT
	      , @fileandpath     VARCHAR(80)

  SET NOCOUNT ON

  SELECT @strerrormessage='opening the File System Object'
  EXECUTE @hr = sp_OACreate  'Scripting.FileSystemObject' , @objfilesystem OUT

  SELECT @fileandpath=@path+'\'+@filename
  IF @hr=0 SELECT @objerrorobject=@objfilesystem , @strerrormessage='Creating file "'+@fileandpath+'"'
  IF @hr=0 EXECUTE @hr = sp_OAMethod @objfilesystem, 'CreateTextFile', @objtextstream OUT, @fileandpath,2,True
  IF @hr=0 SELECT @objerrorobject=@objtextstream, @strerrormessage='writing to the file "'+@fileandpath+'"'
  IF @hr=0 EXECUTE @hr = sp_OAMethod  @objtextstream, 'Write', Null, @string
  IF @hr=0 SELECT @objerrorobject=@objtextstream, @strerrormessage='closing the file "'+@fileandpath+'"'
  IF @hr=0 EXECUTE @hr = sp_OAMethod  @objtextstream, 'Close'
  IF @hr<>0
    BEGIN
	    DECLARE @source VARCHAR(255)
	          , @description VARCHAR(255)
	          , @helpfile VARCHAR(255)
	          , @helpid INT
	    EXECUTE sp_OAGetErrorInfo @objerrorobject
		        , @source OUTPUT
		        , @description OUTPUT
		        , @helpfile OUTPUT,@helpid OUTPUT
	    SELECT @strerrormessage='Error whilst '+COALESCE(@strerrormessage,'doing something')+', '+COALESCE(@description,'')
	    RAISERROR (@strerrormessage,16,1)
    END
  EXECUTE sp_OADestroy @objtextstream
  EXECUTE sp_OADestroy @objtextstream

-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO