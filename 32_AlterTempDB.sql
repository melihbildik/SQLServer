print '---------------------------'
print '32 Alter TempDB '
print '---------------------------'
-- ------------------------------------------------------------------------------------------------
-- Object Name:           32_Tempdb.sql
-- Object Type:           Poststandard Install Script
-- Database:              
-- Autor:                 Melih Bildik, IT222
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Dieses Script passt die Tempdb an und verteilt die Files gemäss IT2_SysAdmin DB auf den Datenlaufwerken
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor								Version		Date		What
-- Melih Bildik, IT222 extern			1.0			28.11.14	first published version
-- Roger Bugmann, IT222 extern			1.1			19.02.15	Maxsize der Files tempdev und templog definiert und den Pfad für templog angepasst.
-- Roger Bugmann, IT222 extern			1.2			23.02.15	Prüfen ob schon mehere Datenfiles vorhanden sind
-- Kunabalasingam Kuareesan, IT234		1.3			07.07.16	Fork for SQL Server 2016
-- Kunabalasingam Kuareesan, IT234		1.4			22.05.17	tempdb Grössendefinition angepasst
-- ------------------------------------------------------------------------------------------------
-- Variablen deklarieren
DECLARE
	 @Datapath1		VARCHAR(256)
	,@Datapath2		VARCHAR(256)
	,@Datapath3		VARCHAR(256)
	,@Datapath4		VARCHAR(256)
	,@Tlogpath1		VARCHAR(256)
	
	,@name			SYSNAME
	,@size			INT
	,@max_size		INT
	,@growth		INT
	,@stmt			VARCHAR(2000)
	,@error			VARCHAR(2000)
	,@version		NVARCHAR(25)
	
-- Settings size for all user data files and log files
  DECLARE
        @file_size             VARCHAR(10)   -- all other data files size
      , @file_maxsize          VARCHAR(10)   -- all other data files max size
      , @file_filegrowth       VARCHAR(10)   -- all other data files growth
      , @log_size              VARCHAR(10)   -- log file size
      , @log_maxsize           VARCHAR(10)   -- log file max size
      , @log_filegrowth        VARCHAR(10)   -- log file growth

	SET @file_size            = 128		-- [MB]
	SET @file_maxsize         = 5120
	SET @file_filegrowth      = 128
	SET @log_size             = 64
	SET @log_maxsize          = 5120
	SET @log_filegrowth       = 64
	
-- ------------------------------------------------------------------------------------------------
--	get serverversion
-- ------------------------------------------------------------------------------------------------
  SET @version = CONVERT(sysname,SERVERPROPERTY('ProductVersion'))

  SELECT @version = CASE
		WHEN @version LIKE '13.0%' THEN '2016'
		WHEN @version LIKE '12.0%' THEN '2014'
		WHEN @version LIKE '11.0%' THEN '2012'
		WHEN @version LIKE '10.%' THEN '2008'
		WHEN @version LIKE '9.0%' THEN '2005'
	END

