USE [IT2_SysAdmin]
GO
-- 17 Procedure USP_GET_LOGINS
IF (SELECT tab_proc_name FROM versioncheck WHERE tab_proc_name like 'USP_GET_LOGINS') IS NULL
INSERT INTO [IT2_SysAdmin].[dbo].[versioncheck] ([tab_proc_name], version, created, procvers) VALUES ('USP_GET_LOGINS','$(pstdvers)',GETDATE(),'1.01')
ELSE
UPDATE IT2_SysAdmin.dbo.versioncheck SET procvers = '1.01', modified = GETDATE() WHERE tab_proc_name = 'USP_GET_LOGINS'
GO
PRINT '---------------------------------------
17 create [USP_GET_LOGINS]
---------------------------------------'
GO
IF EXISTS(SELECT name FROM sysobjects WHERE name = 'USP_GET_LOGINS' AND type = 'P')
DROP PROCEDURE  [dbo].[USP_GET_LOGINS]
GO
-- ------------------------------------------------------------------------------------------------
-- create procedure
-- ------------------------------------------------------------------------------------------------
CREATE  PROCEDURE [dbo].[USP_GET_LOGINS] 
-- ------------------------------------------------------------------------------------------------
-- Object Name:           USP_GET_DBAUSERS
-- Object Type:           stored procedure
-- Database:              IT2_SysAdmin
-- Synonym:               
-- Version:               1.0
-- Date:                  15.11.2011
-- Autor:                 Pascal Braendle, IT226
-- Copyright:             ©Die Schweizerische Post 2012
-- ------------------------------------------------------------------------------------------------
-- Used for:
-- =========
-- Sendet Logins an den CentralServer
-- 
-- ------------------------------------------------------------------------------------------------
-- Parameter:
-- ==========
-- keine
-- ------------------------------------------------------------------------------------------------
-- Possible improvement
-- ====================
-- 
-- ------------------------------------------------------------------------------------------------
-- Last Modification:
-- ==================
-- Autor							Version		Date		What
-- Pascal Braendle, IT226			1.00		15.11.11	erstellt
-- Roger Bugmann, IT222				1.01		03.07.15	Upload Statements verpackt, das die Procedure auch installiert wird wenn
--															die Firewall Rule zum Centralserver noch nicht besteht
-- ------------------------------------------------------------------------------------------------
  AS

-- --------------------------------------------------------------------------------------------
-- Alte Einträge löschen
-- --------------------------------------------------------------------------------------------
EXECUTE ('DELETE FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[personal_logins] WHERE server = @@SERVERNAME')
-- --------------------------------------------------------------------------------------------
-- Neue Einträge generieren
-- --------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#tmp_logins') IS NOT NULL
    DROP TABLE #tmp_logins 

	SELECT @@SERVERNAME server
	 , SL.name login_name  
     , CASE SL.sysadmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [sysadmin]  
     , CASE SL.securityadmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [securityadmin]  
     , CASE SL.serveradmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [serveradmin]  
     , CASE SL.setupadmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [setupadmin]  
     , CASE SL.processadmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [processadmin]  
     , CASE SL.diskadmin WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [diskadmin]  
     , CASE SL.dbcreator WHEN 0 THEN 'No' WHEN 1 THEN 'Yes' ELSE 'N/A' END AS [dbcreator] 
     , SP.type_desc
     , SP.is_disabled
     , SP.default_database_name 
     , SP.create_date
     , SP.modify_date
	INTO #tmp_logins
	FROM sys.syslogins AS SL, sys.server_principals AS SP
    CROSS APPLY (
    SELECT CASE WHEN SRM.member_principal_id IS NULL THEN 'N' ELSE 'Y' END AS bulkadmin
    FROM sys.server_principals AS SR
		LEFT JOIN sys.server_role_members AS SRM
			ON SR.principal_id = SRM.role_principal_id
			AND SRM.member_principal_id = SP.principal_id
        WHERE SR.type = 'R'
        AND SR.name = 'bulkadmin'
    ) AS SRBA
    CROSS APPLY (
        SELECT CASE WHEN SRM.member_principal_id IS NULL THEN 'N' ELSE 'Y' END AS dbcreator
        FROM sys.server_principals AS SR
            LEFT JOIN sys.server_role_members AS SRM
                ON SR.principal_id = SRM.role_principal_id
                AND SRM.member_principal_id = SP.principal_id
        WHERE SR.type = 'R'
        AND SR.name = 'dbcreator'
    ) AS SRDC
WHERE SP.type IN ('S', 'U', 'G') /* S = SQL Login, U = Windows Login, G = Windows Group */
AND SL.name=SP.name
ORDER BY SP.type_desc, SP.name

-- --------------------------------------------------------------------------------------------
-- Upload zum Centralserver
-- --------------------------------------------------------------------------------------------
EXECUTE (' INSERT INTO [CENTRALSERVER].[P95_DBAReports].[dbo].[personal_logins]	
			SELECT * FROM #tmp_logins WHERE login_name not in (
									select login_name COLLATE Latin1_General_CI_AS
										FROM [CENTRALSERVER].[P95_DBAReports].[dbo].[personal_logins]
										WHERE server = @@SERVERNAME) ')

  -- ----------------------------------------------------------------------------------------------
  -- EOF
  -- ---------------------------------------------------------------------------------------------
GO

