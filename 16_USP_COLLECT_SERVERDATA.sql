USE [IT2_SysAdmin]
GO

-- 16 Procedure USP_COLLECT_SERVERDATA
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_COLLECT_SERVERDATA') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_COLLECT_SERVERDATA','$(pstdvers)',GETDATE(),'1.27')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.27', modified = GETDATE() WHERE tab_proc_name = 'USP_COLLECT_SERVERDATA'
GO
PRINT '---------------------------------------
16 create [USP_COLLECT_SERVERDATA]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_COLLECT_SERVERDATA' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_COLLECT_SERVERDATA]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[USP_COLLECT_SERVERDATA]
-- ------------------------------------------------------------------
-- Object Name:           USP_COLLECT_SERVERDATA
-- Object Type:           SP
-- Database:              IT2_SysAdmin
-- Date:                  04.04.11
-- Autor:                 Roger Bugmann, IT226 
-- ------------------------------------------------------------------
-- Used for:
-- =========
-- Server Daten werden gesammelt, SQL Server Version, Datenbanken, Sysadmin Version
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- 
-- 
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Roger Bugmann, IT226				1.00		04.04.11	erste Version
-- Roger Bugmann, IT226				1.01		05.05.11	Angepasst an die neue Tabellen Struktur
-- Roger Bugmann, IT226				1.02		25.05.11	Verschiedenste Bugfixes,
-- Roger Bugmann, IT226				1.03		20.09.11	Update SQLDBS mit DBSize eingefügt
-- Roger Bugmann, IT226				1.04		29.09.11	Bugfix Update SQLDBS, Datum wird auch updated
-- Roger Bugmann, IT226				1.05		20120213	Auf 2012 angepasst WHEN @version LIKE '11.0%' THEN '2012'
-- Roger Bugmann, IT226				1.06beta	20120301	Section SqlDBs verändert, delete und dann insert, kein update,delete section mehr
-- Roger Bugmann, IT226				1.06beta	20120306	Section Sqlservers und procversion verändert, delete und dann insert, kein update,delete section mehr
-- Roger Bugmann, IT226				1.06beta3	20120711	added TCPPORT,CPU,Core,Memory
-- Roger Bugmann, IT226				1.06beta4	20120717	bug with 2012 behoben
-- Roger Bugmann, IT226				1.06beta5	20120718	Anpassungen wegen Rückwärtskompatibilität zu 2005 :-(
-- Roger Bugmann, IT226				1.07		20120818	Kleinere Bugfixes
-- Roger Bugmann, IT226				1.08		20121122	In der Section "Section sqldbs" dbname auch auf 150 vergrössert
-- Roger Bugmann, IT226				1.09		20130131	Zusätzlich werden noch die Serverparameter gesammelt (sp_configure), SYSNAME klein geschrieben wegen Collation Probleme auf SQl Server 2005 
-- Roger Bugmann, IT226				1.10		20130318	Variable @sadmv angeapsst auf VARCHAR(10) , wird gebraucht für die Versionierung der Poststandards neu X.XX.XX (z.B. 1.07.01)
--															Zusätzlich wurde noch der Teil Clusternodes hinzugefügt, fügt die Nodes des Clusters in die Tabelle Clusternodes ein.
-- Roger Bugmann, IT226				1.11		20130318	Zuästzliche Attribute aus der sys.databsese werde gesammelt (,s.compatibility_level,s.collation_name,s.is_read_only	,s.recovery_model_desc
--															,s.is_auto_create_stats_on,s.is_auto_update_stats_on ,s.is_auto_update_stats_async_on, s.is_encrypted)
--															Fehler bei	SERVERPROPERTY('InstanceName')) und SERVERPROPERTY('ServerName')) es hatte ein blank zwichen den Hochkommas am Ende
-- Roger Bugmann, IT226				1.12		20130429	Server Parameter aus sys.configuration, Database Informationen aus sys.databases. Inser Physicalnodes into sqlnodes
-- Roger Bugmann, IT226				1.13		20140219	sqldbs, create_datum wieder hinzugewfügt, wurde im letzten release vergessen, bug bei Tcpport von 2008R2 und 2012 ( and @tcpdyn is null) hinzugefügt
-- Roger Bugmann, IT226				1.14		20140321	Anpassungen auf SQL Server 2014, die Tabelle Logs der DB IT2_SysAdmin wird zusätzlich gesammelt
-- Roger Bugmann, IT226				1.15		20140403	Bei der Generierung des TcpPort, am Ende NULL entfernen 
-- Roger Bugmann, IT226				1.16		20140515	In der Section "sqlservers" wurde der Teil Memory auslesen geändert.
--															Section sqldbs, der Teil mit "EXEC sp_MSforeachdb" durch einen Cursor ersetzt, da es Probleme gab mit DBID's von gelöschten DB's
-- Roger Bugmann, IT222				1.17		20150423	Section sqldbs Version und Availability Group check eingebaut
-- Kaureesan Kuanbalasignam, IT222	1.18		20150423	Section SYSINFO eingebaut
-- Roger Bugmann, IT222				1.19		20150701	Pocedure umgebaut, das die Prozedure auch installiert werden kann auch wenn die Firewallrule zum Centralserver noch nicht besteht
-- Kaureesan Kuanbalasignam, IT222	1.20		20150701	WindowsVersion und WindowsServipack hinzugefügt
-- Roger Bugmann, IT222				1.21		20150819	WindowsVersion und WindowsServipack if Bedingung für SQL Server 2008, und ein neues Feld "Comment" mit Infos über den SQL Server wurde hinzugefügt.
--															no_backup Section neu hinzugefügt.				
-- Roger Bugmann, IT222				1.22		20150825	Section Logs geändert, wegen deadlocks
-- Kunabalasingam Kaureesan, IT234	1.23		20151207	Redundante Einträge entfernt - Siehe Releasenotes.txt des Poststandards 1.10
--												20151207	Nicht verwendeter Eintrag auskommentiert- Section sqldbs: EXEC (@stmt) - Siehe Releasenotes.txt des Poststandards 1.10
-- Kunabalasingam Kaureesan, IT234	1.24		20160601	Section Logs - Alte Daten auf dem Centralserver.P95_DBAReports.dbo.logs löschen
-- Kunabalasingam Kaureesan, IT234	1.25		20160511	Section Collect Database used and free space hinzugefügt
-- Kunabalasingam Kaureesan, IT234	1.26		20161125	Die Upload Statements der "Collect Database Size" in EXEC verpackt
-- Kunabalasingam Kaureesan, IT234	1.27		20170110	Das "INSERT INTO", welches die gesammelten Daten auf den CENTRALSERVER.dbo.sqlsysinfo schreibt wurde ersetzt, neu wird jedes Attribut der Tabelle genannt.
-- 												20170110	Folgende Daten werden neu ermittelt und in die Tabelle "sqlsysinfo" geschrieben: SQL Server Installationsdatum, ob AlwaysON aktiviert ist, ob eine Datenbank "gespiegelt" ist und die SQL Server Version
--												20170119	Folgende Daten werden neu ermittelt und in die Tabelle "sqlsysinfo" geschrieben: Ob die Instanz verschlüsselte Datenbanken beinhaltet
--												20170313	Folgende Daten werden neu ermittelt und in die Tabellen "ha_info_(aoag/mirroring/fci)" geschrieben: AlwaysON, Mirroring und Failover Cluster Instance Informationen

