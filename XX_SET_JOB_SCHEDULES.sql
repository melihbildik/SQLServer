  USE IT2_SysAdmin

  -- --------------------------
  -- Declare internal variables
  -- --------------------------
  DECLARE @job_name VARCHAR(30),
	 @schedule_id VARCHAR(5),
	 @enabled VARCHAR(2),
	 @freq_type VARCHAR(4),
	 @freq_interval VARCHAR(4),
	 @active_start_time VARCHAR(10),
	 @freq_subday_type VARCHAR(4),
	 @freq_subday_interval VARCHAR(4),
	 @stmt VARCHAR(4000)
  
  -- --------------------------------------------------------------
  -- cursor to define job_names and set job_schedules
  -- --------------------------------------------------------------  
  DECLARE cur_db  CURSOR STATIC LOCAL FOR
	SELECT 'SYS_BACKUP_CHECK' UNION
	SELECT 'SYS_BACKUP_FULL_NETWORKER' UNION
	SELECT 'SYS_BACKUP_TLOG' UNION
	SELECT 'SYS_CHECKDB' UNION
	SELECT 'SYS_DELETE_LOGS' UNION
	SELECT 'SYS_GET_CMDB_INFOS' UNION
	SELECT 'SYS_INDEX_REBUILD' UNION
	SELECT 'SYS_LOGON_ERRORS' UNION
	SELECT 'SYS_REFRESH_STATISTICS' UNION
	SELECT 'SYS_SQLSERVERERRORLOGSWITCH'
	OPEN cur_db
          FETCH NEXT FROM cur_db INTO @job_name
          WHILE @@FETCH_STATUS = 0
            BEGIN
			  
			  SET @schedule_id = (SELECT SS.schedule_id
				FROM msdb.dbo.sysschedules AS SS
				INNER JOIN [msdb].[dbo].[sysjobschedules] as SJS
					on SS.schedule_id = SJS.schedule_id
				INNER JOIN [msdb].[dbo].[sysjobs] SJ
					on SJ.job_id = SJS.job_id
			  WHERE SJ.name = @job_name )

				SET @enabled = (SELECT [job_enabled]
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @freq_type = (SELECT freq_type
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @freq_interval = (SELECT freq_interval
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @active_start_time = (SELECT active_start_time
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @freq_subday_type = (SELECT freq_subday_type
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @freq_subday_interval = (SELECT freq_subday_interval
					FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[job_schedule]
					WHERE [server] = @@SERVERNAME AND job_name = @job_name)

				SET @stmt = '
				USE msdb ;  
  
				EXEC dbo.sp_update_schedule  
					@schedule_id = '+@schedule_id+', 
					@enabled = '+@enabled+',
					@freq_type = '+@freq_type+',
					@freq_interval = '+@freq_interval+',
					@freq_subday_type = '+@freq_subday_type+',
					@freq_subday_interval = '+@freq_subday_interval+',
					@active_start_time = '+@active_start_time+'
					;   
				'
				EXEC (@stmt)
			  
			  FETCH NEXT FROM cur_db INTO @job_name
			END
    CLOSE cur_db
    DEALLOCATE cur_db