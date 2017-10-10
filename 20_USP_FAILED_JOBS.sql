USE IT2_SysAdmin
GO
-- 20 Procedure USP_FAILED_JOBS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_FAILED_JOBS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_FAILED_JOBS','$(pstdvers)',GETDATE(),'1.03')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.03', modified = GETDATE() WHERE tab_proc_name = 'USP_FAILED_JOBS'
GO
PRINT '---------------------------------------
20 create [USP_FAILED_JOBS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_FAILED_JOBS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_FAILED_JOBS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure USP_FAILED_JOBS
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE USP_FAILED_JOBS
-- ------------------------------------------------------------------
-- Object Name:           USP_FAILED_JOBS
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  30.01.13
-- Autor:                 Roger Bugmann, IT226 
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Die Prozedur fügt fehlgeschlagene Jobs in die Tabelle failed_jobs auf dem Centralserver ein
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
--
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor					Version		Date		What
-- Roger Bugmann, IT226		1.00		30.01.2013	erste Version
-- Roger Bugmann, IT226		1.01		03.07.2015	Upload Statements verpackt, das die Procedure auch installiert wird wenn
--															die Firewall Rule zum Centralserver noch nicht besteht
-- Roger Bugmann, IT226		1.02		07.07.2015	Bug im Upload select gefixt
-- Roger Bugmann, IT226		1.03		07.07.2015	Upload geändert wegen Collation Konflikt
-- ------------------------------------------------------------------------------------------------
AS
-- // Variable Declarations 
DECLARE @PreviousDate datetime 
DECLARE @Year VARCHAR(4) 
DECLARE @Month VARCHAR(2) 
DECLARE @MonthPre VARCHAR(2) 
DECLARE @Day VARCHAR(2) 
DECLARE @DayPre VARCHAR(2) 
DECLARE @FinalDate INT 
-- // CURSOR Variabeln
DECLARE @server varchar(80)
DECLARE @name varchar(80)
DECLARE @step varchar(80)
DECLARE @step_id int
DECLARE @rundate int
DECLARE @runtime int

-- // Initialize Variables 
SET @PreviousDate = DATEADD(dd, -7, GETDATE()) -- Last 7 days  
SET @Year = DATEPART(yyyy, @PreviousDate)  
SELECT @MonthPre = CONVERT(VARCHAR(2), DATEPART(mm, @PreviousDate)) 
SELECT @Month = RIGHT(CONVERT(VARCHAR, (@MonthPre + 1000000000)),2) 
SELECT @DayPre = CONVERT(VARCHAR(2), DATEPART(dd, @PreviousDate)) 
SELECT @Day = RIGHT(CONVERT(VARCHAR, (@DayPre + 1000000000)),2) 
SET @FinalDate = CAST(@Year + @Month + @Day AS INT) 

-- // Löschen auf centralserver welche älter als 1 Woche sind
EXECUTE (' DELETE CENTRALSERVER.P95_DBAReports.dbo.failed_jobs 
	WHERE run_date < CONVERT(varchar, GetDate()-6, 112)
	AND server = @@SERVERNAME ')
-- // Final Logic 
-- // in die Tabelle failed_jobs auf Centralserver einfügen
IF OBJECT_ID('tempdb..#tmp_failed') IS NOT NULL
    DROP TABLE #tmp_failed 

IF OBJECT_ID('tempdb..#tmp_upload') IS NOT NULL
    DROP TABLE #tmp_upload 
-- ------------------------------------------------------------------------------------------------
-- // Faild Jobs insert into Temptabelle #tmp_failed
-- ------------------------------------------------------------------------------------------------
	SELECT	 h.server COLLATE Latin1_General_CI_AS as server, 
		 j.[name] COLLATE Latin1_General_CI_AS as name, 
         s.step_name COLLATE Latin1_General_CI_AS as step_name, 
         h.step_id, 
         h.run_date, 
         h.run_time, 
         h.sql_severity, 
         h.message 
		 INTO #tmp_failed
         FROM     msdb.dbo.sysjobhistory h 
         INNER JOIN msdb.dbo.sysjobs j 
           ON h.job_id = j.job_id 
         INNER JOIN msdb.dbo.sysjobsteps s 
           ON j.job_id = s.job_id
           AND h.step_id = s.step_id
				WHERE    h.run_status = 0 -- Failure 
				AND h.run_date > @FinalDate 
	ORDER BY h.instance_id DESC 
-- ------------------------------------------------------------------------------------------------
-- // Cursor, vergleicht inhalt der Tabellen #tmp_failed Lokal und failed_jobs auf Centralserver
-- ------------------------------------------------------------------------------------------------
SELECT * INTO #tmp_upload FROM #tmp_failed WHERE 1=0


DECLARE curtmp CURSOR
FOR

SELECT server,name,step_name,step_id,run_date,run_time FROM #tmp_failed
EXCEPT
SELECT server,job_name,step_name,step_id,run_date,run_time FROM CENTRALSERVER.P95_DBAReports.dbo.failed_jobs WHERE server = @@SERVERNAME

OPEN curtmp

FETCH NEXT FROM curtmp INTO @server,@name,@step,@step_id,@rundate,@runtime
WHILE @@FETCH_STATUS = 0

-- // Insert in #tmp_upload für den Upload zum Centralserver
BEGIN
INSERT INTO #tmp_upload SELECT * FROM #tmp_failed
WHERE name=@name and step_name=@step and step_id=@step_id and run_date=@rundate and run_time=@runtime


FETCH NEXT FROM curtmp INTO @server,@name,@step,@step_id,@rundate,@runtime
END
CLOSE curtmp
DEALLOCATE curtmp


-- ------------------------------------------------------------------------------------------------
-- // Upload der Job zum Centralserver
-- ------------------------------------------------------------------------------------------------
EXECUTE ('INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.failed_jobs  select * from #tmp_upload ')
-- ------------------------------------------------------------------------------------------------
-- END procedure exec USP_FAILED_JOBS
-- ------------------------------------------------------------------------------------------------
GO