-- for SQL Server 2014 and lower
  IF(@version <= '2014')
	BEGIN
		IF (SELECT COUNT(*) FROM tempdb.sys.database_files) > 2
			BEGIN
				--PRINT 'Check Tempdb Database Files'
				RAISERROR (N'Tempdb hat bereits mherere Datenfiles definiert, bitte pruefen!!!.', -- Message text.
				   16, 
				   1); 
			END
		ELSE
			BEGIN
				-- Variablen mit den Pfadinformationen abfüllen
				SET @Datapath1 = (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'Data01 file path')+'\tempdb01.ndf'
				SET @Datapath2 = (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'Data02 file path')+'\tempdb02.ndf'
				SET @Datapath3 = (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'Data03 file path')+'\tempdb03.ndf'
				SET @Datapath4 = (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'Data04 file path')+'\tempdb04.ndf'
				SET @Tlogpath1 = (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE [definition] = 'Tlog file path')+'\templog.ldf'

				-- SQL Statement zusammensetzen
				SET @stmt = '
				ALTER DATABASE [tempdb] MODIFY FILE ( SIZE = 16MB, NAME = ''tempdev'', MAXSIZE = 128MB, FILEGROWTH = 16MB)

				ALTER DATABASE [tempdb] MODIFY FILE ( NAME = ''templog'', FILENAME = '''+@Tlogpath1+''', SIZE = '+@log_size+'MB, MAXSIZE = '+@log_maxsize+'MB, FILEGROWTH = '+@log_filegrowth+'MB)

				ALTER DATABASE [tempdb] 
				ADD FILE ( NAME = ''tempdb01'', FILENAME = '''+@Datapath1+''' , SIZE = '+@file_size+'MB, MAXSIZE = '+@file_maxsize+'MB, FILEGROWTH = '+@file_filegrowth+'MB)

				ALTER DATABASE [tempdb] 
				ADD FILE ( NAME = ''tempdb02'', FILENAME = '''+@Datapath2+''' , SIZE = '+@file_size+'MB, MAXSIZE = '+@file_maxsize+'MB, FILEGROWTH = '+@file_filegrowth+'MB)

				ALTER DATABASE [tempdb] 
				ADD FILE ( NAME = ''tempdb03'', FILENAME = '''+@Datapath3+''' , SIZE = '+@file_size+'MB, MAXSIZE = '+@file_maxsize+'MB, FILEGROWTH = '+@file_filegrowth+'MB)

				ALTER DATABASE [tempdb] 
				ADD FILE ( NAME = ''tempdb04'', FILENAME = '''+@Datapath4+''' , SIZE = '+@file_size+'MB, MAXSIZE = '+@file_maxsize+'MB, FILEGROWTH = '+@file_filegrowth+'MB)
				'

				-- SQL Statement ausführen
				BEGIN TRY
					EXEC (@stmt)
				END TRY
				BEGIN CATCH -- Errorhandling
					--print error_message()
					INSERT INTO IT2_SysAdmin.dbo.logs (db, [message], action_time,[type],[source])
						VALUES('tempdb', ERROR_MESSAGE(), GETDATE(),'ERROR','Alter Tempdb')
					-- WindowsEventlog Eintrag erstellen
					SELECT @error = ERROR_MESSAGE()
					EXEC xp_logevent 60000, @error , ERROR
				END CATCH;
			END
	END
  IF(@version >= '2016')
	BEGIN
		-- --------------------------------------------------------------
		-- adjust *.ndf Files
		-- --------------------------------------------------------------
			DECLARE data_file CURSOR STATIC FOR 
				SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
					FROM sys.master_files
					WHERE DB_NAME(database_id) = 'tempdb' AND [type] = '0' 
					ORDER BY [name] asc

				OPEN data_file
				SET @stmt = ''
					FETCH NEXT FROM data_file INTO @name, @size, @max_size, @growth
					WHILE @@FETCH_STATUS = 0
					BEGIN
							BEGIN
								IF(@size < @file_size)
								BEGIN
									SET @stmt += 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', SIZE = '+@file_size+'MB) '
								END

								IF(@max_size < @file_maxsize OR @max_size = '2097152')
								BEGIN
									SET @stmt +=  'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', MAXSIZE = '+@file_maxsize+'MB) '
								END

								IF(@growth < @file_filegrowth)
								BEGIN
									SET @stmt +=  'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', FILEGROWTH = '+@file_filegrowth+'MB) '
								END 
								
								-- SQL Statement ausführen
								BEGIN TRY
									EXEC (@stmt)
								END TRY
								BEGIN CATCH -- Errorhandling
									--print error_message()
									INSERT INTO IT2_SysAdmin.dbo.logs (db, [message], action_time,[type],[source])
										VALUES('tempdb', ERROR_MESSAGE(), GETDATE(),'ERROR','Alter Tempdb')
									-- WindowsEventlog Eintrag erstellen
									SELECT @error = ERROR_MESSAGE()
									EXEC xp_logevent 60000, @error , ERROR
								END CATCH;
							END
							FETCH NEXT FROM data_file INTO @name, @size, @max_size, @growth
					END 
			CLOSE data_file
			DEALLOCATE data_file
		
		-- --------------------------------------------------------------
		-- adjust *.ldf Files
		-- --------------------------------------------------------------	
			DECLARE data_file_ldf CURSOR STATIC FOR 
				SELECT [name], ([size] / 128) as size, ([max_size] / 128) as max_size, ([growth] / 128) as growth
					FROM sys.master_files
					WHERE DB_NAME(database_id) = 'tempdb' AND [type] = '1'

			OPEN data_file_ldf
			SET @stmt = ''
				FETCH NEXT FROM data_file_ldf INTO @name, @size, @max_size, @growth
				WHILE @@FETCH_STATUS = 0
					BEGIN
						BEGIN
							IF(@size < @log_size)
							BEGIN
								SET @stmt += 'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', SIZE = '+@log_size+'MB)'
							END

							IF(@max_size < @log_maxsize OR @max_size = '2097152')
							BEGIN
								SET @stmt +=  'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', MAXSIZE = '+@log_maxsize+'MB)'
							END

							IF(@growth < @log_filegrowth)
							BEGIN
								SET @stmt +=  'ALTER DATABASE [tempdb] MODIFY FILE ( NAME = '''+@name+''', FILEGROWTH = '+@log_filegrowth+'MB)'
							END
							
							-- SQL Statement ausführen
							BEGIN TRY
								EXEC (@stmt)
							END TRY
							BEGIN CATCH -- Errorhandling
								--print error_message()
								INSERT INTO IT2_SysAdmin.dbo.logs (db, [message], action_time,[type],[source])
									VALUES('tempdb', ERROR_MESSAGE(), GETDATE(),'ERROR','Alter Tempdb')
								-- WindowsEventlog Eintrag erstellen
								SELECT @error = ERROR_MESSAGE()
								EXEC xp_logevent 60000, @error , ERROR
							END CATCH;
						END
						FETCH NEXT FROM data_file_ldf INTO @name, @size, @max_size, @growth
					END 
		  CLOSE data_file_ldf
		  DEALLOCATE data_file_ldf
	END