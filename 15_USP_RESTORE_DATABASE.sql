USE IT2_SysAdmin
GO
-- 15 Procedure USP_RESTORE_DATABASE
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_RESTORE_DATABASE') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_RESTORE_DATABASE','$(pstdvers)',GETDATE(),'1.03')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.03', modified = GETDATE() WHERE tab_proc_name = 'USP_RESTORE_DATABASE'
GO
PRINT '---------------------------------------
15 create [USP_RESTORE_DATABASE]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_RESTORE_DATABASE' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_RESTORE_DATABASE]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure USP_RESTORE_DATABASE
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_RESTORE_DATABASE]
(
	@backupfile NVARCHAR(1000)	= NULL,
	@dbname NVARCHAR(1000)		= NULL,
	@executescript BIT			= 0,			-- 0 -> only print SQL-Statements, 1 -> execute SQL-Statement
	@overwriteexistingdb BIT	= 0,			-- 0 -> not overwrite, 1 -> overwrite existing db
	@secfilegroup VARCHAR(255)	= 'USER01'		-- Sekundäre FileGroup neben Primary, wird NULL uebergeben 
												-- wird angenommen, dass keine alternative Filegroup existiert
)
  -- ------------------------------------------------------------------------------------------------
  -- Object Name:           USP_RESTORE_DATABASE
  -- Object Type:           storage procedure
  -- Database:              IT2_SysAdmin
  -- Synonym:               
  -- Version:               0.9.1
  -- Date:                  2010-05-05 
  -- Autor:                 Martin Däppen, IT234 extern
  -- Copyright:             ©Die Schweizerische Post 2010
  -- ------------------------------------------------------------------------------------------------
  -- Used for:
  -- =========
  -- Beschreibung:
  -- -------------
  -- Diese Prozedur ermöglicht das restoren eines Backup-Files unter einem beliebigen Datenbank-
  -- namen. Dabei werden die Daten-, Log- und LogicalFiles entsprechend dem PostStandard und den 
  -- vorhandenen Laufwerken benannt.
  -- Per Default gibt die Prozedur nur die auszuführenden SQL-Statements aus, durch setzen des ent-
  -- sprechenden Flags führt die SP den gewünschten Restore durch.
  -- Falls bereits eine Datenbank mit derm übegebenen Namen existiert, wird diese nur ueberschrie-
  -- ben wenn das ensprechende Parameterflag gesetzt ist. Andernfalls wird eine Meldung mit dem 
  -- Hinweis auf die bereits vorhandene Datenbank ausgegeben.
  -- Der PostStandard sieht für die Files und LogicalFiles in der sekunären FileGroup andere Namens-
  -- konventionen als für die restlichen benutzerdefinierten FileGroups vor. Bei der sekunären File
  -- Group wird der Name 'USER01' angenommen. Dieser Name kann mit dem fünften Parameter '@SecFileGroup' 
  -- überschrieben werden. wird dieser Wert NULL gesetzt werden für alle FileGroups dieselbe allgemeine
  -- Konvention angewandt.
  -- Die Prozedur wurde auf SQL2005 und SQL2008 getestet.
  -- 
  --
  -- Anwendungsbeispiele:
  -- --------------------
  -- USP_RESTORE_DATABASE
  --
  -- Der Aufruf dieser Prozedur ohne Parameter bewirkt die Ausgabe dieses Hilfe-Textes.
  --
  --
  -- USP_RESTORE_DATABASE '<BackupFileName>', '<NewDBName>'
  --
  -- Obiger Aufruf gibt die auszuführenden SQL-Scripts für den Restore des '<BackupFileName>' unter 
  -- DBNamen '<NewDBName>' aus. Der Restore wird jedoch nicht ausgeführt, zu diesem Zweck muss das 
  -- Flag (Parameter) @ExecuteScript = 1 gesetzt werden. 
  -- Das Backup-File wird in den Backup-Verzeichnissen, welche in der IT2_SysAdmin-DB definiert sind
  -- gesucht.
  --
  --
  -- USP_RESTORE_DATABASE '<PathToBackupFile>', '<ExistingDBName>', 0, 1
  --
  -- Obiger Aufruf gibt die auszuführenden SQL-Scripts für den Restore des '<PathToBackupFile>' unter 
  -- dem bereits existierenden DBNamen '<ExistingDBName>' aus. Der Restore wird jedoch nicht ausge-
  -- führt, zu diesem Zweck muss das Flag (Parameter) @ExecuteScript = 1 gesetzt werden. 
  -- Das Backup-File wird in den BackupFile wird nur unter dem angegebenen Verzeichnis gesucht. Der 
  -- vierte Parameter '@OverwriteExistingDB' mit dem Wert 1 erzwingt das Überschreiben der bestehenden
  -- Datenbank.
  --
  -- 
  -- USP_RESTORE_DATABASE '<PathToBackupFile>', '<NewDBName>', 1, 0, 'DATA'
  --
  -- Obiger Aufruf führt den Restore des angegebenen BackupFiles unter dem übergebenen DBNamen '<NewDBName>'
  -- aus. Sollte die Datenbank bereits existieren, wird eine entsprechende Meldung ausgegeben und das Script 
  -- abgebrochen. 
  -- Die sekundäre FileGroup hat den Namen 'DATA' und nicht wie üblich 'USER01'.
  --
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Parameter:
  -- ==========
  -- @backupfile nvarchar(1000)		= NULL,		-- Path to the Backupfile
  -- @DBName nvarchar(1000)			= NULL,		-- DB-Name for the restored Database
  -- @ExecuteScript bit				= 0,		-- 0 -> only print SQL-Statements, 1 -> execute SQL-Statement
  -- @OverwriteExistingDB bit		= 0			-- 0 -> not overwrite, 1 -> overwrite existing db
  -- @SecFileGroup varchar(255)		= 'USER01'	-- Sekundäre FileGroup neben Primary, wird NULL uebergeben 
  --												wird angenommen, dass keine sekundäre Filegroup existier
  ---------------------------------------------------------------------------------------------------
  -- Possible improvement
  -- ====================
  -- 
  -- ------------------------------------------------------------------------------------------------
  -- Last Modification:
  -- ==================
  -- Autor									Version		Date		What
  -- Martin Däppen, IT234 extern			0.9		20100429	first publicated version
  -- Martin Däppen, IT234 extern			0.9.1	20100505	- filecheck added
  -- Martin Däppen, IT234 extern			0.9.2	20100526	- logicalfilecheck added
  --													- Usage-Print if sp called without Params
  -- Melih Bildik,	IT226					1.00		17.08.10		In Poststandards erfasst
  -- Roger Bugmann, IT226					1.01	20120213	- Auf 2012 angepasst " >= '10' "
  -- Kunabalasingam Kaureesan, IT222		1.02	20152701	- Beschreibung ergänzt in Bezug auf Admin Shares (z.B. C$)
  -- Kunabalasingam Kaureesan, IT234		1.03	20150601	- Anpassung Bereich: Logeintrag in SysAdmin-DB schreiben -> Post konforme Version
  -- ------------------------------------------------------------------------------------------------
