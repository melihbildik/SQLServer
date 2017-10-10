USE IT2_SysAdmin
GO
-- 04 Porcedure USP_BACKUP_FULL
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_BACKUP_FULL') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_BACKUP_FULL','$(pstdvers)',GETDATE(),'1.13')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.13', modified = GETDATE() WHERE tab_proc_name = 'USP_BACKUP_FULL'
GO
PRINT '---------------------------------------
04 create [USP_BACKUP_FULL]
---------------------------------------'

GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_BACKUP_FULL' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_BACKUP_FULL]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_BACKUP_FULL]
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_BACKUP_FULL_DIFF
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Autor:                 Melih Bildik, IT226
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Die Prozedure erstellt ein FullBackup von sämtlichen Datenbanken oder ein DIFF von ausgesuchten DBs
-- Wenn eine Datenbank angegeben wird, wird ein FullBackup dieser DB durchgeführt.
-- Ersetzt bestehende BackupScripts, vereinfacht und ohne LITESPEED
-- Mit Fehlerhandling
-- BackupTag für DiffFullbackups und ReadonlyDBs:
-- Für das Fullbackup dieser DBs kann ein Tag definiert werden.
-- Entweder kann in der IT2_Sysadmin ein Feld mit dem Namen BACKUPDAY angelegt werden oder es wird Sunday als default gesetzt.
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- DatenbankName	(optional), wenn keine = alle Datenbanken
-- BackupFileName   (optional, wenn definiert, muss auch der Datenbankname angegeben werden
--					 es muss nur der Filename ohne Suffix und Pfad angegeben werden)
--					 Das File wird im Standardbackupverzeichnis abgelegt	 
-- CopyOnly			(optional) Wenn dieser Parameter nicht leer ist, wird ein Backup mit "copy_only" durchgeführt
--					 um die Sicherungskette nicht zu unterbrechen. Das Backupfile wird mit dem suffix "copy" ergänzt
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor						Version		Date		What
-- Melih Bildik, IT226 extern			1.0			20090819	first published version
-- Roger Bugmann, IT226					1.02		20100201	Neue Versionierung
-- Melih Bildik, IT226 extern			1.03		24.11.2010	Umbau auf DIFF Backups
-- Roger Bugmann, IT226					1.04		20110315	Alle Cursor als LOCAL definiert
-- Roger Bugmann, IT226					1.05		20110321	Alle Cursor als STATIC LOCAL definiert
-- Roger Bugmann, IT226					1.06		20110329	Cursor für Readonly DBs hinzugefügt 
-- Melih Bildik, IT226 extern			1.07		20120208	Umbau für fixen Backuptag für Diff und Readonly DBs
-- Melih Bildik, IT226 extern			1.08		20120229	Einbau von "NoBackup" Datenbanken, die nicht gesichert werden. 
-- Roger Bugmann, IT226					1.09		20121112	Dbname varchar(150)
-- Roger Bugmann, IT226					1.10		26.03.2013	HA Group Anpassungnen
-- Roger Bugmann, IT226					1.11		11.06.2014	Zeit wird dem Backupfilename mitgegeben (DBNAME_20140101_104435_full.bck)
-- Melih Bildik, IT222 extern			1.12		04.11.2014	CopyOnly Parameter eingebaut
-- Roger Bugmann, IT226					1.13		06.05.2015	Abfrage ProdctVersion >= 11.% in Database Cursor
-- ------------------------------------------------------------------------------------------------

  -- ------------------------------
  -- Benutzer Angaben, Parameter(n)
  -- ------------------------------
    @db_name           VARCHAR(150)   = ''
  , @bck_file_name     VARCHAR(1000) = ''
  , @copy_only		   VARCHAR (10)  = '' 

  AS
    -- --------------------------
    -- Declare internal variables
    -- --------------------------
    DECLARE
      @bck_name            VARCHAR(80)
    , @bck_desc            VARCHAR(80)
    , @bck_comment         VARCHAR(2000)
    , @bck_path            VARCHAR(1000)
    , @bck_path_diff	   VARCHAR(1000)		
    , @bck_def_file_name   VARCHAR(2000)
    , @user_given_db_name  BIT            -- 1 = true 0 = false
    , @bck_stmt            VARCHAR(8000)
    , @date                VARCHAR(50)
    , @date_month          VARCHAR(2)
    , @date_day            VARCHAR(2)
    , @error			   VARCHAR(2000)
    , @backupday			   VARCHAR(20)
	, @aktualday		   VARCHAR(20)
	, @time				   VARCHAR(6)
    -- ------------------
    -- Variables settings
    -- ------------------
    SELECT @bck_path    = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Backup full path'
    SELECT @bck_path_diff    = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'Backup diff path'
    SET @date_month  = CAST(MONTH(GETDATE()) AS VARCHAR)
    IF @date_month < 10 
      SET @date_month  = '0'+CAST(MONTH(GETDATE()) AS VARCHAR)
    SET @date_day   = CAST(DAY(GETDATE()) AS VARCHAR)
    IF @date_day < 10 
      SET @date_day  = '0'+CAST(DAY(GETDATE()) AS VARCHAR)
    SET @time = REPLACE(CONVERT(TIME(0), GETDATE(), 11), ':', '') 
	SET @date        = CAST(YEAR(GETDATE()) AS VARCHAR)+@date_month+@date_day+'_'+@time
	
            --print ' year : '+CAST(YEAR(GETDATE()) as varchar)
            --print 'month : '+@date_month
            --print '  day : '+@date_day
            --print ' date : '+@date
    -- Den Backuptag f?r die SpezialBackups setzen
    -- Wenn kein Wert in der DB hinterlegt ist, wird Sonntag als Default gesetzt
    IF EXISTS(SELECT definition FROM IT2_SysAdmin..t_localsettings where definition = 'BACKUPDAY')
    SELECT @backupday = value FROM IT2_SysAdmin..t_localsettings WHERE definition = 'BACKUPDAY'
    ELSE
    SET @backupday = 'Sunday'
	--Den aktuellen Tag herausfinden
	SET @aktualday = DATENAME(WEEKDAY,GETDATE())
    -- --------------------------------------------------------------
    -- checks:
    -- --------------------------------------------------------------
    --
    -- --------------------------------------------
    --  - Falls @bck_file_name einen Wert besitzt muss eine DB angegeben werden
    -- --------------------------------------------
    IF (@bck_file_name <>'' AND @db_name = '')
      BEGIN
        PRINT 'Es kann kein file Name gegeben werden wenn alle DB zu sichern sind'
        RETURN
      END
 
    -- --------------------------------------------------------------
    -- Check ob die DB vorhanden ist
    -- --------------------------------------------------------------
    IF @db_name not in (SELECT name FROM sys.databases) AND @db_name != ''
		BEGIN
			PRINT 'Es ist ein falscher Datenbankname angegben worden'
			INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name,'Falscher Datenbankname', GETDATE(),'ERROR','FULL_BACKUP')
			RETURN
		END
	
	-- --------------------------------------------------------------
    -- cursor to get every db name that can be backuped
    -- --------------------------------------------------------------	

   IF @db_name = ''
      BEGIN -- BeginA
        SET @user_given_db_name = 0
		IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%'
			BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
				DECLARE cur_db  CURSOR STATIC LOCAL FOR /* Cursor für die nicht DiffDBs */
					SELECT name FROM sys.databases 
								WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
								AND name <> 'tempdb' /* Tempdb muss nicht gesichert werden*/
								AND is_read_only = 0   /*read_only DBs werden ignoriert*/
								AND name NOT IN (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE definition = 'DiffBackup')
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_backup)
								AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
								OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
																	JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																		WHERE primary_replica = @@SERVERNAME)
					ORDER BY name
            END
			
		ELSE
			BEGIN	/*	Cursor für Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
				DECLARE cur_db  CURSOR STATIC LOCAL FOR /* Cursor für die nicht DiffDBs */
					SELECT name FROM sys.databases 
								WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
								AND name <> 'tempdb' /* Tempdb muss nicht gesichert werden*/
								AND is_read_only = 0   /*read_only DBs werden ignoriert*/
								AND name NOT IN (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE definition = 'DiffBackup')
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_backup)
					ORDER BY name
			END
		
			
				DECLARE cur_diffdb  CURSOR STATIC LOCAL FOR /* Cursor für die Diff-DBs */
					SELECT name FROM sys.databases 
								WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
								AND name <> 'tempdb' /* Tempdb muss nicht gesichert werden*/
								AND is_read_only = 0   /*read_only DBs werden ignoriert*/
								AND name IN (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE definition = 'DiffBackup' )
								AND name IN (SELECT DISTINCT database_name  FROM [msdb].[dbo].[backupset] 
													WHERE type='D' -- D=Database I=Differential
													GROUP BY database_name
													HAVING MAX(backup_finish_date)> GETDATE()-7 )-- Nur DBs die auch ein Fullbackup haben, das max. 7 Tage alt ist
					ORDER BY name
		

				DECLARE cur_diffdb_full CURSOR STATIC LOCAL FOR /* Cursor für das Fullbackup der DiffDBs (Alle DBs, die Diff gesichtert werden und kein Full vorhanden ist) */
					SELECT name FROM sys.databases 
								WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
								AND name <> 'tempdb' /* Tempdb muss nicht gesichert werden*/
								AND is_read_only = 0   /*read_only DBs werden ignoriert*/
								AND name IN (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE definition = 'DiffBackup')
								AND @aktualday = @backupday -- Nur wenn es der richtige Tag ist, werden die DBs in den Cursor geladen.
					ORDER BY name
				
    -- ------------------------------------------
    -- ausführen des normalen Backups
    -- ------------------------------------------
        OPEN cur_db
        FETCH NEXT FROM cur_db INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
            IF (@user_given_db_name = 1 AND @bck_file_name <> '')
              SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_full.bak'
            ELSE
			IF @copy_only =''--Kein copyonly
			BEGIN
				SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full.bak'
				SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
				SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_stmt='
							  BACKUP DATABASE ['+@db_name+']
							  TO DISK='''+@bck_file_name+'''
							  WITH CHECKSUM
								 , STOP_ON_ERROR
								 , DESCRIPTION = '''+@bck_desc+'''
								 , NOINIT
								 , NOSKIP
								 , MEDIADESCRIPTION = '''+@bck_desc+'''
								 , MEDIANAME = '''+@bck_name+'''
								 , NAME = '''+@bck_name+''''
			END
			ELSE
			BEGIN -- copyonly backup durchführen
				SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full_copy.bak'
				SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
				SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_stmt='
							  BACKUP DATABASE ['+@db_name+']
							  TO DISK='''+@bck_file_name+'''
							  WITH CHECKSUM
								 , COPY_ONLY
								 , STOP_ON_ERROR
								 , DESCRIPTION = '''+@bck_desc+'''
								 , NOINIT
								 , NOSKIP
								 , MEDIADESCRIPTION = '''+@bck_desc+'''
								 , MEDIANAME = '''+@bck_name+'''
								 , NAME = '''+@bck_name+''''
			END
            BEGIN TRY
            EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','FULL_BACKUP')
				-- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
            END CATCH;
 
            --print @db_name
            FETCH NEXT FROM cur_db INTO @db_name
            --print @db_name
          END 
        CLOSE cur_db
        DEALLOCATE cur_db
     --end -- if exists
     
    -- ------------------------------------------
    -- ausführen des Diff Backup 
    -- ------------------------------------------
        OPEN cur_diffdb
        FETCH NEXT FROM cur_diffdb INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
            IF (@user_given_db_name = 1 AND @bck_file_name <> '')
              SET @bck_file_name = @bck_path_diff+'\'+@bck_file_name+'_diff.bak'
            ELSE
              SET @bck_file_name=@bck_path_diff+'\'+@db_name+'_'+@date+'_diff.bak'
            SET @bck_name    = 'Diff Backup of db '+@db_name+'_'+@date
            SET @bck_desc    = 'Diff Backup of db '+@db_name+' at '+@date
            SET @bck_comment = 'Diff Backup of db '+@db_name+' at '+@date
            SET @bck_stmt='
                          BACKUP DATABASE ['+@db_name+']
                          TO DISK='''+@bck_file_name+'''
                          WITH DIFFERENTIAL
							 ,CHECKSUM
                             , STOP_ON_ERROR
                             , DESCRIPTION = '''+@bck_desc+'''
                             , NOINIT
                             , NOSKIP
                             , MEDIADESCRIPTION = '''+@bck_desc+'''
                             , MEDIANAME = '''+@bck_name+'''
                             , NAME = '''+@bck_name+''''
            BEGIN TRY
            EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','FULL_BACKUP')
				-- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
            END CATCH;
            
            FETCH NEXT FROM cur_diffdb INTO @db_name
          END
        CLOSE cur_diffdb
        DEALLOCATE cur_diffdb

	-- ------------------------------------------
    -- ausführen des normalen Backups für Datenbanken die Diff gesichert werden.
    -- ------------------------------------------
        OPEN cur_diffdb_full
        FETCH NEXT FROM cur_diffdb_full INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
            IF (@user_given_db_name = 1 AND @bck_file_name <> '')
              SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_full.bak'
            ELSE
              SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full.bak'
            SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
            SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
            SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
            SET @bck_stmt='
                          BACKUP DATABASE ['+@db_name+']
                          TO DISK='''+@bck_file_name+'''
                          WITH CHECKSUM
                             , STOP_ON_ERROR
                             , DESCRIPTION = '''+@bck_desc+'''
                             , NOINIT
                             , NOSKIP
                             , MEDIADESCRIPTION = '''+@bck_desc+'''
                             , MEDIANAME = '''+@bck_name+'''
                             , NAME = '''+@bck_name+''''
            BEGIN TRY
            EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','FULL_BACKUP')
				-- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
            END CATCH;
 
            --print @db_name
            FETCH NEXT FROM cur_diffdb_full INTO @db_name
            --print @db_name
          END 
        CLOSE cur_diffdb_full
        DEALLOCATE cur_diffdb_full
              
      END -- BeginA
    ELSE
      BEGIN -- BeginB
        SET @user_given_db_name = 1
        DECLARE cur_db_named CURSOR LOCAL --Cursor für einzel DBs
        FOR SELECT name FROM sys.databases 
            WHERE state = 0 
            AND name = @db_name
            
   
     
        -- ------------------------------------------
		-- ausführen des normalen Backups, für die DB die als Parameter mit gegeben ist
		-- ------------------------------------------   
		OPEN cur_db_named
        FETCH NEXT FROM cur_db_named INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
		  	IF @copy_only = ''
			--ohne CopyOnly
			BEGIN
            IF (@user_given_db_name = 1 AND @bck_file_name <> '')
			SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_full.bak'
			ELSE
			SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full.bak'
      
				SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
				SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_stmt='
							  BACKUP DATABASE ['+@db_name+']
							  TO DISK='''+@bck_file_name+'''
							  WITH CHECKSUM
								 , STOP_ON_ERROR
								 , DESCRIPTION = '''+@bck_desc+'''
								 , NOINIT
								 , NOSKIP
								 , MEDIADESCRIPTION = '''+@bck_desc+'''
								 , MEDIANAME = '''+@bck_name+'''
								 , NAME = '''+@bck_name+''''
			END
			ELSE
			-- Mit Copyonly
			BEGIN
				IF (@user_given_db_name = 1 AND @bck_file_name <> '')
					SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_full_copy.bak'
				ELSE
				SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full_copy.bak'
				SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
				SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
				SET @bck_stmt='
							  BACKUP DATABASE ['+@db_name+']
							  TO DISK='''+@bck_file_name+'''
							  WITH CHECKSUM
								 , COPY_ONLY
								 , STOP_ON_ERROR
								 , DESCRIPTION = '''+@bck_desc+'''
								 , NOINIT
								 , NOSKIP
								 , MEDIADESCRIPTION = '''+@bck_desc+'''
								 , MEDIANAME = '''+@bck_name+'''
								 , NAME = '''+@bck_name+''''
			END

            BEGIN TRY
            EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','FULL_BACKUP')
				-- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
            END CATCH;
 
            --print @db_name
            FETCH NEXT FROM cur_db_named INTO @db_name
            --print @db_name
          END 
        CLOSE cur_db_named
        DEALLOCATE cur_db_named     
       END -- BeginB / if @db_name = ''
       
 -- ------------------------------------------
 -- ausführen des normalen Backups für Datenbanken die Read Only sind.
 -- ------------------------------------------
 		DECLARE cur_rodb  CURSOR STATIC LOCAL FOR /* Cursor für die Read-Only-DBs */
		  SELECT name FROM sys.databases 
				WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
				AND name <> 'tempdb' /* Tempdb muss nicht gesichert werden*/
				AND is_read_only = 1   /* DBs mit read_only werden ausgelesen */
				AND @aktualday = @backupday -- Nur wenn es der richtige Tag ist, werden die DBs in den Cursor geladen.
		ORDER BY name

	    OPEN cur_rodb
        FETCH NEXT FROM cur_rodb INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
            IF (@user_given_db_name = 1 and @bck_file_name <> '')
              SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_full.bak'
            ELSE
              SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_full.bak'
            SET @bck_name    = 'Full Backup of db '+@db_name+'_'+@date
            SET @bck_desc    = 'Full Backup of db '+@db_name+' at '+@date
            SET @bck_comment = 'Full Backup of db '+@db_name+' at '+@date
            SET @bck_stmt='
                          BACKUP DATABASE ['+@db_name+']
                          TO DISK='''+@bck_file_name+'''
                          WITH CHECKSUM
                             , STOP_ON_ERROR
                             , DESCRIPTION = '''+@bck_desc+'''
                             , NOINIT
                             , NOSKIP
                             , MEDIADESCRIPTION = '''+@bck_desc+'''
                             , MEDIANAME = '''+@bck_name+'''
                             , NAME = '''+@bck_name+''''
            BEGIN TRY
				EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','FULL_BACKUP')
				-- WindowsEventlog Eintrag erstellen
				SELECT @error = ERROR_MESSAGE()
				EXEC xp_logevent 60000, @error , ERROR
            END CATCH;
 
            --print @db_name
            FETCH NEXT FROM cur_rodb INTO @db_name
            --print @db_name
          END 
        CLOSE cur_rodb
        DEALLOCATE cur_rodb
     --end -- if exists
-- ---------------------------------------------------------------------------------
-- EOF
-- ---------------------------------------------------------------------------------
GO
