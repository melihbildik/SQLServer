USE [IT2_SysAdmin]
GO
-- 19 Procedure USP_ADD_UPDATE_EXTPROP
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_ADD_UPDATE_EXTPROP') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_ADD_UPDATE_EXTPROP','$(pstdvers)',GETDATE(),'1.00')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.00', modified = GETDATE() WHERE tab_proc_name = 'USP_ADD_UPDATE_EXTPROP'
GO
PRINT '---------------------------------------
19 create [USP_ADD_UPDATE_EXTPROP]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_ADD_UPDATE_EXTPROP' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_ADD_UPDATE_EXTPROP]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_ADD_UPDATE_EXTPROP
@check int = ''
, @dbname varchar(150) = ''
, @service varchar(10) = ''
, @descr varchar(1000) = ''
-- ------------------------------------------------------------------
-- Object Name:           USP_ADD_UPDATE_EXTPROP
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  10.01.13
-- Autor:                 Roger Bugmann, IT226 
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Die Prozedur fügt einer Datenbank "extendedproperties" hinzu, dies wird für die Weiterverrechnung benötigt
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- @dbname   -- Datenbankname
-- @service  -- Technische Service ID
-- @descr	 -- Beschreibung des Service
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor					Version		Date		What
-- Roger Bugmann, IT226		1.00		10.01.13	erste Version
-- ------------------------------------------------------------------------------------------------
AS 
DECLARE @stmt varchar(2000)	
IF @check = 1
	BEGIN 
		SET @stmt = 'SELECT name, value FROM '+@dbname+'.sys.fn_listextendedproperty(default, default, default, default, default, default, default) '
		exec (@stmt)
		RETURN
	END	

-- // Prüfung das alle Parameter mitgegeben werden
IF @dbname = ''
      BEGIN
        PRINT 'Kein Datenbankname angegeben

exec USP_ADD_UPD_EXTPROP 0,''DBNAME'',''12345'', ''BESCHREIBUNG'' 
oder nur als Prüfung
exec USP_ADD_UPD_EXTPROP 1,''DBNAME''
'
        RETURN -- exit the stored procedure
      END
    IF @service = ''
      BEGIN
        PRINT 'Keine Tech Service ID angegeben!

exec USP_ADD_UPD_EXTPROP 0,''DBNAME'',''12345'', ''BESCHREIBUNG'' '
        RETURN -- exit the stored procedure
      END
    IF @descr = ''
      BEGIN
        PRINT 'Keine Beschreibung zum Service angegeben!
			
exec USP_ADD_UPD_EXTPROP 0,''DBNAME'',''12345'', ''BESCHREIBUNG'' '
        RETURN -- exit the stored procedure
      END      
      


DECLARE @creator varchar(60) 
DECLARE @extendedproperty TABLE (dbname varchar(150),name varchar(50),value varchar(1000))
DECLARE @properties TABLE (dbname varchar(150),creator varchar(60),it_service varchar(1000),description varchar(1000)) 
	
	-- // Funktion fn_listextendedproperty über alle DBs auslesen und in Temporäre Tabelle speichern (@extendedproperty)
	INSERT INTO @extendedproperty (dbname,name ,value)
		EXEC sp_MSforeachdb 'select "?" AS db, CONVERT(SYSNAME,name),CONVERT(SYSNAME,value) 
							from [?].sys.fn_listextendedproperty(default, default, default, default, default, default, default) 
							where name in (''Creator'',''IT_Service'',''Description'')' 
	-- // Werte aus @extendedproperty umformen und in Temporäre Tabelle @properties speichern
	INSERT INTO @properties
		SELECT distinct (p.dbname )
        , p1.value AS creator 
        , p2.value AS IT_Service      
        , p3.value AS Description 
         FROM @extendedproperty   p 
        LEFT OUTER JOIN @extendedproperty p1 ON p.dbname=p1.dbname AND p1.name='creator' 
        LEFT OUTER JOIN @extendedproperty p2 ON p.dbname=p2.dbname AND p2.name='IT_Service' 
        LEFT OUTER JOIN @extendedproperty p3 ON p.dbname=p3.dbname AND p3.name='Description' 
	-- // @properties abfüllen mit restlichen Datenbanken ohne Services
	INSERT INTO @properties (dbname) SELECT name 
		FROM sys.databases 
		WHERE name NOT IN (SELECT dbname FROM @properties)

	-- // Service ID wird hinzugefügt oder updated
	IF (select it_service from @properties where dbname = @dbname) is null
		BEGIN
			SET @stmt = 'EXEC '+@dbname+'.sys.sp_addextendedproperty  @name=N''IT_Service'', @value= '+@service+' ' 
			EXEC (@stmt)
		END
	ELSE
		BEGIN
		SET @stmt = 'EXEC '+@dbname+'.sys.sp_updateextendedproperty @name=N''IT_Service'', @value= '+@service+' ' 
		EXEC (@stmt)
	END
	
	-- // Beschreibung wird hinzugefügt oder updated
	IF (select description from @properties where dbname = @dbname) is null
		BEGIN
			SET @stmt = 'EXEC '+@dbname+'.sys.sp_addextendedproperty  @name=N''Description'', @value= '''+@descr+''' ' 
			EXEC (@stmt)
		END
	ELSE
		BEGIN
			SET @stmt = 'EXEC '+@dbname+'.sys.sp_updateextendedproperty @name=N''Description'', @value= '''+@descr+''' ' 
			EXEC (@stmt)
		END
	
	-- // Die Extendedproperties werden ausgegeben zur Kontrolle
	SET @stmt = 'SELECT name, value FROM '+@dbname+'.sys.fn_listextendedproperty(default, default, default, default, default, default, default) '
	exec (@stmt)
-- ------------------------------------------------------------------------------------------------
-- END procedure exec USP_ADD_UPDATE_EXTPROP
-- ------------------------------------------------------------------------------------------------
GO