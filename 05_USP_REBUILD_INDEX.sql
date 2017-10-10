USE IT2_SysAdmin
GO
-- 05 Procedure USP_INDEX_REBUILD
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_INDEX_REBUILD') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_INDEX_REBUILD','$(pstdvers)',GETDATE(),'2.17')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '2.17', modified = GETDATE() WHERE tab_proc_name = 'USP_INDEX_REBUILD'
GO
PRINT '---------------------------------------
05 create [USP_INDEX_REBUILD]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_INDEX_REBUILD' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_INDEX_REBUILD]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------------------------------------------
-- create procedure USP_INDEX_REBUILD
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_INDEX_REBUILD]
 @databasename VARCHAR(150) = ''  /* if defined, only this database will be done */
AS
-- ------------------------------------------------------------------------------------------------
-- Object Name:           usp_index_rebuild
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  07.07.10
-- Autor:                 Melih Bildik  smartdynamic AG
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Diese SP rebuildet alle Indexe einer Datenbank
-- als Parameter kann der Datenbankname mitgegeben werden
-- Wird kein Parameter mitgegeben sind alle Datenbanken betroffen
-- Anpassungen wegen Cursorfehler bei emulierten DBs auf SQL2008
-- Verzicht auf temp Tabellen
-- SQL2008 Enterprise DBs werden online rebuildet, wenn LOBs vorhanden sind, wird die Tabelle nicht
-- online aufgebaut.
--
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- @databasename Name der Datenbank bei der alle Indexe neugebuildet werden sollen
-- ------------------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor                				Version		Date		What
-- Melih Bildik							2.00		07.09.09	Erstellt
-- Roger Bugmann, IT226					2.01		20100201	Neue Versionierung
-- Melih Bildik							2.02		07.07.10	Umbau ohne TempTabelle für emulierte DBs	
-- Melih Bildik							2.03		24.08.10	Error auf Warning umgestellt, ReadOnly DBs ausgeschlossen
-- Melih Bildik							2.04		01.11.10	Einbau 30% Fragmentiertung
-- Pascal Brändle, IT226				2.05		10.11.10	erweitert um rebuild_log Tabelle
-- Melih Bildik, IT226					2.06		26.01.10	[] für die Generierung von Scripts, somit werden Tabellen,Index usw. welche z.B mit ( - , ' ') im Namen rebuilded und generieren keine Fehler
-- Roger Bugmann, IT226					2.07		09.03.12	ReadOnly bug fix, nur mit Parameter aufgerufene DBs wurden beachtet
-- Melih Bildik							2.08		16.08.12	Disabled Indexes ausgeschlossen		
-- Roger Bugmann, IT226					2.09		24.01.12	Bug gefixt, beim Offline rebuild, Schema hinzugefügt. Dies führte zu einem Fehler wenn ein anderes als dbo, das Schema war.
-- Roger Bugmann, IT226					2.10		30.01.12	Die Variable @cmd ist mit 500 Zeichen zu klein für Sharepoint DBs, wurde auf 4000 Zeichen geändert
-- Roger Bugmann, IT226					2.11		20.02.12	Die Variable @ixname ist mit 100 Zeichen zu klein für Sharepoint DBs, wurde auf 500 Zeichen geändert
-- Roger Bugmann, IT226					2.12		21.03.12	Anpassungen an HA Groups
-- Roger Bugmann, IT226					2.13		27.04.15	Abfrage ProdctVersion >= 11.% in Cursor für Datenbanken ab SQL Server 2012
-- Melih Bildik,  IT222					2.14		14.07.15	SchemaBug: Beim mehreren Schemas mit ungleicher Anzahl Indexe wurde versucht die nicht vorhandenen Indexe aufzubauen.
-- Roger Bugmann, IT222					2.15		12.08.15	Bug: beim Cursor Aufbau im Block Standard Edition war noch ein Bug. Und es waren verschieden Version 2.14 im Umlauf
-- Kaureesan Kunabalasingam, IT234		2.16		05.08.16	Collation Bug: "SP_EXECUTESQL" geändert auf "sp_executesql"
-- Markus Wey, IT234					2.17		23.11.16	No-RebuildIndex-Tabelle berücksichtigen
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
	DECLARE @database VARCHAR(255)  
	DECLARE @table VARCHAR(255)
	DECLARE @schema VARCHAR(255) 
	DECLARE @cmd NVARCHAR(4000) 
	DECLARE @error VARCHAR(500)
	DECLARE @objname sysname
	DECLARE @objid INT
	DECLARE @ixname VARCHAR(500)
	DECLARE @indexid INT
	DECLARE @frag FLOAT
	DECLARE @fragsize FLOAT
	DECLARE @startzeit DATETIME 
	DECLARE @schemaid NVARCHAR(4)


	-- überprüfen ob in der t_localsettings ein Fragsize Wert gesetzt ist, wenn nein DEFAULT = 30
	IF EXISTS (SELECT [value] FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'frag')
		SELECT  @fragsize = [value] FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'frag'
	ELSE
		SET @fragsize = 30 -- defaultsize, wenn nichts in der DB hinterlegt ist



  -- ===================================================================================
  -- Alle nötigen Daten holen
  -- ===================================================================================
  /* cursor für alle Datenbanken */
	IF @databasename = ''
	BEGIN
		IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%' 	
			BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
				DECLARE DatabaseCursor CURSOR FOR 
					SELECT name FROM sys.databases  
								WHERE name NOT IN ('master','model','msdb','tempdb','distribution')
								AND state = 0 /* status online */   
								AND is_read_only = 0 /* read only werden ignoriert */
								AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_rebuildindex) /* no rebuild index */
								OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
																	JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																		WHERE primary_replica = @@SERVERNAME)
					ORDER BY 1 			
			END
			
		ELSE
			BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
				DECLARE DatabaseCursor CURSOR FOR 
					SELECT name FROM sys.databases  
								WHERE name NOT IN ('master','model','msdb','tempdb','distribution')
								AND state = 0 /* status online */   
								AND is_read_only = 0 /* read only werden ignoriert */
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_rebuildindex) /* no rebuild index */
					ORDER BY 1 
			END
	END
	ELSE
	BEGIN
	  DECLARE DatabaseCursor CURSOR   
	  FOR SELECT name  
		  FROM sys.databases 
		  WHERE state = 0 /* status online */ 
		  AND is_read_only = 0 /* read only werden ignoriert */
		  AND name = @databasename
	END
 -----------------------------------------------------------------------------------------------------------   

	DELETE FROM rebuild_log WHERE start < CURRENT_TIMESTAMP-7

	OPEN DatabaseCursor 
	FETCH NEXT FROM DatabaseCursor INTO @database 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			SET @cmd =  'DECLARE TableCursor CURSOR FOR SELECT  table_name as tableName, table_schema  
                    FROM ['+@database+'].INFORMATION_SCHEMA.TABLES WHERE table_type = ''BASE TABLE'' order by 2,1'  

			EXEC (@cmd) -- Statement ausführen um Cursor aufzubauen
			IF	(SELECT COMPATIBILITY_LEVEL FROM sys.databases WHERE name =  @databasename) <100 or
				(SELECT   CONVERT(VARCHAR,SERVERPROPERTY ('edition'))) NOT LIKE '%Enterprise%'
			BEGIN --Anfang IF
				OPEN TableCursor 
				FETCH NEXT FROM TableCursor INTO @table,@schema  
				WHILE @@FETCH_STATUS = 0  
				BEGIN -- Begin TableCursor
				SET @cmd ='set @schemaid = (SELECT SCHEMA_ID FROM ['+@database+'].sys.schemas where name = '''+@schema+''') '
				EXEC sp_executesql @cmd,N'@schemaid  NVARCHAR(4) OUT',@schemaid OUT
				
				SET @cmd = 'DECLARE IndexCursor CURSOR FOR SELECT OBJECT_NAME(object_id,(select database_id from sys.databases where name = ''' + @database + ''')),object_id, name,index_id from ['+@database+'].sys.indexes
						where index_id > 0 and is_disabled = 0 
						and OBJECT_NAME(object_id,(select database_id from sys.databases where name = ''' + @database + '''))='''+ @table +'''
						and object_id in (select object_id from ['+@database+'].sys.objects where schema_id = '''+ @schemaid +''') ' 
			
				EXEC (@cmd)
				--print @cmd
					OPEN IndexCursor 
					FETCH NEXT FROM IndexCursor INTO @objname, @objid,@ixname ,@indexid 
					WHILE @@FETCH_STATUS = 0  
						BEGIN --Begin IndexCursor
						SELECT @frag =  avg_fragmentation_in_percent FROM sys.dm_db_index_physical_stats (DB_ID(@database),@objid,@indexid, NULL, NULL)
						IF @frag > @fragsize
							BEGIN -- Begin des @frag IFs
								SET @startzeit = CURRENT_TIMESTAMP
								SET @cmd = 'USE ['+@database+'] ALTER INDEX ['+@ixname+'] ON ['+@schema+'].['+@table+'] REBUILD '
								--print @cmd
								BEGIN TRY
									EXEC (@cmd)
									INSERT INTO [IT2_SysAdmin].dbo.rebuild_log values (@database,@table,@ixname,@startzeit,CURRENT_TIMESTAMP,DATEDIFF(SECOND, @startzeit, CURRENT_TIMESTAMP))       								
									--print @cmd
								END TRY
								BEGIN CATCH
									INSERT INTO logs(db, [message], action_time,[type],[source])
									VALUES(@database, ERROR_message()+@cmd, GETDATE(),'WARNING','IndexRebuild')
								END CATCH
							END --Ende des @fag IF
					FETCH NEXT FROM IndexCursor INTO @objname, @objid,@ixname,@indexid 
					END --End IndexCursor 
				CLOSE IndexCursor  
				DEALLOCATE IndexCursor
				--END	
			FETCH NEXT FROM TableCursor INTO @table, @schema   
		END  --END Table Cursor
	CLOSE TableCursor  
	DEALLOCATE TableCursor	
	END --ende der IF Schlaufe, falls es keine SQL2008 Enterprise DB ist..
-----------------------------------------------------------------------------------------------------------
	ELSE
	BEGIN
		OPEN TableCursor 
		FETCH NEXT FROM TableCursor INTO @table, @schema  
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			SET @cmd ='set @schemaid = (SELECT SCHEMA_ID FROM ['+@database+'].sys.schemas where name = '''+@schema+''') '
			EXEC sp_executesql @cmd,N'@schemaid  NVARCHAR(4) OUT',@schemaid OUT
				
			SET @cmd = 'DECLARE IndexCursor CURSOR FOR SELECT OBJECT_NAME(object_id,(select database_id from sys.databases where name = ''' + @database + ''')),object_id, name,index_id from ['+@database+'].sys.indexes
                    where index_id > 0 and is_disabled = 0 and OBJECT_NAME(object_id,(select database_id from sys.databases where name = ''' + @database + '''))='''+ @table +'''
                    and object_id in (select object_id from ['+@database+'].sys.objects where schema_id = '''+ @schemaid +''') ' 
			
				
			EXEC (@cmd)
				OPEN IndexCursor 
				FETCH NEXT FROM IndexCursor INTO @objname, @objid,@ixname ,@indexid 
				WHILE @@FETCH_STATUS = 0  
					BEGIN 
						SELECT @frag =  avg_fragmentation_in_percent FROM sys.dm_db_index_physical_stats (DB_ID(@database),@objid,@indexid, NULL, NULL)
						IF @frag > @fragsize
							BEGIN --begin des @frag IF
							set @startzeit = CURRENT_TIMESTAMP							
							SET @cmd = 'USE ['+@database+'] ALTER INDEX ['+@ixname+'] ON ['+@schema+'].['+ @table+'] REBUILD WITH (ONLINE = ON)' --Rebuild für SQL2008 Enterprise 
							BEGIN TRY
								EXEC (@cmd) 
								INSERT INTO [IT2_SysAdmin].dbo.rebuild_log VALUES (@database,@table,@ixname,@startzeit,CURRENT_TIMESTAMP,DATEDIFF(SECOND, @startzeit, CURRENT_TIMESTAMP))       								
							END TRY
							BEGIN CATCH -- Falls der Index LOBs hat, wird das ALTER INDEX fehlschlagen
       							IF (ERROR_MESSAGE() like '%An online operation%') or
       								(ERROR_MESSAGE() like '%Invalid usage of the%')
       							BEGIN
									SET @startzeit = CURRENT_TIMESTAMP
       								SET @cmd = 'USE ['+@database+'] ALTER INDEX ['+@ixname+'] ON ['+@schema+'].['+@table+'] REBUILD' -- Dehalb wird dieser Index offline bearbeitet
       								EXEC (@cmd)
								INSERT INTO [IT2_SysAdmin].dbo.rebuild_log VALUES (@database,@table,@ixname,@startzeit,CURRENT_TIMESTAMP,DATEDIFF(SECOND, @startzeit, CURRENT_TIMESTAMP))       								
       							END
       							ELSE -- sonst war es ein anderer Fehler..
       							BEGIN
									INSERT INTO logs(db, [message], action_time,[type],[source])
									VALUES(@database, ERROR_message()+@cmd, GETDATE(),'ERROR','IndexRebuild')
									-- WindowsEventlog Eintrag erstellen
									SELECT @error = ERROR_MESSAGE()
									EXEC xp_logevent 60000, @error , WARNING
								END
							END CATCH
							END	 --Ende des @frag IF
					FETCH NEXT FROM IndexCursor INTO @objname, @objid,@ixname,@indexid 
					END --end IndexCursor
					CLOSE IndexCursor  
					DEALLOCATE IndexCursor
		FETCH NEXT FROM TableCursor INTO @table , @schema  
		END --end tablecursor   
        CLOSE TableCursor  
		DEALLOCATE TableCursor  
	END; -- Ende der ELSE Schleife

   FETCH NEXT FROM DatabaseCursor INTO @database 
END --end database cursor  
CLOSE DatabaseCursor  
DEALLOCATE DatabaseCursor 

END  -- end of procedure
-- ------------------------------------------------------------------------------------------------
-- end create procedure
-- ------------------------------------------------------------------------------------------------
GO