USE IT2_SysAdmin
GO
-- 09 Procedure USP_REFRESH_STATISTICS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_REFRESH_STATISTICS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_REFRESH_STATISTICS','$(pstdvers)',GETDATE(),'2.10')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '2.10', modified = GETDATE() WHERE tab_proc_name = 'USP_REFRESH_STATISTICS'
GO
PRINT '---------------------------------------
09 create [USP_REFRESH_STATISTICS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_REFRESH_STATISTICS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_REFRESH_STATISTICS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE  PROCEDURE [dbo].[USP_REFRESH_STATISTICS] 
 @dbname varchar(150) = ''
-- ------------------------------------------------------------------------------------------------
-- Object Name:           usp_refresh_statistics
-- Object Type:           storage procedure
-- Database:              IT2_SysAdmin
-- Verstion:              2.0
-- Date:                  07.09.2009
-- Autor:                 Melih Bildik, smartdynamic AG
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Die SP erneuert alle Statistiken der Datenbank
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- keine

-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Melih Bildik IT226				2.0			07.09.09	Neue Version
-- Roger Bugmann, IT226				2.01		20100201	Neue Versionierung
-- Roger Bugmann, IT226				2.02		20100413	[] beim DB Namen eingefügt, damit DB Name mit - erkannt werden
-- Melih Bildik, IT226				2.03		24.08.10	ReadOnlyDB werden ingoriert
-- Melih Bildik, IT226				2.04		26.09.11	Komplettumbau, Statistiken werden pro DB neu aufgebaut.
-- Melih Bildik, IT226				2.05		23.11.11	Views mit Statistiken werden auch aufgebaut
-- Melih Bildik, IT226				2.06		07.11.12	case sensitiv Anpassungen (SYS.STATS) 
-- Roger Bugmann, IT226				2.07		16.04.13	Anpassungen an HA Groups, Collation Bug, (von TempDB nach tempdb geändert )
-- Roger Bugmann, IT226				2.08		25.08.14	Bug, Wenn Prozedur ausgeführt wird mit Angabe einer Datenbank, gibt es eine Fehlermeldung. "END" war falsch gesetzt
-- Roger Bugmann, IT226				2.09		27.04.15	Abfrage ProdctVersion >= 11.% in Cursor für Datenbanken ab SQL Server 2012
-- Kunabalasingam Kaureesan, IT234	2.10		28.11.16	Schema Bug bei der Erstellung des "tablecursor" behoben
-- ------------------------------------------------------------------------------------------------
  AS
  -- ----------------------------------------------------------------------------------------------
  -- variables declaration 
  -- ----------------------------------------------------------------------------------------------
DECLARE 
	
	    @error	VARCHAR(2000)
	   ,@cmd	VARCHAR(2000)
	   ,@table	VARCHAR(200)
	   ,@schema VARCHAR(200)
	   ,@dbid	VARCHAR(10)

IF @dbname != ''
	  BEGIN   
		SET @dbid = (SELECT database_id FROM sys.databases WHERE name = @dbname)   
		SET @cmd =  'DECLARE tablecursor CURSOR FOR SELECT table_name, table_schema from [' + @dbname + '].INFORMATION_SCHEMA.TABLES WHERE table_type =''BASE TABLE'' OR table_type =''VIEW''
										AND (table_name IN (SELECT DISTINCT object_name(object_id,'+@dbid+') FROM [' + @dbname + '].sys.stats) AND table_schema IN (SELECT DISTINCT OBJECT_SCHEMA_NAME(object_id, '+@dbid+') FROM [' + @dbname + '].sys.stats))' 
		EXEC (@cmd)
		OPEN tablecursor
		FETCH NEXT FROM tablecursor INTO @table,@schema
		WHILE @@FETCH_STATUS = 0  
		BEGIN -- Begin tablecursor  
			BEGIN TRY
				SET @cmd = 'UPDATE STATISTICS ['+@dbname+'].['+@schema+'].['+@table+'] WITH FULLSCAN'
				EXEC(@cmd)
			END TRY
			BEGIN CATCH
				INSERT INTO logs(db, [message], action_time,[type],[source])
					VALUES(@dbname, ERROR_MESSAGE(), GETDATE(),'ERROR','REFRESH_STATS')
				 -- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
			END CATCH
		FETCH NEXT FROM tablecursor INTO @table, @schema
		END -- end table cursor
		CLOSE tablecursor
		DEALLOCATE tablecursor
       END -- end db mitgegeben
      ELSE
		BEGIN --begin ELSE
			IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 
				BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
					DECLARE dbcursor CURSOR FOR
						SELECT name, database_id FROM sys.databases 
												 WHERE name NOT IN ('master','tempdb', 'msdb', 'model')
												 AND state = 0 
												 AND is_read_only = 0 
												 AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
												 OR name IN (SELECT a.database_name FROM sys.availability_databases_cluster a
												 JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																					WHERE primary_replica = @@SERVERNAME)
						ORDER BY 1
				END
			ELSE	
				BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
					DECLARE dbcursor CURSOR FOR
						SELECT name, database_id FROM sys.databases 
												 WHERE name NOT IN ('master','tempdb', 'msdb', 'model') 
												 AND state = 0 
												 AND is_read_only = 0 
						ORDER BY 1
				END
			
				OPEN dbcursor
						FETCH NEXT FROM dbcursor INTO @dbname,@dbid
						WHILE @@Fetch_status=0
							BEGIN --begin
							SET @cmd =  'DECLARE tablecursor CURSOR FOR SELECT table_name, table_schema from [' + @dbname + '].INFORMATION_SCHEMA.TABLES WHERE table_type =''BASE TABLE'' OR table_type =''VIEW''
									AND (table_name IN (SELECT DISTINCT object_name(object_id,'+@dbid+') FROM [' + @dbname + '].sys.stats) AND table_schema IN (SELECT DISTINCT OBJECT_SCHEMA_NAME(object_id, '+@dbid+') FROM [' + @dbname + '].sys.stats))' 
							EXEC (@cmd)
							--print (@cmd)
								OPEN tablecursor
								FETCH NEXT FROM tablecursor INTO @table,@schema
								WHILE @@FETCH_STATUS = 0  
									BEGIN -- Begin tablecursor  
										BEGIN TRY
											SET @cmd = 'UPDATE STATISTICS ['+@dbname+'].['+@schema+'].['+@table+'] WITH FULLSCAN'
											EXEC(@cmd)
										END TRY
            
										BEGIN CATCH
											INSERT INTO logs(db, [message], action_time,[type],[source])
											VALUES(@dbname, ERROR_message(), GETDATE(),'ERROR','REFRESH_STATS')
											-- WindowsEventlog Eintrag erstellen
											SELECT @error = ERROR_MESSAGE()
											EXEC xp_logevent 60000, @error , ERROR
										END CATCH
								FETCH NEXT FROM tablecursor INTO @table, @schema
								END -- end table cursor
						CLOSE tablecursor
					DEALLOCATE tablecursor
			FETCH NEXT from dbcursor into @dbname,@dbid	
			END
		CLOSE dbcursor
		DEALLOCATE dbcursor
 END
-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO