/************************************************************************************
 * File Name        : ChatGptApiController.cls
 * Author           : 최준석
 * Date             : 2025-05-30
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-30      최준석
*************************************************************************************/
public class ChatGptApiController {

    // --- Public Static Methods ---
    public static String uploadBatchFile(String jsonlContent) {
        IFMaster__c ifMaster = getIfMaster('OpenAI_File_Upload');
        String apiKey = getApiKey();
        if (String.isBlank(jsonlContent)) {
            throw new ChatGptApiException('업로드할 파일 내용이 비어있습니다.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ifMaster.Endpoint__c);
        req.setMethod(ifMaster.Method__c);
        String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        String body = '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="purpose"\r\n\r\n' +
                'batch\r\n' +
                '--' + boundary + '\r\n' +
                'Content-Disposition: form-data; name="file"; filename="batch_input.jsonl"\r\n' +
                'Content-Type: application/jsonl\r\n\r\n' +
                jsonlContent + '\r\n' +
                '--' + boundary + '--\r\n';
        req.setBody(body);
        HttpResponse res = executeHttpRequest(req, apiKey, new List<Integer>{200, 201});
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) responseMap.get('id');
    }

    public static String createBatchJob(String inputFileId, String endpoint, String completionWindow) {
        IFMaster__c ifMaster = getIfMaster('OpenAI_Batch_Create');
        String apiKey = getApiKey();
        if (String.isBlank(inputFileId) || String.isBlank(endpoint) || String.isBlank(completionWindow)) {
            throw new ChatGptApiException('OpenAI 배치 작업 생성 파라미터 누락');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ifMaster.Endpoint__c);
        req.setMethod(ifMaster.Method__c);
        req.setHeader('Content-Type', ifMaster.ContentType__c);
        Map<String, Object> bodyMap = new Map<String, Object>{
                'input_file_id' => inputFileId,
                'endpoint' => endpoint,
                'completion_window' => completionWindow
        };
        req.setBody(JSON.serialize(bodyMap));
        HttpResponse res = executeHttpRequest(req, apiKey, new List<Integer>{200, 201});
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) responseMap.get('id');
    }

    public static Map<String, Object> retrieveBatchJobStatus(String batchId) {
        IFMaster__c ifMaster = getIfMaster('OpenAI_Batch_Retrieve');
        String apiKey = getApiKey();
        if (String.isBlank(batchId)) {
            throw new ChatGptApiException('조회할 OpenAI 배치 작업 ID가 누락되었습니다.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ifMaster.Endpoint__c + '/' + batchId);
        req.setMethod(ifMaster.Method__c);
        if(String.isNotBlank(ifMaster.ContentType__c)) {
            req.setHeader('Content-Type', ifMaster.ContentType__c);
        }
        HttpResponse res = executeHttpRequest(req, apiKey, new List<Integer>{200});
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    public static String retrieveFileContent(String fileId) {
        IFMaster__c ifMaster = getIfMaster('OpenAI_File_Content_Retrieve');
        String apiKey = getApiKey();
        if (String.isBlank(fileId)) {
            throw new ChatGptApiException('다운로드할 OpenAI 파일 ID가 누락되었습니다.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ifMaster.Endpoint__c + '/' + fileId + '/content');
        req.setMethod(ifMaster.Method__c);
        HttpResponse res = executeHttpRequest(req, apiKey, new List<Integer>{200});
        return res.getBody();
    }

    // --- Private Helper Methods ---
    private static String getApiKey() {
        Api__mdt apiKeyMdt = Api__mdt.getInstance('OpenAIApiConfig');
        if (apiKeyMdt == null || String.isBlank(apiKeyMdt.ApiKey__c)) {
            String errorMsg = 'OpenAI API Key가 Api__mdt에 설정되지 않았습니다 (레코드명: OpenAIApiConfig).';
            System.debug(LoggingLevel.ERROR, 'ChatGptApiController: ' + errorMsg);
            throw new ChatGptApiException(errorMsg);
        }
        return apiKeyMdt.ApiKey__c;
    }

    private static IFMaster__c getIfMaster(String recordName) {
        List<IFMaster__c> ifMasterList = [
                SELECT Endpoint__c, Method__c, ContentType__c
                FROM IFMaster__c WHERE Name = :recordName LIMIT 1
        ];
        if (ifMasterList.isEmpty()) {
            String errorMsg = 'IFMaster 설정 레코드 ' + recordName + ' 을(를) 찾을 수 없습니다.';
            System.debug(LoggingLevel.ERROR, 'ChatGptApiController: ' + errorMsg);
            throw new ChatGptApiException(errorMsg);
        }
        return ifMasterList[0];
    }

    private static HttpResponse executeHttpRequest(HttpRequest req, String apiKey, List<Integer> successStatusCodes) {
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(120000);
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
            System.debug('OpenAI API 응답 (' + req.getEndpoint() + '): ' + res.getStatusCode() + ' ' + res.getBody());
            if (!successStatusCodes.contains(res.getStatusCode())) {
                String responseBody = res.getBody();
                String errorMessage = 'OpenAI API 오류 (' + req.getEndpoint() + '): ' + res.getStatusCode() + ' - ' + res.getStatus();
                if (String.isNotBlank(responseBody)) {
                    errorMessage += '\n응답 본문: ' + responseBody;
                }
                throw new ChatGptApiException(errorMessage);
            }
            return res;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OpenAI API 호출 중 예외 발생 (' + req.getEndpoint() + '): ' + e.getMessage() + e.getStackTraceString());
            if (e instanceof ChatGptApiException) throw e;
            throw new ChatGptApiException('OpenAI API 호출 중 예외 (' + req.getEndpoint() + '): ' + e.getMessage(), e);
        }
    }

    public class ChatGptApiException extends Exception {}
}