-- ------------------------------------------------------------------------------------------------
AS 
-------------------------------------------
-- Variabeln deklarieren - Allgemein
-------------------------------------------
DECLARE @machine VARCHAR(10)
DECLARE @instance VARCHAR(20)
DECLARE @sp VARCHAR(15)
DECLARE @edtn VARCHAR(50)
DECLARE @version VARCHAR(50)
DECLARE @prodversion VARCHAR(50)
DECLARE @sadmv VARCHAR(10)
DECLARE @stmt  VARCHAR(4000)
DECLARE @pit  VARCHAR(20) 
DECLARE @domainname VARCHAR(100)
DECLARE @tab_proc_name VARCHAR(30)
DECLARE @modified VARCHAR(30)
DECLARE @procvers VARCHAR(7)
DECLARE @core VARCHAR(4)
DECLARE @hyper VARCHAR(4)
DECLARE @cpu VARCHAR(4)
DECLARE @mem VARCHAR(10)
DECLARE @tcpport VARCHAR(5)
DECLARE @tcpdyn VARCHAR(5)
DECLARE @keyname VARCHAR(512)  -- key name
DECLARE @pathname VARCHAR(50)   -- folder path name (MSSQL.?)
DECLARE @tmp_res TABLE (core VARCHAR(4),hyper VARCHAR(4),cpu VARCHAR(4),mem VARCHAR(8))
DECLARE @physical_memory varchar(50)


-------------------------------------------
-- Variabeln deklarieren - SQLSYSINFO
-------------------------------------------
DECLARE @SqlPath NVARCHAR(255)
DECLARE @InstName VARCHAR(16) = @@SERVICENAME
DECLARE @value_name NVARCHAR(20)
DECLARE @LoginMode_Value INT
DECLARE @LoginMode NVARCHAR(15)
DECLARE @RegLoc VARCHAR(100)
DECLARE @ProcessorInfo VARCHAR(256)
DECLARE @osrel  VARCHAR(10)
DECLARE @ossp  VARCHAR(20)

-------------------------------------------
-- Variabeln deklarieren für HA
-------------------------------------------
DECLARE @rowid INT
DECLARE @node VARCHAR(50)
DECLARE @actnode VARCHAR(50)
DECLARE @cols AS NVARCHAR(MAX)
DECLARE @nodes AS NVARCHAR(MAX)
DECLARE @roledesc NVARCHAR(60)
DECLARE @cluster_name NVARCHAR(100)

-------------------------------------------
-- Section sqlservers
-------------------------------------------
-- Variabeln abfüllen
-------------------------------------------
/* Dummy Sysadmin Version setzten (für Server mit Sysadmin <1.04) */
SET @sadmv = '<1.04'

/* Variabeln aus SERVERPROPERTY abfüllen (z.B. Instanz,Edition, Verison, etc */
SET @machine = CONVERT(sysname,SERVERPROPERTY('MachineName')) --as Machine --@Machine
SET @instance = CONVERT(sysname,SERVERPROPERTY('InstanceName')) --as [Instanz Name] --@Instance
SET @sp = CONVERT(sysname,SERVERPROPERTY('ProductLevel')) --AS ServicePack	--@sp
SET @edtn = CONVERT(sysname,SERVERPROPERTY('Edition')) --AS Edition	--@edtn
SET @version = CONVERT(sysname,SERVERPROPERTY('ProductVersion')) --AS ProductVersion --@version
SET @prodversion = CONVERT(sysname,SERVERPROPERTY('ProductVersion')) --AS ProductVersion --@version

/* WindowsVersion & WindowsSPVersion etc */
IF @version like '10.0.%'
	BEGIN
		SELECT @osrel = RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3),
		@ossp =  CASE 
		WHEN (SELECT RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Service', @@VERSION), 14), 14))  LIKE '%Service Pack%' THEN (SELECT RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Service', @@VERSION), 14), 14))
		ELSE ''
		END
	END
ELSE
	BEGIN
		SELECT @osrel = windows_release, @ossp = windows_service_pack_level FROM sys.dm_os_windows_info
	END

/* falls Default Instanz installiert ist wird "MSSQLSERVER" gesetzt */
IF @instance IS NULL 
BEGIN
SET @instance = 'MSSQLSERVER'
END

----------------------------------------------------
-- Section SYSINFO
----------------------------------------------------
IF OBJECT_ID('tempdb..#tmp_sysinfo') IS NOT NULL
    DROP TABLE #tmp_sysinfo 
-- ------------------------------------------------------------------------------------
-- DELETE old Entries from CENTRALSERVER.P95_DBAReports.dbo.sqlsysinfo
-- ------------------------------------------------------------------------------------
EXECUTE ('  DELETE FROM CENTRALSERVER.P95_DBAReports.dbo.sqlsysinfo WHERE [server] = @@SERVERNAME ')

-- ------------------------------------------------------------------------------------
-- GET PIT OR SET DEFAULT  
-- ------------------------------------------------------------------------------------
 SELECT @pit = value FROM [IT2_SysAdmin].[dbo].[t_localsettings] WHERE definition = 'PIT' 
	IF @pit IS NULL 
		SET @pit = 'TBD'

-- ------------------------------------------------------------------------------------
-- GET SysAdminVersion
-- ------------------------------------------------------------------------------------
IF EXISTS(SELECT name FROM [IT2_SysAdmin].sys.sysobjects WHERE name = 'versioncheck' AND type = 'U')
	SELECT @sadmv = version FROM [IT2_SysAdmin].[dbo].[versioncheck] WHERE tab_proc_name = 'IT2_SYSADMIN'

-- ------------------------------------------------------------------------------------
-- GET DOMAINNAME 
-- ------------------------------------------------------------------------------------
 EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\ControlSet001\services\Tcpip\Parameters', N'Domain',@domainname OUTPUT

-- ------------------------------------------------------------------------------------
-- GET PortNumber 
-- ------------------------------------------------------------------------------------
 SET @RegLoc = CASE
	WHEN @InstName = 'MSSQLSERVER' 
		THEN 'Software\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp\'
		ELSE 'Software\Microsoft\Microsoft SQL Server\' + @InstName + '\MSSQLServer\SuperSocketNetLib\Tcp\'
	END

 DECLARE
	@RegRead TABLE(
	VALUE VARCHAR(4000),
	DATA VARCHAR(4000))

 INSERT INTO @RegRead(VALUE,DATA)
	EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @RegLoc, 'tcpPort'; 
	
-- ------------------------------------------------------------------------------------
-- GET ProcessorDescription 
-- ------------------------------------------------------------------------------------
 EXEC xp_instance_regread 'HKEY_LOCAL_MACHINE', 'HARDWARE\DESCRIPTION\System\CentralProcessor\0', 'ProcessorNameString', @ProcessorInfo OUTPUT, N'no_output'

-- ------------------------------------------------------------------------------------
-- GET ServiceAccounts
-- ------------------------------------------------------------------------------------
 DECLARE
	@ServicePath NVARCHAR(256) = N'SYSTEM\CurrentControlSet\Services\' + CASE
		WHEN @@SERVICENAME = 'MSSQLSERVER' 
			THEN 'MSSQLSERVER'
			ELSE 'MSSQL$' + @@SERVICENAME
		END,
	@AgentServicePath NVARCHAR(256) = N'SYSTEM\CurrentControlSet\Services\' + CASE
		WHEN @@SERVICENAME = 'MSSQLSERVER' 
			THEN 'SQLSERVERAGENT'
			ELSE 'SQLAgent$' + @@SERVICENAME
		END,
	@MSSQLServiceAccountName VARCHAR(256),
	@SQLAgentServiceAccountName VARCHAR(256)

 EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', @AgentServicePath, N'ObjectName', @SQLAgentServiceAccountName OUTPUT, N'no_output'
 EXECUTE master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', @ServicePath, N'ObjectName', @MSSQLServiceAccountName OUTPUT, N'no_output'

-- ------------------------------------------------------------------------------------
-- GET Security
-- ------------------------------------------------------------------------------------
 IF @InstName IS NULL
	SET @RegLoc = 'SOFTWARE\Microsoft\MSSQLServer\MSSQlServer\SuperSocketNetLib\Tcp'
	ELSE
		SET @RegLoc = 'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
		EXEC master..xp_regread @rootkey = 'HKEY_LOCAL_MACHINE', @key = @RegLoc, @value_name = @InstName, @value = @SqlPath OUTPUT
 
 IF @InstName IS NULL
	SET @RegLoc = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQLServer\'
	ELSE
		SET @RegLoc = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @SqlPath + '\MSSQLServer\'
		EXEC master..xp_regread @rootkey = 'HKEY_LOCAL_MACHINE', @key = @RegLoc, @value_name = 'LoginMode', @value = @LoginMode_Value OUTPUT

	IF @LoginMode_Value = 1
		SET @LoginMode = 'Windows'
	IF @LoginMode_Value = 2
		SET @LoginMode = 'Mixed'

-- ------------------------------------------------------------------------------------
-- GET SystemManufacturer AND ModelNumber
-- ------------------------------------------------------------------------------------
	DECLARE @SystemManufacturer TABLE(
	LogDate DATETIME NOT NULL,
	ProcessInfor VARCHAR(256),
	Text VARCHAR(MAX)NOT NULL)

 INSERT INTO @SystemManufacturer
	EXEC xp_readerrorlog 0, 1, "Manufacturer";

-- ------------------------------------------------------------------------------------
-- GET InformationofDifferential SQLDMV
-- ------------------------------------------------------------------------------------
 WITH sysInfo
	AS (SELECT cpu_count, hyperthread_ratio, sqlserver_start_time,
	(SELECT ISNULL(CAST(NULLIF(DATEDIFF(HOUR, sqlserver_start_time, GETDATE()) / 24, 0)AS VARCHAR) + ' days ', '') + RIGHT('0' + CAST(DATEDIFF(MINUTE, StartDateTime, GETDATE()) / 60 % 24 AS VARCHAR), 2) + ':' + RIGHT('0' + CAST(DATEDIFF(MINUTE, StartDateTime, GETDATE()) % 60 AS VARCHAR), 2) + ':' + RIGHT('0' + CAST(DATEDIFF(second, StartDateTime, GETDATE()) % 60 AS VARCHAR), 2)
		FROM(SELECT DATEDIFF(DAY, sqlserver_start_time, GETDATE())AS DayDiff)AS dd
			CROSS APPLY(SELECT
			CASE
				WHEN DayDiff > 1 
					THEN DATEADD(DAY, DayDiff - 1, sqlserver_start_time)
					ELSE sqlserver_start_time
				END AS StartDateTime)AS b)AS SystemUpTime,
						total_physical_memory_kb / 1024 AS TotalPhysicalMemoryMB,
						available_physical_memory_kb / 1024 AS AvailPhysicalMemoryMB,
						system_memory_state_desc AS SystemMemoryState,
						physical_memory_in_use_kb / 1024 AS MemInUseMB,
						memory_utilization_percentage AS [MemUtil%]
		FROM sys.dm_os_sys_memory AS sm(NOLOCK)
			CROSS JOIN sys.dm_os_process_memory AS pm(NOLOCK)
			CROSS JOIN sys.dm_os_sys_info AS si(NOLOCK))

