USE IT2_SysAdmin
GO
-- 03 Procedure USP_BACKUP_TLOG
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_BACKUP_TLOG') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_BACKUP_TLOG','$(pstdvers)',GETDATE(),'2.08')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '2.08', modified = GETDATE() WHERE tab_proc_name = 'USP_BACKUP_TLOG'
GO
PRINT '---------------------------------------
03 create [USP_BACKUP_TLOG]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_BACKUP_TLOG' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_BACKUP_TLOG]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_BACKUP_TLOG]
  -- ------------------------------
  -- Benutzer Angaben, Parameter(n)
  -- ------------------------------
    @db_name           varchar(150)   = ''
  , @bck_file_name     varchar(1000) = ''
 -- ------------------------------------------------------------------
-- Object Name:           USP_BACKUP_TLOG
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Verstion:              2.0
-- Date:                  31.08.09
-- Autor:                 Melih Bildik, IT226 (smartdynamic AG 2009)
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Log Backup für  alle Datenbanken im FULL Mode
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- DatenbankName  (optional), wenn keine = alle Datenbanken
-- BackupFileName (optional, wenn definiert, muss auch die Datenbankname gegeben werden)
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Bildik Melih, IT226				2.0		31.08.09	erste Version
-- Roger Bugmann, IT226				2.01		20100201	Neue Versionierung
-- Roger Bugmann, IT226				2.02		20110317	Tlog Backup wird trozdem gemacht auch wenn in den letzt 24h kein
--															Full Backup gemacht wurde, es wird einfach ein Fehler in die Logs Tabelle geschrieben
-- Roger Bugmann, IT226				2.03		201208025	Dbname varchar(150)
-- Roger Bugmann, IT226				2.04		20121107	Bug behoben, COPY_ONLY entfernt
-- Roger Bugmann, IT226				2.05		20121107	Bug fix vom Bug fix :-)
-- Roger Bugmann, IT226				2.06		20140327	HA Group Check
-- Roger Bugmann, IT226				2.07		06.05.2015	Abfrage ProdctVersion >= 11.% in Database Cursor
-- Kunabalasingam Kaureersan, IT222	2.08		03.09.2015 Fehlerbehandlung für Datenbanken im Simple Mode
-- ------------------------------------------------------------------------------------------------
  AS
    -- --------------------------
    -- Declare internal variables
    -- --------------------------
    DECLARE
      @bck_name            VARCHAR(80)
    , @bck_desc            VARCHAR(80)
    , @bck_comment         VARCHAR(2000)
    , @bck_path            VARCHAR(1000)
    , @bck_def_file_name   VARCHAR(2000)
    , @user_given_db_name  BIT     -- 1 = true 0 = false
    , @bck_stmt            VARCHAR(8000)
    , @date                VARCHAR(50)
    , @date_month          VARCHAR(2)
    , @date_day            VARCHAR(2)
    , @debug               BIT     -- 1 = true 0 = false
    , @error			   VARCHAR(2000)
    -- ------------------
    -- Variables settings
    -- ------------------
    SET @debug = 0
    SELECT @bck_path    = value FROM t_localsettings WHERE definition = 'Backup tlog path'
    SET @date_month  = CAST(MONTH(GETDATE()) AS VARCHAr)
    IF @date_month < 10 
      SET @date_month  = '0'+CAST(MONTH(GETDATE()) AS VARCHAR)
    SET @date_day   = CAST(DAY(GETDATE()) AS VARCHAR)
    IF @date_day < 10 
      SET @date_day  = '0'+CAST(DAY(GETDATE()) AS VARCHAR)
    SET @date        = CAST(YEAR(GETDATE()) AS VARCHAR)+@date_month+@date_day
    -- --------------------------------------------------------------
    -- checks:
    -- --------------------------------------------------------------
    --
    -- --------------------------------------------
    -- Falls @bck_file_name einen Wert besitzt muss eine DB angegeben werden     
    -- --------------------------------------------
    IF (@bck_file_name <>'' and @db_name = '')
      BEGIN
        PRINT 'Es kann kein file Name gegeben werden wenn alle DB zu sichern sind'
        RETURN
      END
    
    -- --------------------------------------------------------------
    -- @db_name überprüfen ob vorhanden
    -- --------------------------------------------------------------
    IF @db_name not in (SELECT name FROM sys.databases) AND @db_name != ''
	BEGIN
		PRINT 'Es ist ein falscher Datenbankname angegben worden'
		 INSERT INTO logs(db, [message], action_time,[type],[source])
			VALUES(@db_name,'Falscher Datenbankname', GETDATE(),'ERROR','LOG_BACKUP')
		RETURN
	END
    
	-- --------------------------------------------------------------
    -- @db_name ?berpr?fen ob im SIMPLE Mode
    -- --------------------------------------------------------------
    IF @db_name in (SELECT name FROM sys.databases WHERE recovery_model = 3)
	BEGIN
		PRINT 'Die genannte Datenbank befindet sich im Wiederherstellungsmodus SIMPLE.'
		 INSERT INTO logs(db, [message], action_time,[type],[source])
			VALUES(@db_name,'Wiederherstellungsmodus SIMPLE lässt keine TLOGs zu', GETDATE(),'ERROR','LOG_BACKUP')
		RETURN
	END
    
    -- --------------------------------------------------------------
    -- überprüfen ob fullbackup vorhanden ist
    -- --------------------------------------------------------------

   IF @db_name NOT IN(SELECT s.name FROM sys.sysdatabases	s
						LEFT OUTER JOIN	msdb..backupset b
						ON s.name = b.database_name
						AND b.backup_start_date = (SELECT MAX(backup_start_date)
													FROM msdb..backupset
													WHERE database_name = b.database_name
													AND type = 'D')		-- full database backups only, not log backups
						WHERE b.backup_start_date > GETDATE()-1)
						AND @db_name != ''

   BEGIN
		PRINT'Für diese Datenbank ist kein aktuelles Fullbackup vorhanden'
		INSERT INTO logs(db, [message], action_time,[type],[source])
			VALUES(@db_name,'Kein Fullbackup vorhanden', GETDATE(),'ERROR','LOG_BACKUP')
        RETURN
    END
    
    
    -- --------------------------------------------------------------
    -- cursor der alle sicherungsfähigen DBs rausholt
    -- --------------------------------------------------------------
    
    IF @db_name = ''
      BEGIN
        SET @user_given_db_name = 0
		IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%'
			BEGIN	/*	Cursor für Datenbanken ab SQL Server 2012	*/
				DECLARE cur_db  CURSOR STATIC LOCAL FOR /* Cursor für die nicht DiffDBs */
					SELECT name FROM sys.databases 
								WHERE state = 0 /* state 0 = online -- cursor will get every db that can be backuped */
								AND DATABASEPROPERTYEX ( name , 'Recovery'  )<> 'SIMPLE' /* only databases whith recovery modle full or bulk-copy */
								AND is_read_only = 0   /*read_only DBs werden ignoriert*/
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_backup)
								AND name in (SELECT s.name FROM sys.sysdatabases	s
											WHERE s.name   IN (SELECT DISTINCT database_name  FROM [msdb].[dbo].[backupset] 
											WHERE type='D' -- D=Database I=Differential
											GROUP BY database_name
											HAVING MAX(backup_finish_date)> GETDATE()-7))
								AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
								OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
																	JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																		WHERE primary_replica = @@SERVERNAME)
					ORDER BY name
			END
		ELSE
			BEGIN
				DECLARE cur_db INSENSITIVE CURSOR 
				FOR SELECT d.name FROM sys.databases d
					WHERE state = 0 
					AND DATABASEPROPERTYEX ( d.name , 'Recovery'  )<> 'SIMPLE' /* only databases whith recovery modle full or bulk-copy */
					AND d.is_read_only = 0
					AND d.name in(SELECT s.name FROM sys.sysdatabases	s
								WHERE s.name   IN (SELECT DISTINCT database_name  FROM [msdb].[dbo].[backupset] 
								WHERE type='D' -- D=Database I=Differential
								GROUP BY database_name
							    HAVING MAX(backup_finish_date)> GETDATE()-7 ))
					ORDER by d.name
			END
			END
		ELSE
			BEGIN
			SET @user_given_db_name = 1
				DECLARE cur_db CURSOR
				FOR SELECT name FROM sys.databases WHERE state = 0 AND name = @db_name
        -- cursor get the db name wich is from the user given, it is good so, i can do only 
        -- one script to run the backup statment
      END
    -- print @user_given_db_name
    -- --------------------------------------------------------------------------------------------
    -- DO Backup
    -- --------------------------------------------------------------------------------------------
      BEGIN
        OPEN cur_db
        FETCH NEXT FROM cur_db INTO @db_name
        WHILE @@FETCH_STATUS = 0
          BEGIN
            IF (@user_given_db_name = 1 and @bck_file_name <> '')
              SET @bck_file_name = @bck_path+'\'+@bck_file_name+'_Tlog.trn'
            ELSE
              SET @bck_file_name=@bck_path+'\'+@db_name+'_'+@date+'_Tlog.trn'
            SET @bck_name    = 'Backup Tlog of db '+@db_name+'_'+@date
            SET @bck_desc    = 'Backup Tlog of db '+@db_name+' at '+@date
            SET @bck_comment = 'Backup Tlog of db '+@db_name+' at '+@date
            SET @bck_stmt='
                           BACKUP LOG ['+@db_name+']
                           TO DISK='''+@bck_file_name+'''
                           WITH CHECKSUM
                               , STOP_ON_ERROR
                               , DESCRIPTION = '''+@bck_desc+'''
                               , NOINIT
                               , NOSKIP
                               , MEDIADESCRIPTION = '''+@bck_desc+'''
                               , MEDIANAME = '''+@bck_name+'''
                               , NAME = '''+@bck_name+''''
            -- IF (@user_given_db_name = 1 and @bck_file_name <> '')
            --   SET @bck_stmt = @bck_stmt+', COPY_ONLY'
              
              
			BEGIN TRY
            EXEC (@bck_stmt)
            END TRY
            BEGIN CATCH -- Errorhandling
				--print error_message()
				INSERT INTO logs(db, [message], action_time,[type],[source])
				VALUES(@db_name, ERROR_MESSAGE(), GETDATE(),'ERROR','LOG_BACKUP')
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
      END -- End Native Backup Part

-- ----------------------------------------------------------------
-- EOF
-- ----------------------------------------------------------------
GO