AS

BEGIN
 	SET NOCOUNT ON;	
	EXEC('USE master')
	IF NOT @backupfile IS NULL AND NOT @dbname IS NULL
	BEGIN
		IF NOT EXISTS(SELECT [state_desc] FROM [master].[sys].[databases] WHERE [name] = @dbname) OR @overwriteexistingdb = 1
		BEGIN
			/********************************************/
			/* kontrollieren ob das File existiert   	*/
			/********************************************/
			CREATE TABLE #FILECHECKRESULT
			(
				[File Exists] BIT,
				[file is a Directory] BIT,
				[Parent Directory Exists] BIT
			)

			INSERT #FILECHECKRESULT EXEC master..xp_fileexist @backupfile

			IF (SELECT TOP 1 [File Exists] FROM #FILECHECKRESULT) = 0
			BEGIN
				-- check with backup-Path
				DECLARE @backupdir VARCHAR(500)
				DECLARE @tmppath VARCHAR(500)
				SELECT @backupdir = value FROM t_localsettings WHERE definition = 'Backup full path'
				
				DELETE FROM #FILECHECKRESULT
				SET @tmppath = @backupdir + '\' + @backupfile
				INSERT #FILECHECKRESULT EXEC master..xp_fileexist @tmppath

				IF (SELECT TOP 1 [File Exists] FROM #FILECHECKRESULT) = 0
				BEGIN
					DELETE FROM #FILECHECKRESULT
					SET @tmppath = @backupdir + '1\' + @backupfile
					INSERT #FILECHECKRESULT EXEC master..xp_fileexist @tmppath
				
					IF (SELECT TOP 1 [File Exists] FROM #FILECHECKRESULT) = 0
					BEGIN
						PRINT 'File ''' + @backupfile + ''' does not exists.'
						RETURN
					END
					ELSE
					BEGIN
						SET @backupfile = @backupdir + '1\' + @backupfile
					END
				END
				ELSE
				BEGIN
					SET @backupfile = @backupdir + '\' + @backupfile
				END
			END


			
			/********************************************/
			/* Die Fileliste des Backup-Files auslesen	*/
			/********************************************/
			-- SQL Server 2005
			CREATE TABLE #tmp_filelist
			(
				LogicalName				NVARCHAR(128),
				PhysicalName			NVARCHAR(260),
				Type					CHAR(1),
				FileGroupName			NVARCHAR(128),
				Size					NUMERIC(20,0),
				MaxSize					NUMERIC(20,0),
				FileID					BIGINT, 
				CreateLSN				NUMERIC(25,0),
				DropLSN					NUMERIC(25,0) NULL, 
				UniqueID				UNIQUEIDENTIFIER,
				ReadOnlyLSN				NUMERIC(25,0) NULL,
				ReadWriteLSN			NUMERIC(25,0) NULL,
				BackupSizeInBytes		BIGINT,
				SourceBlockSize			INT, 
				FileGroupID				INT,
				LogGroupGUID			UNIQUEIDENTIFIER NULL, 
				DifferentialBaseLSN		NUMERIC(25,0) NULL, 
				DifferentialBaseGUID	UNIQUEIDENTIFIER, 
				IsReadOnly				BIT, 
				IsPresent				BIT
			)

			IF SUBSTRING(CONVERT(VARCHAR(50), SERVERPROPERTY('productversion')), 0, CHARINDEX('.', CONVERT(VARCHAR(50), SERVERPROPERTY('productversion')), 0)) >= '10' 
			BEGIN
				-- SQL Server 2008 Ergäenzung
				ALTER TABLE #tmp_filelist ADD TDEThumbprint VARBINARY(32) NULL
			END


			INSERT #tmp_filelist exec('restore filelistonly from DISK = ''' + @backupfile + '''')


			/************************************************************/
			/* Kontrollieren ob die sekundäre Filegroup existiert   	*/
			/************************************************************/
			IF NOT @secfilegroup IS NULL 
			BEGIN
				IF NOT EXISTS(SELECT * FROM #tmp_filelist WHERE FileGroupName = @secfilegroup)
				BEGIN
					PRINT 'The FIleGroup ^^' + @secfilegroup + ''' does not exists. Please give a valid Filegroup.'
					RETURN
				END
			END


			/********************************************/
			/* Den Restore vornehmen					*/
			/********************************************/
			DECLARE @currentlogicalname VARCHAR(255)
			DECLARE @currentfilegroupid INT
			DECLARE @lastfilegroupid INT
			DECLARE @otherfilegroupcounter INT
			DECLARE @newfilepath VARCHAR(255)
			DECLARE @datafilecounter INT
			DECLARE @datafilecounterstring CHAR(2)
			DECLARE @restcmd VARCHAR(4000)
			
			SET @restcmd = 'RESTORE DATABASE [' + @dbname + '] FROM  DISK =N''' + @backupfile + ''' WITH  FILE = 1, ' + CHAR(13)

			-- Primary
			IF EXISTS(SELECT LogicalName FROM #tmp_filelist where FileID = 1)
			BEGIN
				SELECT @currentlogicalname = LogicalName FROM #tmp_filelist WHERE FileID = 1
				SELECT @newfilepath = value FROM it2_sysadmin..t_localsettings WHERE definition = 'Primary file path'
				SET @restcmd = @restcmd + ' MOVE N''' + @currentlogicalname + '''	TO N''' + @newfilepath + '\' + @dbname + '_Primary.mdf'', ' + CHAR(13)
			END

			-- Transaction-Log
			IF EXISTS(SELECT LogicalName FROM #tmp_filelist WHERE FileID = 2)
			BEGIN
				SELECT @currentlogicalname = LogicalName FROM #tmp_filelist WHERE FileID = 2
				SELECT @newfilepath = value FROM it2_sysadmin..t_localsettings WHERE definition = 'Tlog file path'
				SET @restcmd = @restcmd + ' MOVE N''' + @currentlogicalname + '''	TO N''' + @newfilepath + '\' + @dbname + '_Tlog.ldf'', ' + CHAR(13)
			END


			-- Existing Datafiles in Filegroup 'USER01' (or given Value)
			SET @datafilecounter = 1
			DECLARE @curfiles CURSOR
				SET @curfiles = CURSOR FOR
					SELECT LogicalName FROM #tmp_filelist WHERE FileGroupName = @secfilegroup ORDER BY FileId
			OPEN @curfiles
			
			FETCH NEXT FROM @curfiles INTO @currentlogicalname

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @datafilecounterstring = right('0' + CONVERT(VARCHAR(2), @datafilecounter), 2)
				SELECT @newfilepath = value FROM it2_sysadmin..t_localsettings WHERE definition = 'Data' + @datafilecounterstring + ' file path'
				SET @restcmd = @restcmd + ' MOVE N''' + @currentlogicalname + '''	TO N''' + @newfilepath + '\' + @dbname + '_Data' + @datafilecounterstring + '.ndf'', ' + CHAR(13)

				SET @datafilecounter = @datafilecounter + 1
			
				FETCH NEXT FROM @curfiles INTO @currentlogicalname
			END

			CLOSE @curfiles
			DEALLOCATE @curfiles
	
			-- Other Filegroups
			DECLARE @filegroupcounterstring VARCHAR(3)
			SET @otherfilegroupcounter = 0
			SET @lastfilegroupid = 0
			
			
			SET @curfiles = CURSOR FOR
				SELECT LogicalName, FileGroupID FROM #tmp_filelist WHERE FileGroupName <> 'Primary' AND NOT FileGroupName IS NULL AND (FileGroupName <> @secfilegroup OR @secfilegroup IS NULL) ORDER BY FileId
			OPEN @curfiles
			
			FETCH NEXT FROM @curfiles INTO @currentlogicalname, @currentfilegroupid

			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @lastfilegroupid <> @currentfilegroupid
				BEGIN	
					SET @otherfilegroupcounter = @otherfilegroupcounter + 1
					SET @datafilecounter = 1
				END
				ELSE
				BEGIN
					SET @datafilecounter = @datafilecounter + 1
				END

				SET @filegroupcounterstring = right('0' + CONVERT(VARCHAR(2), @otherfilegroupcounter), 2)
				SET @datafilecounterstring = right('0' + CONVERT(VARCHAR(2), @datafilecounter), 2)
				SELECT @newfilepath = value FROM it2_sysadmin..t_localsettings WHERE definition = 'Data' + @datafilecounterstring + ' file path'
				SET @restcmd = @restcmd + ' MOVE N''' + @currentlogicalname + '''	TO N''' + @newfilepath + '\' + @dbname + '_FG' + @filegroupcounterstring + '_Data' + @datafilecounterstring + '.ndf'', ' + CHAR(13)

				SET @lastfilegroupid = @currentfilegroupid
			
				FETCH NEXT FROM @curfiles INTO @currentlogicalname, @currentfilegroupid
			END

			CLOSE @curfiles
			DEALLOCATE @curfiles


			IF @overwriteexistingdb = 1
				SET @restcmd = @restcmd + ' NOUNLOAD,  REPLACE,  STATS = 10' + CHAR(13)
			ELSE
				SET @restcmd = @restcmd + ' NOUNLOAD,  STATS = 10' + CHAR(13)
				
			IF @executescript = 1
			BEGIN
				EXEC(@restcmd)
			END
			ELSE
			BEGIN
				PRINT CHAR(13) + CHAR(13) + '/*********************************************************************************************************/' + CHAR(13) + CHAR(13)
				PRINT @restcmd
				PRINT CHAR(13) + CHAR(13) + '/*********************************************************************************************************/' + CHAR(13) + CHAR(13)
			END


			  WHILE (SELECT [state_desc] FROM [master].[sys].[databases] WHERE [name] = @dbname) <> 'ONLINE'
				AND NOT (SELECT [state_desc] FROM [master].[sys].[databases] WHERE [name] = @dbname) IS NULL
			  BEGIN
				WAITFOR DELAY '00:00:01'
				PRINT 'WAITING'
			  END

			/********************************************/
			/* Die Logischen Filenamen anpassen			*/
			/********************************************/
			-- Primary
			IF EXISTS(SELECT LogicalName FROM #tmp_filelist where FileID = 1)
			BEGIN
				SELECT @currentlogicalname = LogicalName FROM #tmp_filelist WHERE FileID = 1
				
				-- Nur anpassen falls der Namen geaendert hat
				IF UPPER(@currentlogicalname) <> UPPER(@dbname + '_Primary')
				BEGIN
					IF @executescript = 1
						EXEC('ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @dbname + '_Primary'')')
					ELSE
						PRINT 'ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @dbname + '_Primary'')'
				END
			END

			-- Transaction-Log
			IF EXISTS(SELECT LogicalName FROM #tmp_filelist where FileID = 2)
			BEGIN
				SELECT @currentlogicalname = LogicalName FROM #tmp_filelist WHERE FileID = 2

				-- Nur anpassen falls der Namen geaendert hat
				IF UPPER(@currentlogicalname) <> UPPER(@dbname + '_Tlog')
				BEGIN
					IF @executescript = 1
						EXEC('ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @dbname + '_Tlog'')')
					ELSE
						PRINT 'ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @dbname + '_Tlog'')'
				END
			END

			-- Existing Datafiles 
			DECLARE @newlogicalname VARCHAR(100)
			SET @datafilecounter = 1
			SET @curfiles = CURSOR 
			FOR
			SELECT LogicalName FROM #tmp_filelist WHERE FileGroupName = @secfilegroup ORDER BY FileId
			OPEN @curfiles
			FETCH NEXT FROM @curfiles INTO @currentlogicalname
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @newlogicalname = @dbname + '_Data' + right('0' + CONVERT(VARCHAR(2), @datafilecounter), 2)

				-- Nur anpassen falls der Namen geaendert hat
				IF UPPER(@currentlogicalname) <> UPPER(@newlogicalname)
				BEGIN
					IF @executescript = 1
						EXEC('ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @newlogicalname + ''')')
					ELSE
						PRINT 'ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @newlogicalname + ''')'
				END

				SET @datafilecounter = @datafilecounter + 1
			
				FETCH NEXT FROM @curfiles INTO @currentlogicalname
			END

			CLOSE @curfiles
			DEALLOCATE @curfiles


			-- Other Filegroups
			SET @otherfilegroupcounter = 0
			SET @lastfilegroupid = 0
						
			SET @curfiles = CURSOR FOR
				SELECT LogicalName, FileGroupID FROM #tmp_filelist WHERE FileGroupName <> 'Primary' AND NOT FileGroupName IS NULL AND (FileGroupName <> @secfilegroup OR @secfilegroup IS NULL) ORDER BY FileId
			
			OPEN @curfiles
			FETCH NEXT FROM @curfiles INTO @currentlogicalname, @currentfilegroupid
			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @lastfilegroupid <> @currentfilegroupid
				BEGIN	
					SET @otherfilegroupcounter = @otherfilegroupcounter + 1
					SET @datafilecounter = 1
				END
				ELSE
				BEGIN
					SET @datafilecounter = @datafilecounter + 1
				END

				SET @filegroupcounterstring = right('0' + CONVERT(VARCHAr(2), @otherfilegroupcounter), 2)
				SET @datafilecounterstring = right('0' + CONVERT(VARCHAR(2), @datafilecounter), 2)

				SET @newlogicalname = @dbname + '_FG' + @filegroupcounterstring + '_Data' + @datafilecounterstring

				-- Nur anpassen falls der Namen geaendert hat
				IF UPPER(@currentlogicalname) <> UPPER(@newlogicalname)
				BEGIN
					IF @executescript = 1
						EXEC('--ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @newlogicalname + ''')')
					ELSE
						PRINT '--ALTER DATABASE [' + @dbname + '] MODIFY FILE (NAME=''' + @currentlogicalname + ''', NEWNAME=''' + @newlogicalname + ''')'
				END

				SET @lastfilegroupid = @currentfilegroupid
				
				FETCH NEXT FROM @curfiles INTO @currentlogicalname, @currentfilegroupid
			END

			CLOSE @curfiles
			DEALLOCATE @curfiles
			

			IF @executescript = 0
			BEGIN
				PRINT CHAR(13) + CHAR(13) + '/*********************************************************************************************************/' + CHAR(13) + CHAR(13)
			END

			--Drip the TempTable
			DROP TABLE #tmp_filelist

			/************************************************/
			/* Den DB-Owner auf NTAuthority\System setzen	*/
			/************************************************/
			DECLARE @changeownercmd VARCHAR(1000)
			SET @changeownercmd = 'USE [' + @dbname + ']' + CHAR(10) + 
									'EXEC dbo.sp_changedbowner @loginame = N''sa'', @map = false'

			IF @executescript = 1
				EXEC(@changeownercmd)
			ELSE
				PRINT @changeownercmd


			/************************************************/
			/* Logeintrag in SysAdmin-DB schreiben			*/
			/************************************************/
			IF @executescript = 1
			BEGIN			
				-- Errorhandling
				--print error_message()
				INSERT INTO logs([proc_id], [loginame], [usrname], [db], [message], [action_time],[type],[source])
				SELECT @@SPID, SYSTEM_USER, USER, @dbname, 'DB ''' + @dbname + ''' restored from File ''' + @backupfile + ''' with Overwrite-Parameter = ' + CONVERT(CHAR(1), @overwriteexistingdb) + '.', GETDATE(),'INFORMATION','RESTORE'
			END

		END
		ELSE
		BEGIN
			PRINT 'Database ''' + @dbname + ''' already exists. For overwriting set the Overwrite-Flag = 1.'
		END
		
	END
	ELSE
	BEGIN
		-- Calling without parameters --> Print using
		DECLARE @helptext VARCHAR(4000)
		SET @helptext = 'Using:' + CHAR(10) + 
				'======' + CHAR(10) + 
				'Anwendungsbeispiele:' + CHAR(10) + 
				'--------------------' + CHAR(10) + 
				'> USP_RESTORE_DATABASE' + CHAR(10) + 
				'' + CHAR(10) + 
				'	Der Aufruf dieser Prozedur ohne Parameter bewirkt die Ausgabe dieses Hilfe-Textes.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'> USP_RESTORE_DATABASE ''<BackupFileName>'', ''<NewDBName>''' + CHAR(10) + 
				'' + CHAR(10) + 
				'	Obiger Aufruf gibt die auszuführenden SQL-Scripts für den Restore des ''<BackupFileName>'' ' + CHAR(10) + 
				'	unter DBNamen ''<NewDBName>'' aus. Der Restore wird jedoch nicht ausgeführt, zu diesem ' + CHAR(10) + 
				'	Zweck muss das Flag (Parameter) @executescript = 1 gesetzt werden. ' + CHAR(10) + 
				'	Das Backup-File wird in den Backup-Verzeichnissen, welche in der IT2_SysAdmin-DB definiert ' + CHAR(10) + 
				'	sind gesucht.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'> USP_RESTORE_DATABASE ''<PathToBackupFile>'', ''<ExistingDBName>'', 0, 1' + CHAR(10) + 
				'' + CHAR(10) + 
				'	Obiger Aufruf gibt die auszuführenden SQL-Scripts für den Restore des ''<PathToBackupFile>'' ' + CHAR(10) + 
				'	unter dem bereits existierenden DBNamen ''<ExistingDBName>'' aus. Der Restore wird jedoch ' + CHAR(10) + 
				'	nicht ausgeführt, zu diesem Zweck muss das Flag (Parameter) @executescript = 1 gesetzt ' + CHAR(10) + 
				'	werden. ' + CHAR(10) + 
				'	Das Backup-File wird in den BackupFile wird nur unter dem angegebenen Verzeichnis gesucht. ' + CHAR(10) + 
				'	Der vierte Parameter ''@OverwriteExistingDB'' mit dem Wert 1 erzwingt das Überschreiben der ' + CHAR(10) + 
				'	bestehenden atenbank.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'> USP_RESTORE_DATABASE ''<PathToBackupFile>'', ''<NewDBName>'', 1, 0, ''DATA''' + CHAR(10) + 
				'' + CHAR(10) + 
				'	Obiger Aufruf führt den Restore des angegebenen BackupFiles unter dem übergebenen DBNamen ' + CHAR(10) + 
				'	''<NewDBName>'' aus. Sollte die Datenbank bereits existieren, wird eine entsprechende Meldung ' + CHAR(10) + 
				'	ausgegeben und das Script abgebrochen. ' + CHAR(10) + 
				'	Die sekundäre FileGroup hat den Namen ''DATA'' und nicht wie üblich ''USER01''.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'Beschreibung:' + CHAR(10) + 
				'-------------' + CHAR(10) + 
				'Diese Prozedur ermöglicht das restoren eines Backup-Files unter einem beliebigen Datenbank-' + CHAR(10) + 
				'namen. Dabei werden die Daten-, Log- und LogicalFiles entsprechend dem PostStandard und den ' + CHAR(10) + 
				'vorhandenen Laufwerken benannt.' + CHAR(10) + 
				'Per Default gibt die Prozedur nur die auszuführenden SQL-Statements aus, durch setzen des ent-' + CHAR(10) + 
				'sprechenden Flags führt die SP den gewünschten Restore durch.' + CHAR(10) + 
				'Falls bereits eine Datenbank mit derm übegebenen Namen existiert, wird diese nur ueberschrie-' + CHAR(10) + 
				'ben wenn das ensprechende Parameterflag gesetzt ist. Andernfalls wird eine Meldung mit dem ' + CHAR(10) + 
				'Hinweis auf die bereits vorhandene Datenbank ausgegeben.' + CHAR(10) + 
				'Der PostStandard sieht für die Files und LogicalFiles in der sekunären FileGroup andere Namens-' + CHAR(10) + 
				'konventionen als für die restlichen benutzerdefinierten FileGroups vor. Bei der sekunären File' + CHAR(10) + 
				'Group wird der Name ''USER01'' angenommen. Dieser Name kann mit dem fünften Parameter ''@secfilegroup'' ' + CHAR(10) + 
				'überschrieben werden. wird dieser Wert NULL gesetzt werden für alle FileGroups dieselbe allgemeine' + CHAR(10) + 
				'Konvention angewandt.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'Grenzen:' + CHAR(10) + 
				'--------' + CHAR(10) + 
				'Da der Service Account vom SQL Server keine lokalen Admin-Berechtigungen besitzt, ist die Verwendung ' + CHAR(10) + 
				'von Admin Shares (z.B. C$) im Parameter: ''<PathToBackupFile>'' nicht möglich.' + CHAR(10) + 
				'' + CHAR(10) + 
				'' + CHAR(10) + 
				'------------------------------------------------------------------------------------------------' + CHAR(10) + 
				'Parameter:' + CHAR(10) + 
				'==========' + CHAR(10) + 
				'@backupfile nvarchar(1000)	= NULL,			-- Path to the Backupfile' + CHAR(10) + 
				'@DBName nvarchar(1000)		= NULL,			-- DB-Name for the restored Database' + CHAR(10) + 
				'@executescript bit			= 0,			-- 0 -> only print SQL-Statements, 1 -> execute SQL-Statement' + CHAR(10) + 
				'@OverwriteExistingDB bit	= 0				-- 0 -> not overwrite, 1 -> overwrite existing db' + CHAR(10) + 
				'@secfilegroup varchar(255)	= ''USER01''		-- Sekundäre FileGroup neben Primary, wird NULL uebergeben' + CHAR(10) +  
				'											-- wird angenommen, dass keine sekundäre Filegroup existier'
		
		PRINT @helptext
	END
END
-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO