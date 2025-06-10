/************************************************************************************
 * File Name        : ba_PublishRiskAnalyzeReport.cls
 * Author           : 최준석
 * Date             : 2025-05-31
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-31      최준석
*************************************************************************************/

public class ba_PublishRiskAnalyzeReport implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name FROM Account WHERE Id = \'001Qy0000172T51IAE\''; // 데모용으로 Record 1개만 - ○○정밀공업

//        String query = 'SELECT Id, Name FROM Account WHERE Id = \'001Qy0000172T4xIAE\''; // 데모용으로 Record 1개만 - oo정밀
//        String query = 'SELECT Id, Name FROM Account WHERE Id = \'001Qy0000172T4kIAE\''; // 데모용으로 Record 1개만 - oo화학

        System.debug('ba_PublishRiskAnalyzeReport - start: Query: ' + query);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> listAccount) {
        System.debug('ba_PublishRiskAnalyzeReport - execute: Processing ' + listAccount.size() + ' Accounts in this chunk.');
        if (listAccount == null || listAccount.isEmpty()) {
            System.debug('No Accounts in the current scope to process.');
            return;
        }

        List<Id> listAccountId = new List<Id>();
        for (Account acc : listAccount) {
            listAccountId.add(acc.Id);
        }

        // --- 1. 현재 scope의 모든 Account에 대한 관련 데이터 일괄 조회 ---
        Map<Id, List<Asset>> mapAccountIdToAssets = new Map<Id, List<Asset>>();
        Set<Id> setAssetId = new Set<Id>();

        if (!listAccountId.isEmpty()) {
            for (Asset obj : [
                    SELECT Id, AccountId, Product2Id, Name, SerialNumber
                    FROM Asset
                    WHERE AccountId IN :listAccountId
                    ORDER BY AccountId
                    LIMIT 1             //데모용으로 1개만 사용(Time Out Issue)
            ]) {
                if (!mapAccountIdToAssets.containsKey(obj.AccountId)) {
                    mapAccountIdToAssets.put(obj.AccountId, new List<Asset>());
                }
                mapAccountIdToAssets.get(obj.AccountId).add(obj);
                setAssetId.add(obj.Id);
            }
        }

        Map<Id, List<Case>> mapAssetIdToCases = new Map<Id, List<Case>>();
        if (!setAssetId.isEmpty()) {
            for (Case obj : [
                    SELECT Id, AssetId, Subject, Description, Part_Code__c, Part_Name__c, malfuction_type__c
                            , Malfunction_Type_Detail__c, CreatedDate, Fault_Code__c, Manufacturer__c, Price__c
                    FROM Case
                    WHERE AssetId IN :setAssetId
                    AND CreatedDate = LAST_N_DAYS:365
                    ORDER BY AssetId, CreatedDate DESC
            ]) {
                if (!mapAssetIdToCases.containsKey(obj.AssetId)) {
                    mapAssetIdToCases.put(obj.AssetId, new List<Case>());
                }
                mapAssetIdToCases.get(obj.AssetId).add(obj);
            }
        }

        Map<Id, List<Alarm_history__c>> mapAssetIdToAlarmHistories = new Map<Id, List<Alarm_history__c>>();
        if (!setAssetId.isEmpty()) {
            for (Alarm_history__c obj : [
                    SELECT Id, Name, Asset__c, Account__c, Error_alarm__c, Product__c, Product2__c,
                            SerialNumber__c, InstallDate__c, ManufactureDate__c,
                            Customer_Warranty_Start_Date__c, Customer_Warranty_End_Date__c,
                            Alarm_Ex__c, Code_L__c, Code_M__c, Code_Name_L__c, Code_Name_M__c, CreatedDate
                    FROM Alarm_history__c
                    WHERE Asset__c IN :setAssetId
                    AND CreatedDate = LAST_N_DAYS:365
                    ORDER BY Asset__c, CreatedDate DESC
            ]) {
                if (!mapAssetIdToAlarmHistories.containsKey(obj.Asset__c)) {
                    mapAssetIdToAlarmHistories.put(obj.Asset__c, new List<Alarm_history__c>());
                }
                mapAssetIdToAlarmHistories.get(obj.Asset__c).add(obj);
            }
        }

        // --- 2. scope 내 각 Account에 대해 위험 분석 처리 ---
        for (Account objAccount : listAccount) {
            List<Asset> listAsset = mapAccountIdToAssets.get(objAccount.Id);
            if (listAsset == null || listAsset.isEmpty()) {
                System.debug('No Assets found for Account: ' + objAccount.Id);
                continue;
            }

            try {
                RiskAnalysisProcessor.processRiskAnalysis(objAccount, listAsset, mapAssetIdToCases, mapAssetIdToAlarmHistories);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Risk analysis processing error for Account: ' + objAccount.Id + ', Error: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ba_PublishRiskAnalyzeReport completed. Salesforce Job ID: ' + bc.getJobId());
    }
}