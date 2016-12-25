USE [KAOS]
GO
/****** Object:  StoredProcedure [dbo].[udsp_DLY_ADJUSTMENT_DAILY_REPORT]    Script Date: 4/27/2016 12:53:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author: 
-- Create date: 09/12/2014
-- Description:  This stored proc will insert data INTO the STG_DLY_ADJUSTMENT_DAILY_REPORT
-- =============================================

CREATE PROCEDURE [dbo].[udsp_DLY_ADJUSTMENT_DAILY_REPORT]
AS

BEGIN
SET NOCOUNT ON;
DECLARE  @Final_cnt_stg    bigint
DECLARE  @Init_cnt_stg     bigint
DECLARE @CurrentDate DATETIME
SET @CurrentDate = GETDATE()

-------------Initial count--------------------

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_ADJUSTMENT_DAILY_REPORT',@Init_cnt_stg output

--------------Truncate table-----------------

--exec udsp_truncate_proxy 'KAOS.dbo.STG_DLY_ADJUSTMENT_DAILY_REPORT'

TRUNCATE TABLE KAOS.dbo.STG_DLY_ADJUSTMENT_DAILY_REPORT

--------------------------------------------------------------------------------------------------------
--------------------

declare @epochyesterday varchar(10)
set @epochyesterday =  datediff(ss,'1970-01-01',DATEADD(DAY,-1,convert(date,(GETDATE()))));

Declare @RunTime as varchar(8)
Declare @StartTime as datetime = getdate()


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#EBM_ST') IS NOT NULL
DROP TABLE #EBM_ST
SELECT EBM.OBJ_ID0,ST.STRING
INTO #EBM_ST
FROM [BRM_ODS].[dbo].EVENT_BILLING_MISC_T EBM WITH (NOLOCK)--ON  E.POID_ID0=EBM.OBJ_ID0
left JOIN [BRM_ODS].[dbo].STRINGS_T ST  WITH (NOLOCK) ON EBM.REASON_DOMAIN_ID=ST.[VERSION] AND EBM.REASON_ID=ST.STRING_ID 
WHERE ST.[DOMAIN] LIKE 'Reason%'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('1 Complete (#EBM_ST is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__OBJ_ID0] ON #EBM_ST(OBJ_ID0 ASC)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('1a Complete (INDEX [TEMP__IX__OBJ_ID0] is Created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#E') IS NOT NULL
DROP TABLE #E
SELECT E.ITEM_OBJ_ID0,E.START_T,E.CREATED_T,E.DESCR,E.POID_ID0, E.ACCOUNT_OBJ_ID0 ,E.SESSION_OBJ_ID0
INTO #E
FROM [BRM_ODS].[dbo].EVENT_T AS E WITH (NOLOCK)
WHERE E.CREATED_T >@epochyesterday
AND E.POID_TYPE IN ('/event/billing/adjustment/account', '/event/billing/adjustment/item', '/event/billing/rax/adj_refund')
AND E.SERVICE_OBJ_TYPE IS NULL
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('1b Complete (#E is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__POID_ID0__ITEM_OBJ_ID0__ACCOUNT_OBJ_ID0] ON #E (POID_ID0,ITEM_OBJ_ID0,ACCOUNT_OBJ_ID0)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('1c Complete (INDEX [TEMP__IX__POID_ID0__ITEM_OBJ_ID0__ACCOUNT_OBJ_ID0] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************

----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#EIA') IS NOT NULL
DROP TABLE #EIA
SELECT E.ITEM_OBJ_ID0,E.START_T,E.CREATED_T,E.DESCR,E.POID_ID0,E.SESSION_OBJ_ID0,A.POID_ID0 AS ACCOUNT_OBJ_ID0,
         A.ACCOUNT_NO,
         AN.COMPANY AS CUSTOMER_NAME,
         I.ITEM_NO AS ADJUSTMENT_NO,ROUND(SUM(I.ITEM_TOTAL) / COUNT(1), 2) AS ADJUSTMENT_AMOUNT,
         CASE I.CURRENCY 
			--WHEN 840 THEN 'USD' 
			--WHEN 826 THEN 'GBP' ELSE 'EUR' 
					WHEN 36	 THEN 'AUD'
					WHEN 826 THEN 'GBP'
					WHEN 840 THEN 'USD'
					WHEN 978 THEN 'EUR'
			END AS TRANSACTION_CURRENCY_CODE, AN.STATE,
         AN.ZIP,
         AN.CANON_COUNTRY,
         AN.COUNTRY,  REPLACE(REPLACE(REPLACE(AN.ADDRESS, CHAR(13), ''), CHAR(10), ''), CHAR(9), '') AS ADDRESS,
         REPLACE(AN.CITY, CHAR(9), '') AS CITY,EBM.STRING
INTO #EIA
FROM #E E
INNER JOIN #EBM_ST EBM ON  E.POID_ID0=EBM.OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].ITEM_T AS I WITH (NOLOCK) ON I.POID_ID0 = E.ITEM_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS A WITH (NOLOCK) ON E.ACCOUNT_OBJ_ID0 = A.POID_ID0
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AS AN WITH (NOLOCK) ON A.POID_ID0 = AN.OBJ_ID0
WHERE    I.POID_TYPE = '/item/adjustment'
         AND I.ITEM_TOTAL <> 0 AND AN.CONTACT_TYPE = 'PRIMARY'
GROUP BY E.ITEM_OBJ_ID0,E.START_T,E.CREATED_T,E.DESCR,E.POID_ID0,E.SESSION_OBJ_ID0,A.POID_ID0 ,
         A.ACCOUNT_NO,
         AN.COMPANY ,
         I.ITEM_NO ,I.CURRENCY, AN.STATE,
         AN.ZIP,
         AN.CANON_COUNTRY,
         AN.COUNTRY,  REPLACE(REPLACE(REPLACE(AN.ADDRESS, CHAR(13), ''), CHAR(10), ''), CHAR(9), '') ,
         REPLACE(AN.CITY, CHAR(9), '') ,EBM.STRING
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('2 Complete (#EIA is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************



----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#S') IS NOT NULL
DROP TABLE #S
SELECT S.POID_ID0,UAN.FIRST_NAME+' '+UAN.LAST_NAME AS  [USER_NAME]
INTO #S
FROM [BRM_ODS].[dbo].SERVICE_T AS S WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS USER_ACCOUNT WITH (NOLOCK) ON S.ACCOUNT_OBJ_ID0 = USER_ACCOUNT.POID_ID0
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AS UAN WITH (NOLOCK) ON USER_ACCOUNT.POID_ID0 = UAN.OBJ_ID0
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('3 Complete (#S is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__POID_ID0] ON #S (POID_ID0 ASC)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('3a Complete (INDEX [TEMP__IX__POID_ID0] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ES') IS NOT NULL
DROP TABLE #ES
SELECT  ES.POID_ID0,S.[USER_NAME]
INTO #ES
FROM [BRM_ODS].[dbo].EVENT_T AS ES WITH (NOLOCK)--ON E.SESSION_OBJ_ID0 = ES.POID_ID0
INNER JOIN #S AS S  ON ES.SERVICE_OBJ_ID0 = S.POID_ID0
WHERE ES.POID_TYPE = '/event/session'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('3b Complete (#ES is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__POID_ID0] ON #ES(POID_ID0 ASC)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('3c Complete (INDEX [TEMP__IX__POID_ID0_ES] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#C') IS NOT NULL
DROP TABLE #C
SELECT C.REC_ID,C.OBJ_ID0,CG.GL_AR_ACCT
INTO #C
FROM [BRM_ODS].[dbo].CONFIG_T AS CT WITH (NOLOCK) 
LEFT JOIN [BRM_ODS].[dbo].CONFIG_GLID_T AS C WITH (NOLOCK) ON CT.POID_ID0 = C.OBJ_ID0
LEFT JOIN [BRM_ODS].[dbo].CONFIG_GLID_ACCTS_T AS CG WITH (NOLOCK) ON C.OBJ_ID0 = CG.OBJ_ID0
													AND C.REC_ID = CG.REC_ID2
													AND CG.ATTRIBUTE = 1
													AND CG.TYPE = 2
WHERE  CT.POID_ID0 = (SELECT MAX(POID_ID0) FROM   [BRM_ODS].[dbo].CONFIG_T WHERE  POID_TYPE = '/config/glid')
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('4 Complete (#C is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#EB') IS NOT NULL
DROP TABLE #EB
SELECT EB.OBJ_ID0,EB.GL_ID, E.ITEM_OBJ_ID0,E.START_T,E.CREATED_T,E.DESCR,E.POID_ID0,E.SESSION_OBJ_ID0,E.ACCOUNT_OBJ_ID0,
         E.ACCOUNT_NO,
         E.CUSTOMER_NAME,
         E.ADJUSTMENT_NO,E.ADJUSTMENT_AMOUNT,E.TRANSACTION_CURRENCY_CODE, E.[STATE],
         E.ZIP,
         E.CANON_COUNTRY,
         E.COUNTRY,E.[ADDRESS],E.[CITY],E.STRING,C.GL_AR_ACCT
INTO #EB
FROM 
#EIA E
LEFT JOIN [BRM_ODS].[dbo].EVENT_BAL_IMPACTS_T AS EB  WITH (NOLOCK) ON E.POID_ID0 = EB.OBJ_ID0
LEFT JOIN #C C ON  EB.GL_ID=C.REC_ID
--WHERE EB.RESOURCE_ID = 840
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('5 Complete (#EB is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__SESSION_OBJ_ID0_EB] ON #EB (SESSION_OBJ_ID0 ASC)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('5a Complete (INDEX [TEMP__IX__SESSION_OBJ_ID0_EB] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************



----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ADJUSTMENTS_INFO') IS NOT NULL
DROP TABLE #ADJUSTMENTS_INFO
SELECT E.ACCOUNT_OBJ_ID0,
E.ACCOUNT_NO,
E.CUSTOMER_NAME,
E.ADJUSTMENT_NO,
cast(DATEADD(SECOND,-1,dateadd(ss, E.START_T , '1970-01-01'))as date)  AS ADJUSTMENT_DATE, 
cast(DATEADD(SECOND,-1,dateadd(ss, E.CREATED_T , '1970-01-01'))as date) AS CREATED_TIME,
E.ADJUSTMENT_AMOUNT,
E.TRANSACTION_CURRENCY_CODE,
NULL INVOICE_APPLIED_TO
,NULL INVOICE_DATE
,E.STRING AS BRM_REASON_CODE
,REPLACE(REPLACE(E.DESCR, CHAR(13), ''), CHAR(10), '') AS COMMENTS
, UAN.[USER_NAME]
,E.[ADDRESS]
,E.[CITY]
,E.[STATE]
,E.ZIP
,E.CANON_COUNTRY
,E.COUNTRY
,NULL AS [COUNTY]
,E.GL_AR_ACCT AS  [GL_STRING]--EB.OBJ_ID0,EB.GL_ID, E.ITEM_OBJ_ID0,E.POID_ID0,E.SESSION_OBJ_ID0,
INTO #ADJUSTMENTS_INFO
FROM #EB E
Left Join #ES UAN ON UAN.POID_ID0 = E.SESSION_OBJ_ID0
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('6 Complete (#ADJUSTMENTS_INFO is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__ACCOUNT_NO] ON #ADJUSTMENTS_INFO (ACCOUNT_NO)
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('6a Complete (INDEX [TEMP__IX__ACCOUNT_NO] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#1') IS NOT NULL
DROP TABLE #1
SELECT P.NAME,PP.ACCOUNT_OBJ_ID0
INTO #1
FROM   [BRM_ODS].[dbo].PRODUCT_T AS P WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].PURCHASED_PRODUCT_T AS PP WITH (NOLOCK)  ON PP.PRODUCT_OBJ_ID0 = P.POID_ID0
--INNER JOIN #ADJUSTMENTS_INFO AD ON AD.ACCOUNT_OBJ_ID0 = PP.ACCOUNT_OBJ_ID0
WHERE  PP.STATUS = 1
AND P.NAME IN ('Cloud Racker Discount Counter', 'Cloud Internal Discount Counter')
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('7 Complete (#1 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#2') IS NOT NULL
DROP TABLE #2
SELECT PAED.VALUE,A.ACCOUNT_NO
INTO #2
FROM   BRM_ODS.DBO.PROFILE_ACCT_EXTRATING_DATA_T AS PAED WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].PROFILE_T AS P WITH (NOLOCK) ON PAED.OBJ_ID0 = P.POID_ID0
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS A WITH (NOLOCK) ON P.ACCOUNT_OBJ_ID0 = A.POID_ID0
WHERE  PAED.NAME = 'SERVICE_TYPE'
AND P.NAME = 'MANAGED_FLAG'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('8 Complete (#2 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#3') IS NOT NULL
DROP TABLE #3
SELECT PAED.VALUE,A.ACCOUNT_NO
INTO #3
FROM   BRM_ODS.DBO.PROFILE_ACCT_EXTRATING_DATA_T AS PAED WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].PROFILE_T AS P WITH (NOLOCK) ON PAED.OBJ_ID0 = P.POID_ID0
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS A WITH (NOLOCK) ON P.ACCOUNT_OBJ_ID0 = A.POID_ID0
WHERE  PAED.NAME = 'MANAGED'
AND P.NAME = 'MANAGED_FLAG'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('9 Complete (#3 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************



----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BRM_INFO') IS NOT NULL
DROP TABLE #BRM_INFO
SELECT DISTINCT AD.ACCOUNT_NO,
                AD.CUSTOMER_NAME,
                AD.ADJUSTMENT_NO,
                AD.ADJUSTMENT_DATE,
                AD.CREATED_TIME,
                AD.ADJUSTMENT_AMOUNT,
                AD.TRANSACTION_CURRENCY_CODE,
                AD.INVOICE_APPLIED_TO,
                AD.INVOICE_DATE,
                AD.BRM_REASON_CODE,
                AD.COMMENTS,
                AD.[USER_NAME],
                AD.[ADDRESS],
                AD.[CITY],
                AD.COUNTY,
                AD.[STATE],
                AD.ZIP,
                AD.CANON_COUNTRY,
                AD.COUNTRY,
                AD.GL_STRING,
                CASE P.INVOICE_CONSOLIDATION_FLAG
				WHEN 0 THEN 'N' 
				WHEN 1 THEN 'Y' 
				END AS CONSOLDATED_ACCOUNT,
                CASE P.INVOICE_CONSOLIDATION_FLAG 
				WHEN 1 THEN P.INVOICE_CONSOLIDATION_ACCOUNT ELSE '' 
				END AS CONS_CORE_NO,
                CASE CONTRACTING_ENTITY 
				WHEN 100 THEN 'US' 
				WHEN 600 THEN 'SWISS' ELSE 'UNKNOWN' 
				END AS CONTRACTING_ENTITY,
                CASE PP.NAME --(SELECT AAA.NAME FROM #1 PQ) 
				WHEN 'Cloud Racker Discount Counter' THEN 'RACKER' 
				WHEN 'Cloud Internal Discount Counter' THEN 'INTERNAL' 
				ELSE '' 
				END AS RACKER_INTERNAL,
                CASE QW.VALUE--(SELECT QW.VALUE FROM #2 QW WHERE QW.ACCOUNT_NO = AT.ACCOUNT_NO) 
				WHEN 'SYSOPS' THEN 'SYSOPS' 
				WHEN 'DEVOPS' THEN 'DEVOPS' ELSE 'LEGACY' 
				END AS SERVICE_TYPE,
				CASE QA.VALUE--(SELECT QA.VALUE FROM #3 QA WHERE QA.ACCOUNT_NO = AT.ACCOUNT_NO) 
				WHEN 'FALSE' THEN 'UNMANAGED' 
				WHEN 'TRUE' THEN 'MANAGED' 
				WHEN 'INFRA' THEN 'MANAGED INFRA' 
				WHEN 'MANAGED' THEN 'MANAGED OPS' 
				END AS SERVICE_LEVEL
				,CASE WHEN BI.SCENARIO_OBJ_ID0 != 0 THEN ((SELECT top(1) PROFILE_NAME FROM [BRM_ODS].[dbo].CONFIG_COLLECTIONS_PROFILE_T CCP
					JOIN [BRM_ODS].[dbo].CONFIG_COLLECTIONS_SCENARIO_T CCS with (nolock) ON CCP.OBJ_ID0 = CCS.PROFILE_OBJ_ID0
					JOIN [BRM_ODS].[dbo].COLLECTIONS_SCENARIO_T CS with (nolock) ON CCS.OBJ_ID0 = CS.CONFIG_SCENARIO_OBJ_ID0
					JOIN [BRM_ODS].[dbo].BILLINFO_T BI with (nolock) ON CS.POID_ID0 = BI.SCENARIO_OBJ_ID0
					JOIN [BRM_ODS].[dbo].ACCOUNT_T A with (nolock) ON BI.ACCOUNT_OBJ_ID0 = A.POID_ID0
					WHERE A.ACCOUNT_NO = AT.ACCOUNT_NO))
										 WHEN BI.SCENARIO_OBJ_ID0 = 0 THEN ((SELECT TOP (1) COLLECTIONS_PROFILE FROM
								 [BRM_ODS].[dbo].CFG_RAX_ACCT_COLL_PROF_MAP_T ACPM, [BRM_ODS].[dbo].CONFIG_PROFILE_CUST_TYPE_T CPCT
								,[BRM_ODS].[dbo].PROFILE_CUSTOMER_CARE_T PCC, [BRM_ODS].[dbo].PROFILE_T P, [BRM_ODS].[dbo].ACCOUNT_T A
					WHERE A.POID_ID0 = P.ACCOUNT_OBJ_ID0
					AND P.POID_ID0 = PCC.OBJ_ID0
					AND PCC.CUSTOMER_TYPE = CPCT.CUSTOMER_TYPE
					AND CPCT.CUSTOMER_TYPE = ACPM.ACCT_COLLECTIONS_PROFILE
					AND A.CURRENCY = ACPM.CURRENCY
					AND A.ACCOUNT_NO = AT.ACCOUNT_NO)) END COLLECTIONS_PROFILE

INTO   #BRM_INFO
FROM  [BRM_ODS].[dbo].ACCOUNT_T AS AT WITH (NOLOCK)
LEFT JOIN #2 QW ON QW.ACCOUNT_NO = AT.ACCOUNT_NO
LEFT JOIN #3 QA ON QA.ACCOUNT_NO = AT.ACCOUNT_NO
INNER JOIN [BRM_ODS].[dbo].PROFILE_T AS PT WITH (NOLOCK) ON AT.POID_ID0 = PT.ACCOUNT_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].PROFILE_RACKSPACE_T AS P WITH (NOLOCK) ON P.OBJ_ID0 = PT.POID_ID0
INNER JOIN [BRM_ODS].[dbo].BILLINFO_T BI ON BI.ACCOUNT_OBJ_ID0 = AT.POID_ID0
INNER JOIN #ADJUSTMENTS_INFO AS AD ON AD.ACCOUNT_NO = AT.ACCOUNT_NO
LEFT JOIN #1 PP ON AD.ACCOUNT_OBJ_ID0 = PP.ACCOUNT_OBJ_ID0
WHERE  AT.ACCOUNT_NO LIKE '020-%';
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('10 Complete (#BRM_INFO is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************

--Select TOP 100 * FROM  #BRM_INFO
----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BRM_HMDB') IS NOT NULL
DROP TABLE #BRM_HMDB
SELECT ACCOUNT_NO AS CUSTOMER_NO,
       REPLACE(BRM_ACCOUNT.CUSTOMER_NAME, ',', '') AS CUSTOMER_NAME,
       CONS_CORE_NO,
       CASE 
WHEN BRM_ACCOUNT.ADJUSTMENT_AMOUNT > 0 THEN 'DEBIT' ELSE 'CREDIT' 
END AS ADJUSTMENT_TYPE,
       BRM_ACCOUNT.ADJUSTMENT_DATE,
       BRM_ACCOUNT.CREATED_TIME,
       ADJUSTMENT_NO,
       CASE 
WHEN BRM_ACCOUNT.ADJUSTMENT_AMOUNT < 0 THEN -ADJUSTMENT_AMOUNT ELSE ADJUSTMENT_AMOUNT 
END AS ADJUSTMENT_AMOUNT,
       BRM_ACCOUNT.TRANSACTION_CURRENCY_CODE,
       INVOICE_APPLIED_TO,
       INVOICE_DATE,
       BRM_ACCOUNT.BRM_REASON_CODE,
       BRM_ACCOUNT.COMMENTS,
       BRM_ACCOUNT.USER_NAME,
       REPLACE(BRM_ACCOUNT.ADDRESS, ',', '') AS ADDRESS,
       REPLACE(BRM_ACCOUNT.CITY, ',', '') AS CITY,
       REPLACE(BRM_ACCOUNT.COUNTY, ',', '') AS COUNTY,
       BRM_ACCOUNT.STATE,
       BRM_ACCOUNT.ZIP,
       REPLACE(BRM_ACCOUNT.CANON_COUNTRY, ',', '') AS CANON_COUNTRY,
       REPLACE(BRM_ACCOUNT.COUNTRY, ',', '') AS COUNTRY,
       GL_STRING,
       CONSOLDATED_ACCOUNT,
       CONTRACTING_ENTITY,
       RACKER_INTERNAL,
       SERVICE_TYPE,
       SERVICE_LEVEL,
       ACT_VAL_ACCOUNTSTATUSID AS STATUS_ID,
       CASE ACT_VAL_ACCOUNTSTATUSID 
	   WHEN 1 THEN 'NEW' 
	   WHEN 3 THEN 'ACTIVE' 
	   WHEN 4 THEN 'APPROVAL DENIED' 
	   WHEN 5 THEN 'DELINQUENT' 
	   WHEN 6 THEN 'SUSPENDED' 
	   WHEN 7 THEN 'AUP VIOLATION' 
	   WHEN 8 THEN 'CLOSED' 
	   WHEN 10 THEN 'PENDING MIGRATION' 
	   WHEN 2 THEN 'PENDING APPROVAL' 
	   WHEN 14 THEN 'TESTSTATUS' 
	   WHEN 9 THEN 'UNVERIFIED' 
	   END AS [STATUS],
	   COLLECTIONS_PROFILE
INTO   #BRM_HMDB
FROM   #BRM_INFO AS BRM_ACCOUNT
       LEFT OUTER JOIN
       [ODS_HMDB_US].[DBO].ACT_ACCOUNT AS HMDB_ACCOUNT
       ON REPLACE(REPLACE(ACCOUNT_NO, '020-', ''), '021-', '') = CONVERT (VARCHAR, ID);
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('11 Complete (#BRM_HMDB is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
CREATE INDEX [TEMP__IX__BRM_HMDB] ON #BRM_HMDB (CUSTOMER_NO);
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('11a Complete (INDEX [TEMP__IX__BRM_HMDB] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#SQ') IS NOT NULL
DROP TABLE #SQ
SELECT A1.Account_id,t1.name 
INTO #SQ
FROM SS_DB_ODS.dbo.account_all A1
inner JOIN SS_DB_ODS.dbo.teams_accounts_all ta1 with (nolock) on a1.account_id=ta1.account_id
INNER JOIN SS_DB_ODS.dbo.team_all T1 with (nolock) on t1.team_id=ta1.team_id AND t1.parent_team_id is not null
where rel_type='support'
AND ta1.deleted_at='1970-01-01 00:00:01.000'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('12a Complete (#SQ is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************

----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#AM') IS NOT NULL
DROP TABLE #AM
SELECT UR.account_id,Ua.name
INTO #AM
FROM [SS_DB_ODS].dbo.accounts_users_roles_all UR
INNER JOIN [SS_DB_ODS].[dbo].[role_all] R with (nolock) on UR.role_id=R.role_id
INNER JOIN [SS_DB_ODS].dbo.user_all ua with (nolock) on ua.[user_id]=UR.[user_id]
WHERE R.name='Account Manager' AND ur.deleted_at='1970-01-01 00:00:01.000'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('12b Complete (#AM is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************


----------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#SSL') IS NOT NULL
DROP TABLE #SSL
SELECT DISTINCT
              A.number AS NUMBER
              ,A1.number AS HYBRID_ACCOUNT_NO
              ,t.segment AS GROUP_NAME
              ,t.business_unit AS SEGMENT
              ,T.TEAM_ID TEAM
              ,T.name AS TEAM_NAME
              ,AM.name AS ACCOUNT_MANAGER
              ,t.subregion AS SUBREGION
              ,t.region  AS REGION
INTO #SSL
FROM SS_DB_ODS.dbo.account_all A with (nolock)
inner JOIN SS_DB_ODS.dbo.teams_accounts_all ta with (nolock)
on ISNULL(A.hybrid_acct_id,a.account_id)=ta.account_id  --- changed form a.ccount_id=ta.account_id
INNER JOIN SS_DB_ODS.dbo.team_all T with (nolock)
on t.team_id=ta.team_id
AND t.parent_team_id IS NULL
AND ta.deleted_at='1970-01-01 00:00:01.000'
LEFT JOIN SS_DB_ODS.dbo.account_all A1 with (nolock) ---Added logic for linked accounts 
on A1.account_id=A.hybrid_acct_id  
and A1.[TYPE]<>'CLOUD'
LEFT JOIN #SQ SQ on SQ.Account_id=ta.account_id
LEFT JOIN #AM AM ON AM.account_id=ISNULL(A1.account_id,ta.account_id)
where rel_type='revenue'
AND A.[Type] = 'CLOUD';

--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('12c Complete (#BRM_HMDB is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************

CREATE INDEX TEMP_INDEX_SSL ON #SSL(NUMBER);
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('12d Complete (INDEX [TEMP_INDEX_SSL] is created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************



INSERT INTO [KAOS].[dbo].[STG_DLY_ADJUSTMENT_DAILY_REPORT]
(
CUSTOMER_NO
,CUSTOMER_NAME
,CONS_CORE_NO
,HYBRID_ACCOUNT_NO
,STATUS_CODE 
,STATUS_DESCRIPTION
,ADJUSTMENT_TYPE
,ADJUSTMENT_NO
,BRM_REASON_CODE
,ADJUSTMENT_ENTERED_BY
,TRANSACTION_CURRENCY_CODE 
---,GL_DATE
,GL_STRING
,COMMENTS 
,ADJUSTMENT_DATE
,CREATED_TIME 
,ADJUSTMENT_AMOUNT
,TEAM_NAME
,CONSOLIDATED_INVOICE 
,ADDRESS
,CITY
,COUNTY 
,STATE
,POSTAL_CODE
,COUNTRY_CODE
,COUNTRY
,GROUP_NAME 
,SEGMENT
,REGION
,SUBREGION
,INTERNAL
,RACKER 
,SERVICE_LEVEL
,SERVICE_TYPE 
,CONTRACTING_ENTITY
,DW_TIMESTAMP
,COLLECTIONS_PROFILE
)

SELECT DISTINCT CUSTOMER_NO,ISNULL(REPLACE(CUSTOMER_NAME,',',''),'') CUSTOMER_NAME,ISNULL(CONS_CORE_NO,'') CONS_CORE_NO,ISNULL(HYBRID_ACCOUNT_NO,'') HYBRID_ACCOUNT_NO,ISNULL(CAST(STATUS_ID AS VARCHAR(MAX)),'') STATUS_CODE
,ISNULL(STATUS,'') STATUS_DESCRIPTION,ISNULL(ADJUSTMENT_TYPE,'') ADJUSTMENT_TYPE,ISNULL(ADJUSTMENT_NO,'') ADJUSTMENT_NO
,ISNULL(REPLACE(BRM_REASON_CODE,',',''),'') BRM_REASON_CODE,ISNULL(REPLACE(USER_NAME,',',''),'') ADJUSTMENT_ENTERED_BY,ISNULL(TRANSACTION_CURRENCY_CODE,'') TRANSACTION_CURRENCY_CODE
---,'' GL_DATE
,ISNULL(GL_STRING,'') GL_STRING
,ISNULL(REPLACE(COMMENTS,',',''),'') COMMENTS,ISNULL(CONVERT(VARCHAR(17),ADJUSTMENT_DATE,113),'') ADJUSTMENT_DATE,ISNULL(CONVERT(VARCHAR(17),CREATED_TIME,113),'') CREATED_TIME
,ISNULL(ROUND(ADJUSTMENT_AMOUNT,2),'') ADJUSTMENT_AMOUNT,ISNULL(REPLACE(TEAM_NAME,',',''),'') TEAM_NAME,ISNULL(CONSOLDATED_ACCOUNT,'') CONSOLIDATED_INVOICE
,ISNULL(REPLACE(ADDRESS,',',''),'') ADDRESS,ISNULL(CITY,'') CITY,ISNULL(COUNTY,'') COUNTY
,ISNULL(STATE,'') STATE,ISNULL(ZIP,'') POSTAL_CODE,ISNULL(CANON_COUNTRY,'') COUNTRY_CODE,ISNULL(COUNTRY,'') COUNTRY,ISNULL(REPLACE(GROUP_NAME,',',''),'') GROUP_NAME
,ISNULL(REPLACE(SEGMENT,',',''),'') SEGMENT,ISNULL(REPLACE(REGION,',',''),'') REGION,ISNULL(REPLACE(SUBREGION,',',''),'') SUBREGION
,CASE WHEN RACKER_INTERNAL='INTERNAL' THEN 'Y' ELSE 'N' END INTERNAL,CASE WHEN RACKER_INTERNAL='RACKER' THEN 'Y' ELSE 'N' END RACKER
,ISNULL(SERVICE_LEVEL,'') SERVICE_LEVEL,ISNULL(SERVICE_TYPE,'') SERVICE_TYPE
,ISNULL(CONTRACTING_ENTITY,'') CONTRACTING_ENTITY
,GETDATE() AS DW_TIMESTAMP
,ISNULL(COLLECTIONS_PROFILE,'') COLLECTIONS_PROFILE
FROM #BRM_HMDB 
LEFT OUTER JOIN #SSL ON REPLACE(REPLACE(CUSTOMER_NO,'020-',''),'021-','') =NUMBER 
AND  ADJUSTMENT_AMOUNT<>0;
--ORDER BY CUSTOMER_NO ASC;

--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('13 Complete (INSERT INTO [STG_DLY_ADJUSTMENT_DAILY_REPORT] is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------
-------------------

----Final count

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_ADJUSTMENT_DAILY_REPORT',@final_cnt_stg output

-----------load Audit tbale--------------------------

EXEC EBI_Logging.dbo.udsp_audit_tables 'STG_DLY_ADJUSTMENT_DAILY_REPORT', 
 'KAOS',  
 'udsp_DLY_ADJUSTMENT_DAILY_REPORT',
 @init_cnt_stg,
 @final_cnt_stg,
 @currentdate,
 1 ,
 1

END


GO
/****** Object:  StoredProcedure [dbo].[udsp_DLY_AGING_REPORT]    Script Date: 4/27/2016 12:53:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

---- =============================================
---- Author: Theodore
---- Create date: 09/12/2014
---- Description:  This stored proc will insert data INTO the STG_DLY_AGING_REPORT
---- Reviewed by DBAs : 09/15/2015

---- Modified by : Sree kandula
---- Modified date: 04/06/2016
---- Description:  Added an Alias "AI.PAYMENT_TERM" for the column "PAYMENT_TERM" in the Step 21.
---- Reviewed by DBAs : 04/06/2016
---- =============================================

CREATE PROCEDURE [dbo].[udsp_DLY_AGING_REPORT]
AS

BEGIN
SET NOCOUNT ON;
DECLARE  @Final_cnt_stg    bigint
DECLARE  @Init_cnt_stg     bigint
DECLARE @CurrentDate DATETIME
SET @CurrentDate = GETDATE()

-------------Initial count--------------------

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_AGING_REPORT',@Init_cnt_stg output

--------------Truncate table-----------------

--exec udsp_truncate_proxy 'KAOS.dbo.STG_DLY_AGING_REPORT';

TRUNCATE TABLE KAOS.dbo.STG_DLY_AGING_REPORT;

--------------------------------------------------------------------------------------------------------
--------------------

Declare @RunTime as varchar(8)
Declare @StartTime as datetime = getdate()

IF OBJECT_ID('TEMPDB..#Rotating_Query') IS NOT NULL
DROP TABLE #Rotating_Query
SELECT   ACCOUNT_T.POID_ID0 AS ACCOUNT_OBJ_ID0,
         ACCOUNT_NO,
         ACCOUNT_NAMEINFO_T.COMPANY AS NAME,
         CASE ACCOUNT_T.STATUS 
WHEN 10100 THEN 'ACTIVE' 
WHEN 10102 THEN 'INACTIVE' 
WHEN 10103 THEN 'DISCONNECTED' 
END AS ACCOUNT_STATUS,
         'CURRENT' AS AGEING,
        -- ISNULL(SUM(DUE), 0) AS SUM_DUE,
         CASE ACCOUNT_T.CURRENCY 
--WHEN 840 THEN 'USD' 
--WHEN 826 THEN 'GBP' 
--WHEN 978 THEN 'EUR' 
WHEN 36	 THEN 'AUD'
		WHEN 40	 THEN 'ATS'
		WHEN 56	 THEN 'BEF'
		WHEN 124 THEN 'CAD'
		WHEN 246 THEN 'FIM'
		WHEN 250 THEN 'FRF'
		WHEN 280 THEN 'DEM'
		WHEN 300 THEN 'GRD'
		WHEN 372 THEN 'IEP'
		WHEN 380 THEN 'ITL'
		WHEN 392 THEN 'JPY'
		WHEN 442 THEN 'LUF'
		WHEN 528 THEN 'NLG'
		WHEN 620 THEN 'PTE'
		WHEN 724 THEN 'ESP'
		WHEN 756 THEN 'CHF'
		WHEN 826 THEN 'GBP'
		WHEN 840 THEN 'USD'
		WHEN 978 THEN 'EUR'
		WHEN 999 THEN 'SDR'
END AS ACCOUNT_CURR,
         CONFIG_PAYMENT_TERM_T.PAYMENT_TERM_DESC AS PAYMENT_TERM,
         ACCOUNT_NAMEINFO_T.FIRST_NAME + ' ' + ACCOUNT_NAMEINFO_T.LAST_NAME AS BILLING_NAME,
         ACCOUNT_NAMEINFO_T.EMAIL_ADDR AS BILLING_EMAIL_ADDR,
         ACCOUNT_NAMEINFO_T.FIRST_NAME + ' ' + ACCOUNT_NAMEINFO_T.LAST_NAME AS PRIMARY_NAME,
         ACCOUNT_NAMEINFO_T.EMAIL_ADDR AS PRIMARY_EMAIL_ADDR,
         CASE PAYINFO_T.POID_TYPE 
WHEN '/payinfo/cc' THEN 'CREDIT CARD' 
WHEN '/payinfo/invoice' THEN 'LOCKBOX' 
WHEN '/payinfo/dd' THEN 'DEBIT CARD' ELSE 'UNKNOWN' 
END AS PAYMENT_METHOD,
         0 AS NEW_DELIQUENCY,
         CAST ([INTERNAL_NOTES_BUF] AS VARCHAR (MAX)) AS NOTES
INTO #Rotating_Query
FROM    -- [BRM_ODS].[dbo].ITEM_T WITH (NOLOCK)
       --  INNER JOIN
         [BRM_ODS].[dbo].ACCOUNT_T WITH (NOLOCK)
      --   ON ITEM_T.ACCOUNT_OBJ_ID0 = ACCOUNT_T.POID_ID0
           -- AND ACCOUNT_T.CURRENCY = ISNULL(840, ACCOUNT_T.CURRENCY)
         INNER JOIN
         [BRM_ODS].[dbo].BILLINFO_T WITH (NOLOCK)
         ON BILLINFO_T.ACCOUNT_OBJ_ID0 = ACCOUNT_T.POID_ID0
            AND BILLINFO_T.BILLING_SEGMENT = 2001
         LEFT OUTER JOIN
         [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T WITH (NOLOCK)
         ON ACCOUNT_NAMEINFO_T.OBJ_ID0 = ACCOUNT_T.POID_ID0
            AND ACCOUNT_NAMEINFO_T.CONTACT_TYPE = 'PRIMARY'
         INNER JOIN
         [BRM_ODS].[dbo].PAYINFO_T WITH (NOLOCK,forceseek)
         ON PAYINFO_T.account_obj_id0 = account_t.poid_id0
            AND BILLINFO_T.PAYINFO_OBJ_ID0 = PAYINFO_T.POID_ID0
         INNER JOIN
         [BRM_ODS].[dbo].PROFILE_T WITH (NOLOCK)
         ON PROFILE_T.poid_type = '/profile/rackspace'
            AND PROFILE_T.account_obj_id0 = ACCOUNT_T.POID_ID0
         INNER JOIN
         [BRM_ODS].[dbo].PROFILE_rackspace_T WITH (NOLOCK)
         ON profile_rackspace_t.obj_id0 = profile_t.poid_id0
         INNER JOIN
         [BRM_ODS].[dbo].CONFIG_PAYMENT_TERM_T WITH (NOLOCK)
         ON PAYINFO_T.PAYMENT_TERM = CONFIG_PAYMENT_TERM_T.REC_ID
         LEFT OUTER JOIN
         [BRM_ODS].[dbo].ACCOUNT_INTERNAL_NOTES_BUF WITH (NOLOCK)
         ON ACCOUNT_INTERNAL_NOTES_BUF.OBJ_ID0 = ACCOUNT_T.POID_ID0
WHERE  ACCOUNT_T.CURRENCY = ISNULL(ACCOUNT_T.CURRENCY, 840 )--  ROUND(ITEM_T.DUE, 2) <> 0
--SELECT * FROM #Rotating_Query
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('1 Complete (#Rotating_Query is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
        -- AND ITEM_T.BILL_OBJ_ID0 = 0
        -- AND ACCOUNT_T.ACCOUNT_NO = ISNULL(NULL, ACCOUNT_T.ACCOUNT_NO)
       --  AND ITEM_T.CREATED_T >= datediff(dd, '19700101', getdate()) * 86400
--GROUP BY (ACCOUNT_NO), CASE ACCOUNT_T.STATUS 
--WHEN 10100 THEN 'ACTIVE' 
--WHEN 10102 THEN 'INACTIVE' 
--WHEN 10103 THEN 'DISCONNECTED' 
--END, CASE ACCOUNT_T.CURRENCY 
--WHEN 840 THEN 'USD' 
--WHEN 826 THEN 'GBP' 
--WHEN 978 THEN 'EUR' 
--END, (COMPANY), CONFIG_PAYMENT_TERM_T.PAYMENT_TERM_DESC, ACCOUNT_T.POID_ID0, ACCOUNT_NAMEINFO_T.FIRST_NAME, ACCOUNT_NAMEINFO_T.LAST_NAME, ACCOUNT_NAMEINFO_T.EMAIL_ADDR, PAYINFO_T.POID_TYPE, CAST ([INTERNAL_NOTES_BUF] AS VARCHAR (MAX));


DECLARE @DUE_T BIGINT = datediff(dd,'19700101',getdate())*86400
DECLARE @DUE_T_30 BIGINT = datediff(dd,'19700101',getdate()-30)*86400
DECLARE @DUE_T_60 BIGINT = datediff(dd,'19700101',getdate()-60)*86400
DECLARE @DUE_T_90 BIGINT = datediff(dd,'19700101',getdate()-90)*86400
DECLARE @DUE_T_120 BIGINT = datediff(dd,'19700101',getdate()-120)*86400

--SELECT @DUE_T,  @DUE_T_30
IF OBJECT_ID('TEMPDB..#BILL_T__DUE') IS NOT NULL
DROP TABLE #BILL_T__DUE
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE
FROM [BRM_ODS].[dbo].BILL_T
WHERE BILL_T.DUE          <> 0 
AND BILL_T.DUE_T       >= @DUE_T ;
--SELECT * FROM #BILL_T__DUE

--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL( 'USD',ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES

--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('2 Complete (#BILL_T__DUE is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BILL_T__DUE_30_0') IS NOT NULL
DROP TABLE #BILL_T__DUE_30_0
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE_30_0
FROM [BRM_ODS].[dbo].BILL_T (NOLOCK)
WHERE BILL_T.DUE          <> 0 
AND BILL_T.DUE_T       >= @DUE_T_30
AND BILL_T.DUE_T       < @DUE_T ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('3 Complete (#BILL_T__DUE_30_0 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BILL_T__DUE_60_30') IS NOT NULL
DROP TABLE #BILL_T__DUE_60_30
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE_60_30
FROM [BRM_ODS].[dbo].BILL_T (NOLOCK)
WHERE BILL_T.DUE          <> 0 
AND BILL_T.DUE_T       >= @DUE_T_60
AND BILL_T.DUE_T       < @DUE_T_30 ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('4 Complete (#BILL_T__DUE_60_30 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BILL_T__DUE_90_60') IS NOT NULL
DROP TABLE #BILL_T__DUE_90_60
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE_90_60
FROM [BRM_ODS].[dbo].BILL_T (NOLOCK)
WHERE BILL_T.DUE          <> 0 
AND BILL_T.DUE_T       >= @DUE_T_90
AND BILL_T.DUE_T       < @DUE_T_60 ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('5 Complete (#BILL_T__DUE_90_60 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BILL_T__DUE_120_90') IS NOT NULL
DROP TABLE #BILL_T__DUE_120_90
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE_120_90
FROM [BRM_ODS].[dbo].BILL_T (NOLOCK)
WHERE BILL_T.DUE          <> 0 
AND BILL_T.DUE_T       >= @DUE_T_120
AND BILL_T.DUE_T       < @DUE_T_90 ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('6 Complete (#BILL_T__DUE_120_90 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BILL_T__DUE_120') IS NOT NULL
DROP TABLE #BILL_T__DUE_120
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #BILL_T__DUE_120
FROM [BRM_ODS].[dbo].BILL_T (NOLOCK)
WHERE BILL_T.DUE          <> 0 
--AND BILL_T.DUE_T       >= @DUE_T_120
AND BILL_T.DUE_T       < @DUE_T_120 ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('7 Complete (#BILL_T__DUE_120 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ITEM_T__DUE') IS NOT NULL
DROP TABLE #ITEM_T__DUE
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
--AND ITEM_T.DUE_T       >= @DUE_T_120
AND ITEM_T.CREATED_T       >=  @DUE_T;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('8 Complete (#ITEM_T__DUE is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#ITEM_T__DUE_30_0') IS NOT NULL
DROP TABLE #ITEM_T__DUE_30_0
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE_30_0
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
AND ITEM_T.CREATED_T       >= @DUE_T_30
AND ITEM_T.CREATED_T       <  @DUE_T;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('9 Complete (#ITEM_T__DUE_30_0 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ITEM_T__DUE_60_30') IS NOT NULL
DROP TABLE #ITEM_T__DUE_60_30
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE_60_30
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
AND ITEM_T.CREATED_T       >= @DUE_T_60
AND ITEM_T.CREATED_T       <  @DUE_T_30;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('10 Complete (#ITEM_T__DUE_60_30 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ITEM_T__DUE_90_60') IS NOT NULL
DROP TABLE #ITEM_T__DUE_90_60
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE_90_60
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
AND ITEM_T.CREATED_T       >= @DUE_T_90
AND ITEM_T.CREATED_T       <  @DUE_T_60;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('11 Complete (#ITEM_T__DUE_90_60 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ITEM_T__DUE_120_90') IS NOT NULL
DROP TABLE #ITEM_T__DUE_120_90
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE_120_90
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
AND ITEM_T.CREATED_T       >= @DUE_T_120
AND ITEM_T.CREATED_T       <  @DUE_T_90;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('12 Complete (#ITEM_T__DUE_120_90 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#ITEM_T__DUE_120') IS NOT NULL
DROP TABLE #ITEM_T__DUE_120
SELECT ACCOUNT_OBJ_ID0, ISNULL(DUE,0) AS [DUE]
INTO #ITEM_T__DUE_120
FROM [BRM_ODS].[dbo].ITEM_T (NOLOCK)
WHERE ROUND(ITEM_T.DUE,2)         <> 0 AND ITEM_T.BILL_OBJ_ID0 = 0
--AND ITEM_T.CREATED_T       >= @DUE_T_120
AND ITEM_T.CREATED_T       <  @DUE_T_120;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('13 Complete (#ITEM_T__DUE_120 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************

--IF OBJECT_ID('TEMPDB..#BILL_T_ALL') IS NOT NULL
--DROP TABLE #BILL_T_ALL
--SELECT A.[SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES INTO #BILL_T_ALL FROM (
-------------------------------------------------------------------------------------------------------------------------
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL( ACCOUNT_CURR,'USD')
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE_30_0 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE_60_30 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE_90_60 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE_120_90 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #BILL_T__DUE_120 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
-------------------------------------------------------------------------------------------------------------------------
--) A
----*********************************************************************************************************************
--set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('13 Complete (#BILL_T_ALL is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
----*********************************************************************************************************************
-------------------------------------------------------------------------------------------------------------------------
--IF OBJECT_ID('TEMPDB..#ITEM_T_ALL') IS NOT NULL
--DROP TABLE #ITEM_T_ALL
--SELECT B.[SUM_DUE],B.ACCOUNT_OBJ_ID0,B.ACCOUNT_NO	,B.NAME	,B.ACCOUNT_STATUS	,B.AGEING	,B.ACCOUNT_CURR	,B.PAYMENT_TERM	,B.BILLING_NAME	,B.BILLING_EMAIL_ADDR	,B.PRIMARY_NAME	,B.PRIMARY_EMAIL_ADDR	,B.PAYMENT_METHOD	,B.NEW_DELIQUENCY	,B.NOTES INTO #ITEM_T_ALL FROM (
-------------------------------------------------------------------------------------------------------------------------
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE_30_0 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE_60_30 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE_90_60 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE_120_90 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--UNION ALL
--SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES
--FROM #Rotating_Query A
--INNER JOIN #ITEM_T__DUE_120 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
--GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES

-------------------------------------------------------------------------------------------------------------------------
--) B
----*********************************************************************************************************************
--set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('14 Complete (#ITEM_T_ALL is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
----*********************************************************************************************************************

IF OBJECT_ID('TEMPDB..#Event') IS NOT NULL
DROP TABLE #Event

SELECT E.POID_ID0,E.ACCOUNT_OBJ_ID0,E.SESSION_OBJ_ID0,E.SERVICE_OBJ_TYPE,E.CREATED_T,EBP.OBJ_ID0,EBP.TRANS_ID
INTO #Event
FROM [BRM_ODS].[dbo].EVENT_T E  (NOLOCK)
JOIN [BRM_ODS].[dbo].EVENT_BILLING_PAYMENT_T EBP  WITH (NOLOCK) ON E.POID_ID0=EBP.OBJ_ID0
WHERE 
E.SERVICE_OBJ_TYPE IS NULL 
and E.POID_TYPE like '/event/billing/payment%'

create index temp_event_dailyagaing on #event(POID_ID0,CREATED_T)
create index temp_event_dailyagaing_account on #event(ACCOUNT_OBJ_ID0)
create index temp_event_dailyagaing_session on #event(SESSION_OBJ_ID0)
create index temp_event_dailyagaing_tran on #event(TRANS_ID)

set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('14 Complete (#Event is Loaded):  %s',10,1,@RunTime) WITH NOWAIT

IF OBJECT_ID('Tempdb..#BRM_HMDB') IS NOT NULL
DROP TABLE #BRM_HMDB
IF OBJECT_ID('TEMPDB..#AGEING_INFO') IS NOT NULL
	DROP TABLE #AGEING_INFO
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
--SELECT AB.[SUM_DUE],AB.ACCOUNT_OBJ_ID0,AB.ACCOUNT_NO	,AB.NAME	,AB.ACCOUNT_STATUS	,AB.AGEING	,AB.ACCOUNT_CURR	,AB.PAYMENT_TERM	,AB.BILLING_NAME	,AB.BILLING_EMAIL_ADDR	,AB.PRIMARY_NAME	,AB.PRIMARY_EMAIL_ADDR	,AB.PAYMENT_METHOD	,AB.NEW_DELIQUENCY	,AB.NOTES INTO #AB FROM 
--(
;WITH AGEING_1 AS (
--SELECT A.[SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES FROM #BILL_T_ALL A
--UNION ALL
--SELECT B.[SUM_DUE],B.ACCOUNT_OBJ_ID0,B.ACCOUNT_NO	,B.NAME	,B.ACCOUNT_STATUS	,B.AGEING	,B.ACCOUNT_CURR	,B.PAYMENT_TERM	,B.BILLING_NAME	,B.BILLING_EMAIL_ADDR	,B.PRIMARY_NAME	,B.PRIMARY_EMAIL_ADDR	,B.PAYMENT_METHOD	,B.NEW_DELIQUENCY	,B.NOTES FROM #ITEM_T_ALL B
--SELECT A.[SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.AGEING	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES INTO #BILL_T_ALL FROM (
-----------------------------------------------------------------------------------------------------------------------
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'CURRENT'  AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL( ACCOUNT_CURR,'USD')
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'1-30' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE_30_0 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'31-60'       AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE_60_30 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'61-90' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE_90_60 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'91-120' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE_120_90 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'121+' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #BILL_T__DUE_120 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
-------------------------------------------------------------------------------------------------------------------------
--) A
UNION ALL 
----*********************************************************************************************************************
--set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
--RAISERROR ('13 Complete (#BILL_T_ALL is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
----*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
--IF OBJECT_ID('TEMPDB..#ITEM_T_ALL') IS NOT NULL
--DROP TABLE #ITEM_T_ALL
--SELECT B.[SUM_DUE],B.ACCOUNT_OBJ_ID0,B.ACCOUNT_NO	,B.NAME	,B.ACCOUNT_STATUS	,B.AGEING	,B.ACCOUNT_CURR	,B.PAYMENT_TERM	,B.BILLING_NAME	,B.BILLING_EMAIL_ADDR	,B.PRIMARY_NAME	,B.PRIMARY_EMAIL_ADDR	,B.PAYMENT_METHOD	,B.NEW_DELIQUENCY	,B.NOTES INTO #ITEM_T_ALL FROM (
-------------------------------------------------------------------------------------------------------------------------
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'CURRENT'  AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'1-30' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE_30_0 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'31-60'       AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE_60_30 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'61-90' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE_90_60 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'91-120' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE_120_90 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]
UNION ALL 
SELECT SUM(B.[DUE]) AS [SUM_DUE],A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,'121+' AS [AGEING]
FROM #Rotating_Query A
INNER JOIN #ITEM_T__DUE_120 B  ON A.ACCOUNT_OBJ_ID0 = B.ACCOUNT_OBJ_ID0
--AND ACCOUNT_CURR = ISNULL('USD', ACCOUNT_CURR)
GROUP BY A.ACCOUNT_OBJ_ID0,A.ACCOUNT_NO	,A.NAME	,A.ACCOUNT_STATUS	,A.ACCOUNT_CURR	,A.PAYMENT_TERM	,A.BILLING_NAME	,A.BILLING_EMAIL_ADDR	,A.PRIMARY_NAME	,A.PRIMARY_EMAIL_ADDR	,A.PAYMENT_METHOD	,A.NEW_DELIQUENCY	,A.NOTES,[AGEING]

-------------------------------------------------------------------------------------------------------------------------
--) B
) --AB

--SELECT * FROM #AB
,AGEING_2 AS (
    SELECT ACCOUNT_OBJ_ID0,AGEING_1.ACCOUNT_NO,AGEING_1.ACCOUNT_STATUS,NAME,REPLACE(BILLING_NAME,',','') BILLING_NAME,BILLING_EMAIL_ADDR,REPLACE(PRIMARY_NAME,',','') PRIMARY_NAME,PRIMARY_EMAIL_ADDR,REPLACE(NOTES,',','') NOTES,PAYMENT_TERM,
    AGEING_1.ACCOUNT_CURR,
    AGEING_1.PAYMENT_METHOD,MAX(NEW_DELIQUENCY) NEW_DELIQUENCY,
    CASE AGEING_1.AGEING
      WHEN 'CURRENT' THEN SUM_DUE
      ELSE 0
    END AS A_CURRENT,
    CASE AGEING_1.AGEING
      WHEN '1-30' THEN SUM_DUE
     ELSE 0
    END AS A_1_30,
    CASE AGEING_1.AGEING
      WHEN '31-60' THEN SUM_DUE
      ELSE 0
    END AS A_31_60,
    CASE AGEING_1.AGEING
      WHEN '61-90' THEN SUM_DUE
      ELSE 0
    END AS A_61_90,
    CASE AGEING_1.AGEING
      WHEN '91-120' THEN SUM_DUE
      ELSE 0
    END AS A_91_120,
    CASE AGEING_1.AGEING
      WHEN '121+' THEN SUM_DUE
      ELSE 0
    END AS A_121_PLUS 
    FROM AGEING_1
    GROUP BY ACCOUNT_OBJ_ID0,ACCOUNT_NO,ACCOUNT_STATUS,NAME,BILLING_NAME,BILLING_EMAIL_ADDR,PRIMARY_NAME,PRIMARY_EMAIL_ADDR,NOTES,PAYMENT_TERM,
    ACCOUNT_CURR,PAYMENT_METHOD,CASE AGEING
      WHEN 'CURRENT'
      THEN SUM_DUE
      ELSE 0
    END,
    CASE AGEING
      WHEN '1-30'
      THEN SUM_DUE
      ELSE 0
    END,
    CASE AGEING
      WHEN '31-60'      
      THEN SUM_DUE
      ELSE 0
    END,
    CASE AGEING
      WHEN '61-90'
      THEN SUM_DUE
      ELSE 0
    END,
    CASE AGEING
      WHEN '91-120'
      THEN SUM_DUE
      ELSE 0
    END,
CASE AGEING
      WHEN '121+'
      THEN SUM_DUE
      ELSE 0
    END
),
AGEING_INFO  AS (
   SELECT ACCOUNT_OBJ_ID0,ACCOUNT_NO,ACCOUNT_STATUS,ACCOUNT_CURR,NAME,PAYMENT_METHOD,PAYMENT_TERM,BILLING_NAME,BILLING_EMAIL_ADDR,PRIMARY_NAME,PRIMARY_EMAIL_ADDR,NOTES,
  MAX(NEW_DELIQUENCY) NEW_DELIQUENCY,
  ACCOUNT_CURR AS Currency,
(SUM(A_CURRENT)+SUM(A_1_30)+SUM(A_31_60)+SUM(A_61_90)+SUM(A_91_120)+SUM(A_121_PLUS)) AS Total,
  SUM(A_CURRENT) CURRENT_0,
  SUM(A_1_30) BALANCE_1_30,
  SUM(A_31_60) BALANCE_31_60,
  SUM(A_61_90) BALANCE_61_90,
  SUM(A_91_120) BALANCE_91_120,
  SUM(A_121_PLUS) BALANCE_121_PLUS
FROM AGEING_2
GROUP BY ACCOUNT_OBJ_ID0,ACCOUNT_NO,ACCOUNT_STATUS,ACCOUNT_CURR,PAYMENT_METHOD,NAME,PAYMENT_TERM,BILLING_NAME,BILLING_EMAIL_ADDR,NOTES,PRIMARY_NAME,PRIMARY_EMAIL_ADDR
)
--,BRM_INFO AS (

select * into #AGEING_INFO from AGEING_INFO
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('15 Complete (#AGEING_INFO is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------
IF OBJECT_ID('TEMPDB..#BRM_INFO_Last_payment_dt') IS NOT NULL
	DROP TABLE #BRM_INFO_Last_payment_dt

select	 E.ACCOUNT_OBJ_ID0, DATEADD(SECOND,-1,DATEADD(SS, max(E.CREATED_T) , '1970-01-01')) LAST_PAYMENT_DATE into #BRM_INFO_Last_payment_dt
FROM    BRM_ODS.DBO.ACCOUNT_T A  WITH (NOLOCK)
	JOIN #Event E ON E.ACCOUNT_OBJ_ID0=A.POID_ID0 
	JOIN BRM_ODS.DBO.EVENT_BILLING_PAYMENT_CC_T EBPC  WITH (NOLOCK) ON EBPC.OBJ_ID0=E.POID_ID0    
	LEFT OUTER JOIN BRM_ODS.DBO.EVENT_PAYMENT_BATCH_T  EBPB  WITH (NOLOCK) ON E.SESSION_OBJ_ID0=EBPB.OBJ_ID0    
	JOIN BRM_ODS.DBO.BILLINFO_T B  WITH (NOLOCK) ON B.ACCOUNT_OBJ_ID0=A.POID_ID0    
	JOIN BRM_ODS.DBO.PAYINFO_T P  WITH (NOLOCK) ON P.POID_ID0=B.PAYINFO_OBJ_ID0    
	JOIN BRM_ODS.DBO.PAYINFO_CC_T PC  WITH (NOLOCK) ON PC.OBJ_ID0=P.POID_ID0    
	LEFT OUTER JOIN BRM_ODS.DBO.ACCOUNT_NAMEINFO_T AN  WITH (NOLOCK) ON AN.OBJ_ID0=A.POID_ID0 AND AN.CONTACT_TYPE='CONTACT'    
	LEFT JOIN BRM_ODS.DBO.RAX_PYMT_DETAILS_T RPD  WITH (NOLOCK) ON RPD.TRANS_ID=E.TRANS_ID    
	LEFT OUTER JOIN BRM_ODS.DBO.BILL_T BL  WITH (NOLOCK) ON BL.POID_ID0=B.LAST_BILL_OBJ_ID0    
	inner join #AGEING_INFO AI on AI.ACCOUNT_NO=A.ACCOUNT_NO
	WHERE     RPD.STATUS = 0 
	group by E.ACCOUNT_OBJ_ID0   
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('16 Complete (#BRM_INFO_Last_payment_dt is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#CFG_RAX_ACCT_COLL_PROF_MAP_T') IS NOT NULL
DROP TABLE #CFG_RAX_ACCT_COLL_PROF_MAP_T
SELECT ACPM.CURRENCY, ACPM.COLLECTIONS_PROFILE
INTO #CFG_RAX_ACCT_COLL_PROF_MAP_T
FROM [BRM_ODS].[dbo].CFG_RAX_ACCT_COLL_PROF_MAP_T AS ACPM
INNER JOIN [BRM_ODS].[dbo].CONFIG_PROFILE_CUST_TYPE_T AS CPCT WITH (NOLOCK)  ON CPCT.CUSTOMER_TYPE = ACPM.ACCT_COLLECTIONS_PROFILE 
INNER JOIN [BRM_ODS].[dbo].PROFILE_CUSTOMER_CARE_T AS PCC WITH (NOLOCK) ON  CPCT.CUSTOMER_TYPE = PCC.[CUSTOMER_TYPE]
GROUP BY ACPM.CURRENCY, ACPM.COLLECTIONS_PROFILE
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('17 Complete (#CFG_RAX_ACCT_COLL_PROF_MAP_T is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#SCENARIO_OBJ_ID0_Equal0') IS NOT NULL
DROP TABLE #SCENARIO_OBJ_ID0_Equal0
SELECT ACPM.COLLECTIONS_PROFILE,A.ACCOUNT_NO
INTO #SCENARIO_OBJ_ID0_Equal0
FROM   [BRM_ODS].[dbo].ACCOUNT_T AS A WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].PROFILE_T AS P WITH (NOLOCK) ON A.POID_ID0 = P.ACCOUNT_OBJ_ID0
INNER JOIN #CFG_RAX_ACCT_COLL_PROF_MAP_T AS ACPM WITH (NOLOCK) ON A.CURRENCY = ACPM.CURRENCY
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('18 Complete (#SCENARIO_OBJ_ID0_Equal0 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------
CREATE INDEX [IX__ACCOUNT_NO__#SCENARIO_OBJ_ID0_Equal0] ON #SCENARIO_OBJ_ID0_Equal0 ( ACCOUNT_NO )
--SELECT TOP(1) COLLECTIONS_PROFILE FROM  #SCENARIO_OBJ_ID0_Equal0 -- 7991680
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('18a Complete ([IX__ACCOUNT_NO__#SCENARIO_OBJ_ID0_Equal0] is created):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#SCENARIO_OBJ_ID0_NOTEqual0') IS NOT NULL
DROP TABLE #SCENARIO_OBJ_ID0_NOTEqual0
SELECT CCP.PROFILE_NAME,A.ACCOUNT_NO
INTO #SCENARIO_OBJ_ID0_NOTEqual0
FROM   [BRM_ODS].[dbo].CONFIG_COLLECTIONS_PROFILE_T AS CCP WITH (NOLOCK) 
INNER JOIN [BRM_ODS].[dbo].CONFIG_COLLECTIONS_SCENARIO_T AS CCS WITH (NOLOCK) ON CCP.OBJ_ID0 = CCS.PROFILE_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].COLLECTIONS_SCENARIO_T AS CS WITH (NOLOCK) ON CCS.OBJ_ID0 = CS.CONFIG_SCENARIO_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].BILLINFO_T AS BI WITH (NOLOCK) ON CS.POID_ID0 = BI.SCENARIO_OBJ_ID0 
INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS A WITH (NOLOCK) ON BI.ACCOUNT_OBJ_ID0 = A.POID_ID0
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('19 Complete #SCENARIO_OBJ_ID0_NOTEqual0 is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------
CREATE INDEX [IX__ACCOUNT_NO__#SCENARIO_OBJ_ID0_NOTEqual0] ON #SCENARIO_OBJ_ID0_NOTEqual0 ( ACCOUNT_NO )
--SELECT TOP(1) PROFILE_NAME FROM #SCENARIO_OBJ_ID0_NOTEqual0 -- 1763
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('19a Complete ([IX__ACCOUNT_NO__#SCENARIO_OBJ_ID0_NOTEqual0] is created):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#COLLECTOR_NAME') IS NOT NULL
DROP TABLE #COLLECTOR_NAME
SELECT DISTINCT AN.FIRST_NAME + ' ' + AN.LAST_NAME AS [COLLECTOR_NAME],P.ACCOUNT_OBJ_ID0
INTO #COLLECTOR_NAME
FROM   [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AS AN
INNER JOIN [BRM_ODS].[dbo].SERVICE_T AS S WITH (NOLOCK) ON AN.OBJ_ID0 = S.ACCOUNT_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].PROFILE_RACKSPACE_T AS PRS WITH (NOLOCK) ON S.LOGIN = PRS.COLLECTION_AGENT
INNER JOIN [BRM_ODS].[dbo].PROFILE_T AS P WITH (NOLOCK) ON PRS.OBJ_ID0 = P.POID_ID0
--INNER JOIN [BRM_ODS].[dbo].ACCOUNT_T AS AT WITH (NOLOCK) ON P.ACCOUNT_OBJ_ID0 = AT.POID_ID0
WHERE  P.POID_TYPE = '/profile/rackspace'  
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('20 Complete (#COLLECTOR_NAME is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

CREATE INDEX [IX__ACCOUNT_OBJ_ID0__#COLLECTOR_NAME] ON #COLLECTOR_NAME (ACCOUNT_OBJ_ID0)
--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('20a Complete ([IX__ACCOUNT_OBJ_ID0__#COLLECTOR_NAME] is created):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------


IF OBJECT_ID('TEMPDB..#BRM_INFO') IS NOT NULL
	DROP TABLE #BRM_INFO
SELECT DISTINCT  AT.ACCOUNT_NO,ACCOUNT_STATUS,ACCOUNT_CURR,AI.NAME,AI.PAYMENT_METHOD,AI.PAYMENT_TERM
,(SELECT FIRST_NAME+' '+LAST_NAME FROM [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AN with (nolock) WHERE AN.OBJ_ID0=AT.POID_ID0 AND AN.CONTACT_TYPE='CONTACT') BILLING_NAME
,(SELECT EMAIL_ADDR FROM [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AN with (nolock) WHERE AN.OBJ_ID0=AT.POID_ID0 AND AN.CONTACT_TYPE='CONTACT')BILLING_EMAIL_ADDR
,PRIMARY_NAME,PRIMARY_EMAIL_ADDR,NOTES,
  AI.CURRENCY TRANSACTION_CURRENCY_CODE,TOTAL, CURRENT_0,NEW_DELIQUENCY, 
CASE 
WHEN B.SCENARIO_OBJ_ID0 != 0  THEN (SELECT TOP(1) PROFILE_NAME FROM #SCENARIO_OBJ_ID0_NOTEqual0  where ACCOUNT_NO=AT.ACCOUNT_NO)
WHEN B.SCENARIO_OBJ_ID0 = 0 THEN (SELECT TOP(1) COLLECTIONS_PROFILE FROM  #SCENARIO_OBJ_ID0_Equal0  where ACCOUNT_NO=AT.ACCOUNT_NO)
END AS COLLECTIONS_PROFILE,[COLLECTOR_NAME] = (SELECT [COLLECTOR_NAME] FROM #COLLECTOR_NAME WHERE ACCOUNT_OBJ_ID0 = AT.POID_ID0),
(select top 1 LAST_PAYMENT_DATE from #BRM_INFO_Last_payment_dt E where E.ACCOUNT_OBJ_ID0=AT.POID_ID0) AS LAST_PAYMENT_DATE
--(SELECT TOP(1) DATEADD(SECOND,-1,DATEADD(SS, E.CREATED_T , '1970-01-01')) FROM    
--BRM_ODS.DBO.ACCOUNT_T A  WITH (NOLOCK)
--JOIN #Event E ON E.ACCOUNT_OBJ_ID0=A.POID_ID0 
--JOIN BRM_ODS.DBO.EVENT_BILLING_PAYMENT_CC_T EBPC  WITH (NOLOCK) ON EBPC.OBJ_ID0=E.POID_ID0    
--LEFT OUTER JOIN BRM_ODS.DBO.EVENT_PAYMENT_BATCH_T  EBPB  WITH (NOLOCK) ON E.SESSION_OBJ_ID0=EBPB.OBJ_ID0    
--JOIN BRM_ODS.DBO.BILLINFO_T B  WITH (NOLOCK) ON B.ACCOUNT_OBJ_ID0=A.POID_ID0    
--JOIN BRM_ODS.DBO.PAYINFO_T P  WITH (NOLOCK) ON P.POID_ID0=B.PAYINFO_OBJ_ID0    
--JOIN BRM_ODS.DBO.PAYINFO_CC_T PC  WITH (NOLOCK) ON PC.OBJ_ID0=P.POID_ID0    
--LEFT OUTER JOIN BRM_ODS.DBO.ACCOUNT_NAMEINFO_T AN  WITH (NOLOCK) ON AN.OBJ_ID0=A.POID_ID0 AND AN.CONTACT_TYPE='CONTACT'    
--LEFT JOIN BRM_ODS.DBO.RAX_PYMT_DETAILS_T RPD  WITH (NOLOCK) ON RPD.TRANS_ID=E.TRANS_ID    
--LEFT OUTER JOIN BRM_ODS.DBO.BILL_T BL  WITH (NOLOCK) ON BL.POID_ID0=B.LAST_BILL_OBJ_ID0    
--WHERE     
-- RPD.STATUS = 0    
--AND E.ACCOUNT_OBJ_ID0=AT.POID_ID0 
--ORDER BY E.CREATED_T DESC)LAST_PAYMENT_DATE
  ,BALANCE_1_30,BALANCE_31_60,BALANCE_61_90,BALANCE_91_120,BALANCE_121_PLUS,
CASE INVOICE_CONSOLIDATION_FLAG
WHEN 0 THEN 'N'
WHEN 1 THEN 'Y' END CONSOLDATED_ACCOUNT
,CASE INVOICE_CONSOLIDATION_FLAG
      WHEN 1 THEN INVOICE_CONSOLIDATION_ACCOUNT
      ELSE '' 
 END  CONS_CORE_NO
,CASE CONTRACTING_ENTITY WHEN 100 THEN 'US' WHEN 600 THEN 'SWISS' ELSE 'UNKNOWN' END CONTRACTING_ENTITY,ACTG_CYCLE_DOM BDOM,
CASE (SELECT P.NAME FROM [BRM_ODS].[dbo].PRODUCT_T P with (nolock) , [BRM_ODS].[dbo].PURCHASED_PRODUCT_T PP with (nolock)  WHERE 
AI.ACCOUNT_OBJ_ID0=PP.ACCOUNT_OBJ_ID0 AND PP.PRODUCT_OBJ_ID0=P.POID_ID0 AND PP.STATUS=1 AND P.NAME 
IN ('Cloud Racker Discount Counter','Cloud Internal Discount Counter'))
WHEN 'Cloud Racker Discount Counter' THEN 'RACKER'
WHEN 'Cloud Internal Discount Counter' THEN 'INTERNAL'
ELSE ''
END RACKER_INTERNAL,
CASE (SELECT PAED.VALUE FROM BRM_ODS.DBO.PROFILE_ACCT_EXTRATING_DATA_T PAED with (nolock),[BRM_ODS].[dbo].PROFILE_T P with (nolock) , [BRM_ODS].[dbo].ACCOUNT_T A with (nolock) WHERE PAED.OBJ_ID0=P.POID_ID0 AND PAED.NAME='SERVICE_TYPE' AND P.ACCOUNT_OBJ_ID0=A.POID_ID0
            AND A.ACCOUNT_NO=AT.ACCOUNT_NO AND P.NAME='MANAGED_FLAG') 
                  WHEN 'SYSOPS' THEN 'SYSOPS' WHEN 'DEVOPS' THEN 'DEVOPS' ELSE 'LEGACY' END SERVICE_TYPE,
  CASE (SELECT PAED.VALUE FROM BRM_ODS.DBO.PROFILE_ACCT_EXTRATING_DATA_T PAED with (nolock) ,[BRM_ODS].[dbo].PROFILE_T P with (nolock), [BRM_ODS].[dbo].ACCOUNT_T A with (nolock) WHERE PAED.OBJ_ID0=P.POID_ID0 AND PAED.NAME='MANAGED' AND P.ACCOUNT_OBJ_ID0=A.POID_ID0
            AND A.ACCOUNT_NO=AT.ACCOUNT_NO AND P.NAME='MANAGED_FLAG') 
                  WHEN 'FALSE' THEN 'UNMANAGED' WHEN 'TRUE' THEN 'MANAGED' WHEN 'INFRA' THEN 'MANAGED INFRA' WHEN 'MANAGED' THEN 'MANAGED OPS' END SERVICE_LEVEL  
into #BRM_INFO                
FROM [BRM_ODS].[dbo].ACCOUNT_T AT with (nolock)
INNER JOIN #AGEING_INFO AI ON AI.ACCOUNT_NO=AT.ACCOUNT_NO
INNER JOIN [BRM_ODS].[dbo].BILLINFO_T B with (nolock) ON AT.POID_ID0=B.ACCOUNT_OBJ_ID0
--INNER JOIN #COLLECTOR_NAME CN ON CN.ACCOUNT_NO=AT.ACCOUNT_NO
INNER JOIN [BRM_ODS].[dbo].PROFILE_T PT with (nolock)  ON  AT.POID_ID0=PT.ACCOUNT_OBJ_ID0
INNER JOIN [BRM_ODS].[dbo].PROFILE_RACKSPACE_T P with (nolock)  ON P.OBJ_ID0=PT.POID_ID0 


--------------------------------------------------------------------------------------------
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('21 Complete (#BRM_INFO is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--------------------------------------------------------------------------------------------

IF OBJECT_ID('TEMPDB..#BRM_HMDB') IS NOT NULL
	DROP TABLE #BRM_HMDB

SELECT 
ACCOUNT_NO,REPLACE(BRM_INFO.NAME,',','') NAME,TRANSACTION_CURRENCY_CODE,TOTAL BALANCE,CURRENT_0,BALANCE_1_30,BALANCE_31_60,BALANCE_61_90,BALANCE_91_120,BALANCE_121_PLUS,
NEW_DELIQUENCY,COLLECTIONS_PROFILE,COLLECTOR_NAME,LAST_PAYMENT_DATE,PAYMENT_METHOD, REPLACE(REPLACE(SUBSTRING(NOTES,1,CASE CHARINDEX(CHAR(10)+CHAR(13)+CHAR(10),SUBSTRING(NOTES,4,LEN(NOTES))) WHEN 0 THEN LEN(NOTES)-3 ELSE CHARINDEX(CHAR(10)+CHAR(13)+CHAR(10),SUBSTRING(NOTES,4,LEN(NOTES)))END), CHAR(13),' '), CHAR(10),' ') COMMENTS,PAYMENT_TERM,BILLING_NAME,BILLING_EMAIL_ADDR,PRIMARY_NAME,PRIMARY_EMAIL_ADDR,
CONSOLDATED_ACCOUNT,CONS_CORE_NO,CONTRACTING_ENTITY,RACKER_INTERNAL,BDOM,SERVICE_LEVEL,SERVICE_TYPE,
ACT_VAL_ACCOUNTSTATUSID STATUS_CODE,
CASE ACT_VAL_ACCOUNTSTATUSID
WHEN 1     THEN 'NEW'
WHEN 3     THEN 'ACTIVE'
WHEN 4     THEN 'APPROVAL DENIED'
WHEN 5     THEN 'DELINQUENT'
WHEN 6     THEN 'SUSPENDED'
WHEN 7     THEN 'AUP VIOLATION'
WHEN 8     THEN 'CLOSED'
WHEN 10    THEN 'PENDING MIGRATION'
WHEN 2     THEN 'PENDING APPROVAL'
WHEN 14    THEN 'TESTSTATUS'
WHEN 9     THEN 'UNVERIFIED' END STATUS_DESCRIPTION,HMDB_CONS_INFO.CREATED INVOICE_CONS_DATE into #BRM_HMDB
FROM #BRM_INFO BRM_INFO
LEFT OUTER JOIN [ODS_HMDB_US].[DBO].ACT_ACCOUNT HMDB_ACCOUNT with (nolock) ON REPLACE(REPLACE(ACCOUNT_NO,'020-',''),'021-','') =CONVERT(VARCHAR,ID)
LEFT OUTER JOIN [ODS_HMDB_US].[DBO].ACT_MANAGED HMDB_CONS_INFO with (nolock) ON ACT_ACCOUNTID=HMDB_ACCOUNT.ID
--)

--SELECT * INTO #BRM_HMDB FROM BRM_HMDB ;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('22 Complete (#BRM_HMDB is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
CREATE INDEX TEMP_BRM_HMDB ON #BRM_HMDB (ACCOUNT_NO);
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('22a Complete (TEMP_BRM_HMDB Index is Created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('Tempdb..#SQ') IS NOT NULL
DROP TABLE #SQ
                  SELECT A1.Account_id,t1.name
				  INTO #SQ FROM SS_DB_ODS.dbo.account_all A1 with (nolock)
                  inner JOIN SS_DB_ODS.dbo.teams_accounts_all ta1 with (nolock)
                  on a1.account_id=ta1.account_id
                  INNER JOIN SS_DB_ODS.dbo.team_all T1 with (nolock)
                        on t1.team_id=ta1.team_id
                  AND t1.parent_team_id is not null
                  where rel_type='support'
                  AND ta1.deleted_at='1970-01-01 00:00:01.000'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('23 Complete (#SQ is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('Tempdb..#AM') IS NOT NULL
DROP TABLE #AM
SELECT UR.account_id,Ua.name INTO #AM
            FROM [SS_DB_ODS].dbo.accounts_users_roles_all UR with (nolock) 
            INNER JOIN [SS_DB_ODS].[dbo].[role_all] R with (nolock)
                        on UR.role_id=R.role_id
            INNER JOIN [SS_DB_ODS].dbo.user_all ua with (nolock)
                        on ua.[user_id]=UR.[user_id]
                              AND R.name='Account Manager'
                              AND ur.deleted_at='1970-01-01 00:00:01.000'
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('24 Complete (#AM is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('Tempdb..#SSL') IS NOT NULL
DROP TABLE #SSL
;WITH SSL AS (
SELECT DISTINCT
              A.number AS NUMBER
              ,A1.number AS HYBRID_ACCOUNT_NO
              ,t.segment AS GROUP_NAME
              ,t.business_unit AS SEGMENT
              ,T.TEAM_ID TEAM
              ,T.name AS TEAM_NAME
              ,AM.name AS ACCOUNT_MANAGER
              ,t.subregion AS SUBREGION
              ,t.region  AS REGION

--INTO #TempT1
FROM SS_DB_ODS.dbo.account_all A with (nolock)
inner JOIN SS_DB_ODS.dbo.teams_accounts_all ta with (nolock)
on ISNULL(A.hybrid_acct_id,a.account_id)=ta.account_id  --- changed form a.ccount_id=ta.account_id
INNER JOIN SS_DB_ODS.dbo.team_all T with (nolock)
on t.team_id=ta.team_id
AND t.parent_team_id IS NULL
AND ta.deleted_at='1970-01-01 00:00:01.000'
LEFT JOIN SS_DB_ODS.dbo.account_all A1 with (nolock) ---Added logic for linked accounts 
on A1.account_id=A.hybrid_acct_id  
and A1.[TYPE]<>'CLOUD'
LEFT JOIN #SQ SQ
                  on SQ.Account_id=ta.account_id
                  
LEFT JOIN
           #AM  AM 
      ON AM.account_id=ISNULL(A1.account_id,ta.account_id)

where 
rel_type='revenue'
AND A.[Type] = 'CLOUD'
)
SELECT * INTO #SSL FROM SSL;
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('25 Complete (#SSL is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
CREATE INDEX TEMP_INDEX_SSL ON #SSL(NUMBER);
--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('26 Complete (TEMP_INDEX_SSL Index is Created):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
/*SELECT A.ACCOUNT_NO
,CASE WHEN EBPC.RESULT=0 THEN 'SUCCESS' 
      WHEN EBPC.RESULT=5 THEN 'BAD CARD' 
      WHEN EBPC.RESULT=6 THEN 'SERVICE UNAVAILABLE' 
      WHEN EBPC.RESULT=7 THEN 'SOFT DECLINE' 
      WHEN EBPC.RESULT=8 THEN 'HARD DECLINE' 
      WHEN EBP.STATUS=10 THEN 'WRITEOFF_SUCCESS' WHEN EBP.STATUS=15 THEN 'SUSPENSE' 
      WHEN EBP.STATUS=16 THEN 'FAILED_SUSPENSE' WHEN EBP.STATUS=18 THEN 'FAILED_RECYCLE_SUSPENSE'
      WHEN EBP.STATUS=19 THEN 'RETURNED_SUSPENSE' WHEN EBP.STATUS=30 THEN 'FAILED' ELSE 'UNKNOWN' END PAYMENT_STATUS
INTO #DECLINE_INFO
FROM EVENT_T E
JOIN ACCOUNT_T A ON E.ACCOUNT_OBJ_ID0=A.POID_ID0
JOIN EVENT_BILLING_PAYMENT_T EBP ON  E.POID_ID0=EBP.OBJ_ID0 --AND EBP.STATUS=0
JOIN EVENT_BILLING_PAYMENT_CC_T EBPC ON E.POID_ID0=EBPC.OBJ_ID0 AND  EBPC.RESULT<>0 
JOIN #BRM_HMDB BH ON BH.ACCOUNT_NO=A.ACCOUNT_NO
WHERE E.POID_TYPE ='/event/billing/payment/cc' AND E.SERVICE_OBJ_TYPE IS NULL   ORDER BY E.CREATED_T DESC*/