-- ------------------------------------------------------------------------------------
-- INSERT INTO CENTRALSERVER - sqlsysinfos (UPLOAD)
-- ------------------------------------------------------------------------------------
 --INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.sqlsysinfo 
 SELECT
	 CONVERT(VARCHAR(128), SERVERPROPERTY('Servername'))AS server,
	 @osrel as WindowsVersion,
	 @ossp as WindowsSPVersion,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('MachineName'))AS MachineName,
	 InstanceName = CASE
	 WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('InstanceName')) IS NULL THEN 'MSSQLSERVER'
	 ELSE CONVERT(VARCHAR(128), SERVERPROPERTY('InstanceName')) 
	 END,
	 @LoginMode AS AuthenticationMode,
	 @pit as PIT,
	 @domainname as Domain,
	 @MSSQLServiceAccountName AS SQLServiceAccount,
	 @SQLAgentServiceAccountName AS SQLAgentServiceAccount,
	 @sadmv AS sysadmin_version,
	 (SELECT
	CASE
	 WHEN ISNUMERIC(DATA) = 1 THEN CAST(DATA AS INT)
	 END
	FROM @RegRead)AS Port,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))AS ComputerNamePhysicalNetBIOS,
	 CASE
	 WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('IsClustered')) = 1 THEN 'Clustered'
	 WHEN SERVERPROPERTY('IsClustered') = 0 THEN 'Not Clustered'
	 WHEN SERVERPROPERTY('IsClustered') = NULL THEN 'Error'
	 END AS IsClustered,
	 (SELECT TOP 1
	 Text
	FROM @SystemManufacturer)AS SystemManufacturer,
	 @ProcessorInfo AS ProcessorInfo,
	 s.*,
	 CONVERT(INT, SERVERPROPERTY('ProcessId'))AS ProcessId,
	 CONVERT(INT, SERVERPROPERTY('IsSingleUser'))AS IsSingleUser,
	 	 CASE
		 WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('EditionID')) = -1253826760 THEN 'Desktop Edition'
		 WHEN SERVERPROPERTY('EditionID') = -1592396055 THEN 'Express Edition'
		 WHEN SERVERPROPERTY('EditionID') = -1534726760 THEN 'Standard Edition'
		 WHEN SERVERPROPERTY('EditionID') = 1333529388 THEN 'Workgroup Edition'
		 WHEN SERVERPROPERTY('EditionID') = 1804890536 THEN 'Enterprise Edition'
		 WHEN SERVERPROPERTY('EditionID') = -323382091 THEN 'Personal Edition'
		 WHEN SERVERPROPERTY('EditionID') = -2117995310 THEN 'Developer Edition'
		 WHEN SERVERPROPERTY('EditionID') = 610778273 THEN 'Enterprise Evaluation Edition'
		 WHEN SERVERPROPERTY('EditionID') = 1044790755 THEN 'Windows Embedded SQL'
		 WHEN SERVERPROPERTY('EditionID') = 4161255391 THEN 'Express Edition with Advanced Services'
		 WHEN SERVERPROPERTY('EditionID') = 284895786 THEN 'Business Intelligence Edition'
		 WHEN SERVERPROPERTY('EditionID') = 1872460670 THEN 'Enterprise Edition: Core-based Licensing'
	 END AS ProductEdition,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ProductVersion'))AS ProductVersion,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ProductLevel'))AS ProductLevel,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ResourceLastUpdateDateTime'))AS ResourceLastUpdateDateTime,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ResourceVersion'))AS ResourceVersion,
	 CASE
		 WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 1 THEN 'Integrated security'
		 WHEN SERVERPROPERTY('IsIntegratedSecurityOnly') = 0 THEN 'Not Integrated security'
	 END AS IsIntegratedSecurityOnly,
	 CASE
		 WHEN SERVERPROPERTY('EngineEdition') = 1 THEN 'Personal Edition'
		 WHEN SERVERPROPERTY('EngineEdition') = 2 THEN 'Standard Edition'
		 WHEN SERVERPROPERTY('EngineEdition') = 3 THEN 'Enterprise Edition'
		 WHEN SERVERPROPERTY('EngineEdition') = 4 THEN 'Express Edition'
	 END AS EngineEdition,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('LicenseType'))AS LicenseType,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('NumLicenses'))AS NumLicenses,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('BuildClrVersion'))AS BuildClrVersion,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('Collation'))AS Collation,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('CollationID'))AS CollationID,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('ComparisonStyle'))AS ComparisonStyle,
	 CASE
		 WHEN CONVERT(VARCHAR(128), SERVERPROPERTY('IsFullTextInstalled')) = 1 THEN 'Full-text is installed'
		 WHEN SERVERPROPERTY('IsFullTextInstalled') = 0 THEN 'Full-text is not installed'
		 WHEN SERVERPROPERTY('IsFullTextInstalled') = NULL THEN 'Error'
	 END AS IsFullTextInstalled,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('SqlCharSet'))AS SqlCharSet,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('SqlCharSetName'))AS SqlCharSetName,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('SqlSortOrder'))AS SqlSortOrderID,
	 CONVERT(VARCHAR(128), SERVERPROPERTY('SqlSortOrderName'))AS SqlSortOrderName,
	 (SELECT [SQLversion] = CASE
		WHEN @version LIKE '13.0%' THEN '2016'
		WHEN @version LIKE '12.0%' THEN '2014'
		WHEN @version LIKE '11.0%' THEN '2012'
		WHEN @version LIKE '10.%' THEN '2008'
		WHEN @version LIKE '9.0%' THEN '2005' END) as [SQLversion],
	 (SELECT create_date FROM sys.server_principals WHERE sid = 0x010100000000000512000000) as SQLInstDate,
	 (SELECT CASE WHEN (SELECT SERVERPROPERTY ('IsHadrEnabled')) = 1 THEN 1 ELSE 0 END) as IsHadrEnabled,
	 (SELECT TOP 1 [IsMirroringEnabled] = CASE WHEN [mirroring_state] IS NOT NULL THEN 1 ELSE 0 END FROM sys.database_mirroring ORDER BY [mirroring_state] DESC) as IsMirroringEnabled,
	 (SELECT TOP 1 [is_encrypted] = CASE WHEN [is_encrypted] = '1' THEN 1 ELSE 0 END FROM sys.databases ORDER BY [is_encrypted] DESC) as ContainsEncryptedDBs,
	 CAST ((SELECT value
			FROM fn_listextendedproperty(default, default, default, default, default, default, default)
			WHERE name in ('Comment')) as VARCHAR (4000)) as Comment
	 INTO #tmp_sysinfo