INSERT INTO [KAOS].[dbo].[STG_DLY_AGING_REPORT]
(
CUSTOMER_NO
,CUSTOMER_NAME
,CONS_CORE_NO
,HYBRID_ACCOUNT_NO
,STATUS_CODE
,STATUS_DESCRIPTION
,AS_OF_DATE
,TRANSACTION_CURRENCY_CODE
,BALANCE
,CURRENT_0
,BALANCE_1_30
,BALANCE_31_60
,BALANCE_61_90
,BALANCE_91_120
,BALANCE_121_PLUS
,NEW_DELIQUENCY
,LAST_PAYMENT_DATE
,PAYMENT_METHOD
,COMMENTS
,PAYMENT_TERM
,TEAM_NAME
,ACCOUNT_MANAGER
,BILLING_NAME
,BILLING_EMAIL_ADDR
,PRIMARY_NAME
,PRIMARY_EMAIL_ADDR
,GROUP_NAME
,SEGMENT
,REGION
,SUBREGION
,BILL_CYCLE_DATE
,INVOICE_CONS_DATE
,CONSOLDATED_INVOICE
,INTERNAL
,RACKER
,SERVICE_TYPE
,SERVICE_LEVEL
,CONTRACTING_ENTITY
,DW_TIMESTAMP
,BUSINESS_DEVELOPMENT_COLLECTION
,COLLECTIONS_PROFILE
,COLLECTOR_NAME
)