FROM sysInfo AS s

EXECUTE ('INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[sqlsysinfo]
           ([server]
           ,[WindowsVersion]
           ,[WindowsSPVersion]
           ,[MachineName]
           ,[InstanceName]
           ,[AuthenticationMode]
           ,[PIT]
           ,[Domain]
           ,[SQLServiceAccount]
           ,[SQLAgentServiceAccount]
           ,[SysAdminVersion]
           ,[Port]
           ,[ComputerNamePhysicalNetBIOS]
           ,[IsClustered]
           ,[SystemManufacturer]
           ,[ProcessorInfo]
           ,[cpu_count]
           ,[hyperthread_ratio]
           ,[sqlserver_start_time]
           ,[SystemUpTime]
           ,[TotalPhysicalMemoryMB]
           ,[AvailPhysicalMemoryMB]
           ,[SystemMemoryState]
           ,[MemInUseMB]
           ,[MemUtil%]
           ,[ProcessId]
           ,[IsSingleUser]
           ,[ProductEdition]
           ,[ProductVersion]
           ,[ProductLevel]
           ,[ResourceLastUpdateDateTime]
           ,[ResourceVersion]
           ,[IsIntegratedSecurityOnly]
           ,[EngineEdition]
           ,[LicenseType]
           ,[NumLicenses]
           ,[BuildClrVersion]
           ,[Collation]
           ,[CollationID]
           ,[ComparisonStyle]
           ,[IsFullTextInstalled]
           ,[SqlCharSet]
           ,[SqlCharSetName]
           ,[SqlSortOrderID]
           ,[SqlSortOrderName]
		   ,[SQLversion]
		   ,[SQLInstDate]
		   ,[IsHadrEnabled]
		   ,[IsMirroringEnabled]
		   ,[ContainsEncryptedDBs]
           ,[comment]) 
			SELECT * FROM #tmp_sysinfo ')

----------------------------------------------------
-- Section SYSINFO END
----------------------------------------------------
BEGIN 
----------------------------------------------------
-- Section sqldbs
----------------------------------------------------
IF OBJECT_ID('tempdb..#properties') IS NOT NULL
    DROP TABLE #properties 

IF OBJECT_ID('tempdb..#extendedproperty') IS NOT NULL
    DROP TABLE #extendedproperty 

DECLARE @cr_date VARCHAR(30)
DECLARE @creator varchar(60) 
DECLARE @service varchar(1000)
DECLARE @descr varchar(1000)
DECLARE @dbsize varchar(10)
DECLARE @dbname VARCHAR(150)

CREATE TABLE #properties (dbname varchar(150),creator varchar(60),it_service varchar(1000),description varchar(1000)) 
CREATE TABLE #extendedproperty (dbname varchar(150),name varchar(50),value varchar(1000))

IF @version  >= '11.%' --IN ('2012','2014','2016')
	BEGIN
		DECLARE cur_db CURSOR 
		FOR
		SELECT name FROM sys.databases WHERE state_desc='ONLINE' AND name NOT IN (
                     SELECT DISTINCT
                     dbcs.database_name AS [DatabaseName]
                     FROM master.sys.availability_groups AS AG
                     LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
                     ON AG.group_id = agstates.group_id
                     INNER JOIN master.sys.availability_replicas AS AR
                     ON AG.group_id = AR.group_id
                     INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
                     ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
                     INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
                     ON arstates.replica_id = dbcs.replica_id
                     LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
                     ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
                     WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1
                     )
	END
ELSE
	BEGIN
		DECLARE cur_db CURSOR 
		FOR
		SELECT name FROM sys.databases WHERE state_desc='ONLINE'
	END
OPEN cur_db 
FETCH NEXT FROM cur_db INTO @dbname
        WHILE @@FETCH_STATUS = 0
        BEGIN

	EXECUTE ('INSERT INTO #extendedproperty (dbname,name ,value)
		SELECT '''+@dbname+''', CONVERT(sysname,name),CONVERT(sysname,value) 
							from ['+@dbname+'].sys.fn_listextendedproperty(default, default, default, default, default, default, default) 
							where name in (''Creator'',''IT_Service'',''Description'')' )

-- EXEC (@stmt)

FETCH NEXT FROM cur_db INTO @dbname
END	
CLOSE cur_db
DEALLOCATE cur_db

	-- Werte aus @extendedproperty umformen und in Temporäre Tabelle @properties speichern
	INSERT INTO #properties
		SELECT distinct (p.dbname )
        , p1.value AS creator 
        , p2.value AS IT_Service      
        , p3.value AS Description 
         FROM #extendedproperty   p 
        LEFT OUTER JOIN #extendedproperty p1 ON p.dbname=p1.dbname AND p1.name='creator' 
        LEFT OUTER JOIN #extendedproperty p2 ON p.dbname=p2.dbname AND p2.name='IT_Service' 
        LEFT OUTER JOIN #extendedproperty p3 ON p.dbname=p3.dbname AND p3.name='Description' 
	-- @properties abfüllen mit restlichen Datenbanken ohne Services
	INSERT INTO #properties (dbname) SELECT name 
		FROM sys.databases 
		WHERE name NOT IN (SELECT dbname FROM #properties)

----------------------------------------------------
-- delete sqldbs für diesen Server
----------------------------------------------------
	EXECUTE (' 	DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[sqldbs] WHERE server=@@SERVERNAME ')
		
----------------------------------------------------
-- insert into sqldbs  
-- server_databases(_version) auskommentiert, neu in der Procedure USP_HARDENING
----------------------------------------------------

SET @stmt = '
DECLARE ins_cur CURSOR
FOR
SELECT  s.name,ISNULL((p.creator),'''')  ,ISNULL((p.it_service),''''),ISNULL((p.description),'''') ,s.create_date
	from sys.databases s
	JOIN #properties p on s.name = p.dbname 
		WHERE state = 0 
		AND s.name NOT IN (''tempdb'',''model'',''master'',''msdb'')
		AND s.name NOT LIKE ''ReportServer%''
		AND s.name NOT IN (SELECT dbname COLLATE Latin1_General_CI_AS FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[sqldbs] 
																	  WHERE server = @@SERVERNAME) '
						
EXEC (@stmt)
						
OPEN ins_cur
FETCH NEXT FROM ins_cur INTO @dbname,@creator,@service,@descr,@cr_date
WHILE @@FETCH_STATUS = 0
BEGIN --Block ins
	
	BEGIN TRY 
		-- Insert into SqlDBs
		SET @stmt =   'insert into [CENTRALSERVER].[P95_DBAReports].[dbo].[sqldbs] (
						server,dbname,bemerkung,service,datum,create_datum,creator) 
						values (@@servername,'''+@dbname+''','''+@descr+''','''+@service+''',getdate(),'''+@cr_date+''','''+@creator+''')'
		--PRINT @stmt
		EXEC (@stmt)
		-- Update der Tabelle SqlDBs mit der DB Size pro Datenbank
		SET @stmt =		'update [CENTRALSERVER].[P95_DBAReports].[dbo].[sqldbs] set dbsize = (SELECT sum(size/128) FROM ['+@dbname+']..sysfiles ),datum = getdate() where dbname = '''+@dbname+''' and server = @@SERVERNAME'
		EXEC (@stmt)
		--PRINT @stmt
	END TRY
	BEGIN CATCH
		--PRINT ERROR_MESSAGE()
		IF ERROR_MESSAGE() LIKE '%is participating in an availability group%'
		--PRINT @dbname
		EXECUTE (' UPDATE [CENTRALSERVER].[P95_DBAReports].[dbo].[sqldbs] SET ao_status = ''secondary'' where dbname = '''+@dbname+''' and server = @@SERVERNAME ')
	END CATCH
	FETCH NEXT FROM ins_cur INTO @dbname,@creator,@service,@descr,@cr_date
END --Block ins 
CLOSE ins_cur
DEALLOCATE ins_cur

----------------------------------------------------
-- Section procversion
----------------------------------------------------
----------------------------------------------------
-- delete procversion für diesen Server
----------------------------------------------------
	EXECUTE (' 	DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[procversion] WHERE server=@@SERVERNAME ')
----------------------------------------------------
-- insert into procversion
----------------------------------------------------
SET @stmt = '
DECLARE ins_cur  CURSOR FOR
SELECT tab_proc_name,procvers,
	modified = CASE
	WHEN modified IS NULL THEN created
	ELSE modified
	END
	FROM versioncheck
	WHERE tab_proc_name NOT IN (
	SELECT tab_proc_name COLLATE Latin1_General_CI_AS
		FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[procversion]
		WHERE server=@@SERVERNAME )'

EXEC (@stmt)

BEGIN
	OPEN ins_cur
	FETCH next from ins_cur INTO @tab_proc_name,@procvers,@modified
	WHILE @@FETCH_STATUS = 0
	BEGIN --Block insert into procversion
		BEGIN TRY 
			SET @stmt = 'insert into [CENTRALSERVER].[P95_DBAReports].[dbo].[procversion] (server,tab_proc_name,procvers,modified) values ('''+@@SERVERNAME+''','''+@tab_proc_name+''','''+@procvers+''','''+@modified+''')'
			EXEC (@stmt)
			--print @stmt
		END TRY
		BEGIN CATCH
			PRINT ERROR_MESSAGE()
			PRINT @@SERVERNAME
		END CATCH
		FETCH NEXT FROM ins_cur INTO @tab_proc_name,@procvers,@modified
	END --Block ins 
	CLOSE ins_cur
	DEALLOCATE ins_cur
END --insert procversion

END --END Proc

----------------------------------------------------
-- Section Logs 
----------------------------------------------------

EXECUTE (' DELETE FROM CENTRALSERVER.P95_DBAReports.dbo.logs WHERE server = @@servername AND action_time < DATEADD(day, -90, GETDATE())
INSERT INTO CENTRALSERVER.P95_DBAReports.dbo.logs SELECT @@SERVERNAME, * FROM logs
WHERE logid NOT IN (SELECT logid FROM CENTRALSERVER.P95_DBAReports.dbo.logs WHERE server=@@SERVERNAME)	
AND action_time > GETDATE()-30 ')

----------------------------------------------------
-- Section no_backup
----------------------------------------------------

EXECUTE ('DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[no_backup]
	WHERE server = @@SERVERNAME')

EXECUTE ('INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[no_backup]
SELECT @@SERVERNAME, * FROM IT2_SysAdmin.dbo.no_backup')

----------------------------------------------------
-- Section Clusternodes 
----------------------------------------------------

IF EXISTS (select * from sys.dm_os_cluster_nodes)
BEGIN
PRINT 'I am a CLUSTER :-)'

SET @actnode = LOWER(CONVERT(sysname,SERVERPROPERTY('ComputerNamePhysicalNetBIOS')))

IF OBJECT_ID('tempdb..#oldnode') IS NOT NULL
    DROP TABLE #oldnode

CREATE TABLE #oldnode (actnode VARCHAR(20))

EXECUTE ('INSERT INTO #oldnode SELECT actnode FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[clusternodesv2] WHERE server=@@SERVERNAME')

-- / Tabelle sqlnodes abfüllen mit allen Physikalischen Nodes pro SQL Instanz 
EXECUTE (' INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].sqlnodes (server, physicalnode) 
	SELECT @@SERVERNAME, NodeName FROM sys.dm_os_cluster_nodes
								  WHERE NodeName COLLATE DATABASE_DEFAULT not in (SELECT  physicalnode 
														 FROM [CENTRALSERVER].[P95_DBAReports].[dbo].sqlnodes 
														 WHERE server = @@SERVERNAME) ')

EXECUTE (' DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[clusternodesv2] WHERE server = @@SERVERNAME ')

IF OBJECT_ID('tempdb..#ocn') IS NOT NULL
    DROP TABLE #ocn 
	 
	  CREATE TABLE #ocn (ID VARCHAR(2), nodename VARCHAR(20))
	  
	  INSERT INTO #ocn SELECT ROW_NUMBER() OVER (ORDER BY NodeName ASC) AS ROWID, NodeName FROM sys.dm_os_cluster_nodes
	  
	SELECT @cols = STUFF((SELECT DISTINCT ',' + QUOTENAME(nodename)
						FROM #ocn
				FOR XML PATH(''), TYPE
				).value('.', 'NVARCHAR(MAX)') 
			,1,1,'')

	SELECT @nodes = STUFF((SELECT distinct ',' + QUOTENAME('node'+ID) 
						FROM #ocn
				FOR XML PATH(''), TYPE
				).value('.', 'NVARCHAR(MAX)') 
			,1,1,'')

	SET @stmt = 'INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[clusternodesv2] (server,actnode,'+@nodes+')'+' '+'SELECT  @@servername,'+@actnode+' as actnode,' + @cols + ' from 
				 (
					select nodename
					from #ocn
				) x
				pivot 
				(
					max(nodename)
					for nodename in (' + @cols + ')
				) p '

	--PRINT @stmt
	EXEC(@stmt)

IF (SELECT actnode FROM #oldnode) <> @actnode
	
	EXECUTE ('UPDATE [CENTRALSERVER].[P95_DBAReports].[dbo].[clusternodesv2] SET actnode='''+@actnode+''',nodechanged=getdate() WHERE server=@@SERVERNAME ')
	END

ELSE 
	PRINT 'This Instance is not part of a failover cluster!'
-- ------------------------------------------------------------------------------------------------
-- Collect Database used and free space
-- ------------------------------------------------------------------------------------------------

-- Declare internal variables
  DECLARE
  @db_name	NVARCHAR(150)

  DECLARE @ALLOCATION_TABLE table
	(
		dbname sysname,
		reservedpages bigint,
		usedpages bigint,
		pages bigint
	)

-- REMOVE - Old Entries
  DELETE FROM IT2_SysAdmin.dbo.database_size  WHERE ins_date < DATEADD(day, -180, GETDATE())


-- Declare DB Cursor
  IF (SELECT  substring(CONVERT(sysname,SERVERPROPERTY('ProductVersion')),0,5)) >= '11.%'
			BEGIN	/*	Cursor f�r Datenbanken ab SQL Server 2012	*/
				DECLARE cur_db  CURSOR STATIC LOCAL FOR
					SELECT name FROM sys.databases 
								WHERE state = 0 
								--AND name <> 'tempdb'
								AND database_id NOT IN (SELECT database_id FROM sys.dm_hadr_database_replica_states)
								OR name IN (SELECT a.database_name  FROM sys.availability_databases_cluster a
																	JOIN sys.dm_hadr_availability_group_states b ON a.group_id = b.group_id
																		WHERE primary_replica = @@SERVERNAME)
					ORDER BY name
            END
			
		ELSE
			BEGIN	/*	Cursor f�r Datenbanken kleiner SQL Server 2012 (2005,2008/R2)	*/
				DECLARE cur_db  CURSOR STATIC LOCAL FOR
					SELECT name FROM sys.databases 
								WHERE state = 0
								--AND name <> 'tempdb'
								AND name NOT IN (SELECT value FROM IT2_SysAdmin.dbo.t_localsettings WHERE definition = 'DiffBackup')
								AND name NOT IN (SELECT dbname from IT2_SysAdmin.dbo.no_backup)
					ORDER BY name
			END

-- Open DB Cursor - GET PAGE INFORMATIONS
			OPEN cur_db
			  FETCH NEXT FROM cur_db INTO @db_name
			  WHILE @@FETCH_STATUS = 0
			  BEGIN

			  INSERT INTO @ALLOCATION_TABLE
					EXEC
					('
					USE ['+@db_name+'] 
					SELECT '''+@db_name+''',
					SUM(a.total_pages) as reservedpages,
					SUM(a.used_pages) as usedpages,
					SUM(
						CASE
							When it.internal_type IN (202,204,211,212,213,214,215,216) Then 0
							When a.type <> 1 Then a.used_pages
							When p.index_id < 2 Then a.data_pages
							Else 0
						END
					) as pages
					FROM ['+@db_name+'].sys.partitions p join ['+@db_name+'].sys.allocation_units a on p.partition_id = a.container_id
					LEFT JOIN ['+@db_name+'].sys.internal_tables it on p.object_id = it.object_id
					')
			  FETCH NEXT FROM cur_db INTO @db_name
			  END 
			CLOSE cur_db
			DEALLOCATE cur_db

-- Collect Database Size
  INSERT INTO [IT2_SysAdmin].[dbo].[database_size]
  SELECT
        -- from first result set of 'exec sp_spacedused'
        @@SERVERNAME 
		,DB_NAME(sf.database_id)
        ,LTRIM(STR((CONVERT (DEC (15,2),sf.dbsize) + CONVERT (DEC (15,2),sf.logsize)) * 8192 / 1048576,15,2))
        ,LTRIM(STR((CASE WHEN sf.dbsize >= pages.reservedpages THEN
            (CONVERT (DEC (15,2),sf.dbsize) - convert (DEC (15,2),pages.reservedpages))
            * 8192 / 1048576 ELSE 0 END),15,2))
		,GETDATE()
    FROM (
        SELECT
            database_id,
            SUM(CONVERT(BIGINT,CASE WHEN TYPE = 0 THEN size ELSE 0 END)) AS dbsize,
            SUM(CONVERT(BIGINT,CASE WHEN TYPE <> 0 THEN size ELSE 0 END)) AS logsize
        FROM sys.master_files
        GROUP BY database_id
    ) sf,
    (
    SELECT
            dbname,
            reservedpages,
            usedpages,
            pages
            FROM @ALLOCATION_TABLE
     ) pages
  WHERE DB_NAME(sf.database_id)= pages.dbname

-- Import to CENTRALSERVER

  EXECUTE ('
		DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[database_size] 
		WHERE server = @@servername
		')

  EXECUTE ('
  INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[database_size]
  SELECT ds.[server], ds.[database], ds.[db_size_in_mb], ds.[db_size_free_in_mb], ds.[ins_date] FROM [IT2_SysAdmin].[dbo].[database_size] as ds
  INNER JOIN (SELECT [database], MAX([ins_date]) as [ins_date]
				FROM [IT2_SysAdmin].[dbo].[database_size]
					GROUP BY [database]) AS groupds
  ON ds.[database] = groupds.[database]
  AND ds.[ins_date] = groupds.[ins_date]
  ')

----------------------------------------------------
-- GET HA Information - AlwaysOn Availability Groups
----------------------------------------------------
IF @version  >= '11.%' --IN ('2012','2014','2016')
BEGIN
	IF OBJECT_ID('tempdb..#AgName') IS NOT NULL
		DROP TABLE #AgName
	CREATE TABLE #AgName (ag_name NVARCHAR(256))

	IF ((SELECT SERVERPROPERTY('IsHadrEnabled')) = 1)
	BEGIN

	  SELECT @roledesc = [primary_replica]
	  FROM sys.dm_hadr_name_id_map as dhnim
	  INNER JOIN sys.dm_hadr_availability_group_states dhags
				ON dhnim.ag_id = dhags.group_id
		WHERE [primary_replica] = UPPER(@@SERVERNAME)

	  INSERT INTO #AgName (ag_name)
	  SELECT ag_name
	  FROM sys.dm_hadr_name_id_map as dhnim
	  INNER JOIN sys.dm_hadr_availability_group_states dhags
				ON dhnim.ag_id = dhags.group_id
			WHERE [primary_replica] = UPPER(@@SERVERNAME)

	  IF @roledesc = UPPER(@@SERVERNAME)
	  BEGIN
			-- DELETE OLD ENTRIES
			EXECUTE ('DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_aoag]
			WHERE cluster_name = (SELECT DISTINCT cluster_name FROM sys.dm_hadr_cluster) AND ag_name COLLATE DATABASE_DEFAULT IN (SELECT ag_name FROM #AgName)')
			
			-- INSERT NEW ENTRIES
			EXECUTE ('INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_aoag]
			   ([cluster_name]
			   ,[node_name]
			   ,[instance_name]
			   ,[ag_name]
			   ,[ag_role]
			   ,[dns_name]
			   ,[port]
			   ,[database_name]
			   ,[ins_date])
			SELECT 
				(SELECT cluster_name FROM sys.dm_hadr_cluster) as ''cluster_name'', 
				[node_name], 
				[instance_name], 
				[ag_name], 
				''ag_role'' = CASE WHEN UPPER([primary_replica]) = UPPER([instance_name]) THEN ''Primary'' WHEN UPPER([primary_replica]) != UPPER([instance_name]) THEN ''Secondary''  END,
				[dns_name], 
				[port], 
				[database_name],
				GETDATE()
			FROM sys.dm_hadr_instance_node_map as dhinm
			INNER JOIN sys.dm_hadr_name_id_map as dhnim
				ON dhinm.ag_resource_id = dhnim.ag_resource_id
			LEFT JOIN sys.availability_databases_cluster as adc
				ON dhnim.ag_id = adc.group_id
			LEFT JOIN sys.availability_group_listeners as agl
				ON dhnim.ag_id = agl.group_id
			INNER JOIN sys.dm_hadr_availability_group_states dhags
				ON dhnim.ag_id = dhags.group_id
			WHERE [primary_replica] = UPPER(@@SERVERNAME)')
	  END
	 
	END
END

----------------------------------------------------
-- GET HA Information - Mirroring
----------------------------------------------------
IF EXISTS (SELECT TOP 1 * FROM sys.database_mirroring WHERE mirroring_state IS NOT NULL)
BEGIN

	SELECT @roledesc = [mirroring_role_desc]
	FROM sys.database_mirroring
	WHERE mirroring_state IS NOT NULL AND mirroring_role_desc = 'PRINCIPAL'

	-- DELETE OLD ENTRIES
	EXECUTE ('DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_mirroring]
		WHERE [instance_name] = @@SERVERNAME')

	IF @roledesc = 'PRINCIPAL'
	BEGIN
		-- INSERT NEW ENTRIES
		EXECUTE ('INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_mirroring]
			   ([instance_name]
			   ,[db_name]
			   ,[mirroring_role_desc]
			   ,[mirroring_partner_instance]
			   ,[mirroring_partner_name]
			   ,[ins_date])
		SELECT @@SERVERNAME AS ''instance_name'' ,DB_NAME(database_id) AS [db_name], [mirroring_role_desc], [mirroring_partner_instance], [mirroring_partner_name], GETDATE()
		FROM sys.database_mirroring
		WHERE mirroring_state IS NOT NULL AND mirroring_role_desc = ''PRINCIPAL''')
	END
	
END

----------------------------------------------------
-- GET HA Information - SQL Server Failover Cluster
----------------------------------------------------
IF ((SELECT SERVERPROPERTY('IsClustered')) = 1)
BEGIN
  
  -- GET WINDOWS VERSION
  IF @version like '10.0.%'
	BEGIN
		SELECT @osrel = RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3)
	END
  ELSE
	BEGIN
		SELECT @osrel = windows_release FROM sys.dm_os_windows_info
	END
  
  IF (@osrel < 6.2) -- FOR WINDOWS SERVER 2008 & 2008R2
  BEGIN
	  EXECUTE master.dbo.xp_regread 
	  'HKEY_LOCAL_MACHINE', 
	  'Cluster', 
	  'ClusterName', 
	  @cluster_name OUTPUT
  END
  ELSE -- FOR WINDOWS SERVER 2012 AND HIGHER
  BEGIN
	  EXECUTE master.dbo.xp_regread 
	  'HKEY_LOCAL_MACHINE', 
	  '0.Cluster', 
	  'ClusterName', 
	  @cluster_name OUTPUT
  END
  
  -- DELETE OLD ENTRIES
  EXECUTE ('DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_fci] WHERE [instance_name] = @@SERVERNAME')
  
  -- INSERT NEW ENTRIES
  EXECUTE ('INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[ha_info_fci]
           ([cluster_name]
           ,[instance_name]
           ,[nodename]
           ,[is_current_owner]
		   ,[ins_date])
  SELECT 
	'''+@cluster_name+''' as ''cluster_name'', 
	@@servername as ''instance_name'', 
	[NodeName] as ''nodename'', 
	[is_current_owner] = CASE WHEN [NodeName] = (SELECT SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'')) THEN 1 
							  WHEN [NodeName] <> (SELECT SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'')) THEN 0 END,
	GETDATE()
	FROM sys.dm_os_cluster_nodes')
	
END
  
-- ------------------------------------------------------------------------------------------------
-- END procedure exec USP_COLLECT_SERVERDATA
-- ------------------------------------------------------------------------------------------------

GO