--IF OBJECT_ID('Tempdb..#FINAL_TABLE') IS NOT NULL
--DROP TABLE #FINAL_TABLE

SELECT ACCOUNT_NO AS [CUSTOMER_NO]
,ISNULL(REPLACE(BH.NAME,',',''),'') AS [CUSTOMER_NAME]
,ISNULL(CONS_CORE_NO,'') AS [CONS_CORE_NO]
, ISNULL(HYBRID_ACCOUNT_NO,'') AS HYBRID_ACCOUNT_NO
, ISNULL(CAST(STATUS_CODE AS VARCHAR(MAX)),'') STATUS_CODE
,ISNULL(STATUS_DESCRIPTION,'') STATUS_DESCRIPTION
,CONVERT(VARCHAR(17),GETDATE(),113)AS AS_OF_DATE
,ISNULL(TRANSACTION_CURRENCY_CODE,'') AS TRANSACTION_CURRENCY_CODE, 
ROUND(BALANCE,2) BALANCE,ROUND(CURRENT_0,2) CURRENT_0,ROUND(BALANCE_1_30,2) BALANCE_1_30,ROUND(BALANCE_31_60,2) AS [BALANCE_31_60]
,ROUND(BALANCE_61_90,2) BALANCE_61_90,ROUND(BALANCE_91_120,2) BALANCE_91_120,ROUND(BALANCE_121_PLUS,2) BALANCE_121_PLUS
,CASE NEW_DELIQUENCY WHEN 1 THEN 'YES' ELSE 'NO' END NEW_DELIQUENCY,ISNULL(CONVERT(VARCHAR, LAST_PAYMENT_DATE),'') LAST_PAYMENT_DATE,ISNULL(PAYMENT_METHOD,'') PAYMENT_METHOD,ISNULL(COMMENTS,'') COMMENTS,ISNULL(PAYMENT_TERM,'') PAYMENT_TERM
,ISNULL(REPLACE(TEAM_NAME,',',''),'') TEAM_NAME, ISNULL(REPLACE(ACCOUNT_MANAGER,',',''),'') ACCOUNT_MANAGER,
ISNULL(REPLACE(BILLING_NAME,',',''),'') BILLING_NAME,ISNULL(BILLING_EMAIL_ADDR,'') BILLING_EMAIL_ADDR,ISNULL(REPLACE(PRIMARY_NAME,',',''),'') PRIMARY_NAME
,ISNULL(PRIMARY_EMAIL_ADDR,'') PRIMARY_EMAIL_ADDR, 
ISNULL(REPLACE(GROUP_NAME,',',''),'') GROUP_NAME,ISNULL(REPLACE(SEGMENT,',',''),'') SEGMENT,ISNULL(REPLACE(REGION,',',''),'') REGION,ISNULL(REPLACE(SUBREGION,',',''),'') SUBREGION, BDOM BILL_CYCLE_DATE
--,ISNULL((SELECT TOP 1 PAYMENT_STATUS FROM #DECLINE_INFO D WHERE D.ACCOUNT_NO=BH.ACCOUNT_NO),'') CREDIT_CARD_DECLINE_REASON
,ISNULL(CONVERT(VARCHAR(17),INVOICE_CONS_DATE,113),'') INVOICE_CONS_DATE,ISNULL(CONSOLDATED_ACCOUNT,'') CONSOLDATED_INVOICE
,CASE WHEN RACKER_INTERNAL='INTERNAL' THEN 'Y' ELSE 'N' END INTERNAL,CASE WHEN RACKER_INTERNAL='RACKER' THEN 'Y' ELSE 'N' END RACKER, SERVICE_TYPE,SERVICE_LEVEL,CONTRACTING_ENTITY
,GETDATE() AS DW_TIMESTAMP
,'' BUSINESS_DEVELOPMENT_COLLECTION
,ISNULL(COLLECTIONS_PROFILE,'') AS COLLECTIONS_PROFILE
,ISNULL(COLLECTOR_NAME,'') AS COLLECTOR_NAME
--INTO #FINAL_TABLE
FROM #BRM_HMDB BH
LEFT JOIN #SSL ON NUMBER=REPLACE(REPLACE(ACCOUNT_NO,'020-',''),'021-','')
WHERE  ROUND(BALANCE,2) <> 0; --ORDER BY ACCOUNT_NO,PAYMENT_TERM ASC;

--*********************************************************************************************************************
set @RunTime = convert(varchar(30),getdate()-@StartTime,8)
RAISERROR ('27 Complete ([KAOS].[dbo].[STG_DLY_AGING_REPORT] is Loaded):  %s',10,1,@RunTime) WITH NOWAIT
--*********************************************************************************************************************
-----------------------------------------------------------------------------------------------------------------------
--Final count

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_AGING_REPORT',@final_cnt_stg output

-----------load Audit tbale--------------------------

EXEC EBI_Logging.dbo.udsp_audit_tables 'STG_DLY_AGING_REPORT', 
 'KAOS',  
 'udsp_DLY_AGING_REPORT',
 @init_cnt_stg,
 @final_cnt_stg,
 @currentdate,
 1 ,
 1

END


GO
/****** Object:  StoredProcedure [dbo].[udsp_DLY_BILLED_BDOM_USAGE]    Script Date: 4/27/2016 12:53:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: 
-- Create date: 09/12/2014
-- Description:  This stored proc will insert data INTO the STG_DLY_BILLED_BDOM_USAGE
-- =============================================

CREATE PROCEDURE [dbo].[udsp_DLY_BILLED_BDOM_USAGE]
AS

BEGIN
SET NOCOUNT ON;
DECLARE  @Final_cnt_stg    bigint
DECLARE  @Init_cnt_stg     bigint
DECLARE @CurrentDate DATETIME
SET @CurrentDate = GETDATE()

-------------Initial count--------------------

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_BILLED_BDOM_USAGE',@Init_cnt_stg output

--------------Truncate table-----------------

--exec udsp_truncate_proxy 'KAOS.dbo.STG_DLY_BILLED_BDOM_USAGE'

TRUNCATE TABLE KAOS.dbo.STG_DLY_BILLED_BDOM_USAGE

--------------------------------------------------------------------------------------------------------
--------------------
  

  

declare @epochtoday varchar(10)
set @epochtoday =  datediff(ss,'1970-01-01',DATEADD(DAY,0,convert(date,(GETDATE()))));


WITH UNBILLED AS (SELECT ACCOUNT_NO,DATEADD(SECOND,-1,dateadd(ss, A.EFFECTIVE_T , '1970-01-01'))  EFFECTIVE_T,SUM(I.DUE) CURRENT_DUE,ACTG_CYCLE_DOM BDOM
,DATEADD(SECOND,-1,dateadd(ss, B.LAST_BILL_T , '1970-01-01')) LAST_BILL_DATE
,DATEADD(SECOND,-1,dateadd(ss, B.NEXT_BILL_T , '1970-01-01')) NEXT_BILL_DATE
FROM [BRM_ODS].[dbo].ACCOUNT_T A with (nolock)
LEFT OUTER JOIN [BRM_ODS].[dbo].ACCOUNT_NAMEINFO_T AN with (nolock) ON AN.OBJ_ID0=A.POID_ID0 AND AN.CONTACT_TYPE='PRIMARY'
JOIN [BRM_ODS].[dbo].BILLINFO_T B with (nolock) ON B.ACCOUNT_OBJ_ID0=A.POID_ID0 AND BILLING_SEGMENT=2001 AND ACTG_CYCLE_DOM=DAY(GETDATE())
JOIN [BRM_ODS].[dbo].ITEM_T I with (nolock) ON I.ACCOUNT_OBJ_ID0=A.POID_ID0 AND I.STATUS=2 AND I.OPENED_T >= @epochtoday
WHERE A.CURRENCY=840 GROUP BY ACCOUNT_NO,ACTG_CYCLE_DOM,A.EFFECTIVE_T,B.LAST_BILL_T,B.NEXT_BILL_T),
STATUS_CHANGE AS (
SELECT ACT_ACCOUNTID,MAX(DATE) DATE_CHANGED FROM [ODS_HMDB_US].dbo.ACT_log_AccountStatus with (nolock) GROUP BY ACT_ACCOUNTID),
PREVIOUS AS (
SELECT ACCOUNT_NO,ISNULL(SUM(DUE),0) PREVIOUS_DUE FROM [BRM_ODS].[dbo].ACCOUNT_T A with (nolock), [BRM_ODS].[dbo].ITEM_T I with (nolock),[BRM_ODS].[dbo].BILLINFO_T B with (nolock) WHERE A.POID_ID0=B.ACCOUNT_OBJ_ID0 AND I.ACCOUNT_OBJ_ID0=A.POID_ID0
AND I.STATUS=2 AND I.OPENED_T <@epochtoday AND ACTG_CYCLE_DOM=DAY(GETDATE()) GROUP BY ACCOUNT_NO)

INSERT INTO [dbo].[STG_DLY_BILLED_BDOM_USAGE]

(
	ACCOUNT_NO	 
	,CREATED_DATE	
	,TOTAL_AMOUNT_TO_BE_INVOICED	
	,PREVIOUS_BALANCE_OF_THE_ACCOUNT	
	,BALAANCE_AFTER_THE_RENEWALS	
	,SUM_OF_BILLABLE_CHARGES	
	,LAST_BILL_DATE	
	,NEXT_BILL_DATE	
	,SUM_OF_DISCOUNTS	
	,SUM_OF_TAXES	
	,ISC_CONSOLIDATED	
	,STATUS	
	,DAYS_SINCE_LAST_STATUS_CHANGE	
	,DESIRED_BILLING_DAY	
	,DW_TIMESTAMP 
)



SELECT U.ACCOUNT_NO,ISNULL(CONVERT(VARCHAR(10),U.EFFECTIVE_T,101),'')  CREATED_DATE,CURRENT_DUE TOTAL_AMOUNT_TO_BE_INVOICED,ISNULL(PREVIOUS_DUE,0) PREVIOUS_BALANCE_OF_THE_ACCOUNT
,ISNULL(CURRENT_DUE,0)+ISNULL(PREVIOUS_DUE,0) BALAANCE_AFTER_THE_RENEWALS,CURRENT_DUE SUM_OF_BILLABLE_CHARGES
,ISNULL(CONVERT(VARCHAR(10),LAST_BILL_DATE,101),'') LAST_BILL_DATE,ISNULL(CONVERT(VARCHAR(10),NEXT_BILL_DATE,101),'') NEXT_BILL_DATE
,0 SUM_OF_DISCOUNTS,0 SUM_OF_TAXES
,CASE INVOICE_CONSOLIDATION_FLAG WHEN 1 THEN 'TRUE' WHEN 0 THEN 'FALSE' END ISC_CONSOLIDATED
,CASE ACT_VAL_ACCOUNTSTATUSID
WHEN 1     THEN 'NEW'
WHEN 3     THEN 'ACTIVE'
WHEN 4     THEN 'APPROVAL DENIED'
WHEN 5     THEN 'DELINQUENT'
WHEN 6     THEN 'SUSPENDED'
WHEN 7     THEN 'AUP VIOLATION'
WHEN 8     THEN 'CLOSED'
WHEN 10    THEN 'PENDING MIGRATION'
WHEN 2     THEN 'PENDING APPROVAL'
WHEN 14    THEN 'TESTSTATUS'
WHEN 9     THEN 'UNVERIFIED' END STATUS
,-DATEDIFF(DAY,GETDATE(),DATE_CHANGED) DAYS_SINCE_LAST_STATUS_CHANGE
,BDOM DESIRED_BILLING_DAY
,GETDATE() AS DW_TIMESTAMP
FROM UNBILLED U
LEFT OUTER JOIN PREVIOUS P ON P.ACCOUNT_NO=U.ACCOUNT_NO
JOIN [BRM_ODS].[dbo].ACCOUNT_T A with (nolock) ON A.ACCOUNT_NO=U.ACCOUNT_NO
JOIN [BRM_ODS].[dbo].PROFILE_T PT with (nolock) ON PT.ACCOUNT_OBJ_ID0=A.POID_ID0
JOIN [BRM_ODS].[dbo].PROFILE_RACKSPACE_T PR with (nolock) ON PT.POID_ID0=PR.OBJ_ID0
LEFT OUTER JOIN [ODS_HMDB_US].[DBO].ACT_ACCOUNT HMDB_ACCOUNT with (nolock) ON REPLACE(REPLACE(U.ACCOUNT_NO,'020-',''),'021-','') =CONVERT(VARCHAR,ID)
LEFT OUTER JOIN STATUS_CHANGE ON  REPLACE(REPLACE(U.ACCOUNT_NO,'020-',''),'021-','') =CONVERT(VARCHAR,ACT_ACCOUNTID)
--ORDER BY U.ACCOUNT_NO
;


----Final count

Exec EBI_Logging.dbo.udsp_Row_Count 'KAOS','dbo.STG_DLY_BILLED_BDOM_USAGE',@final_cnt_stg output

-----------load Audit tbale--------------------------

EXEC EBI_Logging.dbo.udsp_audit_tables 'STG_DLY_BILLED_BDOM_USAGE', 
 'KAOS',  
 'udsp_DLY_BILLED_BDOM_USAGE',
 @init_cnt_stg,
 @final_cnt_stg,
 @currentdate,
 1 ,
 1


END

GO
