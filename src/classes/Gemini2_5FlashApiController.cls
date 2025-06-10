/************************************************************************************
 * 파일명          : Gemini2_5FlashApiController.cls
 * 작성자          : 최준석
 * 작성일          : 2025-05-30
 * 설명            :
 * Gemini 2.5 Flash API 연동 컨트롤러 - 파라미터 설정 및 활용 가이드
 * =================================================================================
 * 이 Apex 클래스는 Google Gemini API와의 연동을 담당하며, 요청 생성부터 응답 처리까지의
 * 전체 과정을 지원합니다. 아래 가이드를 통해 주요 파라미터 설정 및 활용 방법을 확인하세요.
 *
 * 주요 기능:
 * - Gemini API 요청 생성 및 전송
 * - 대화형(multi-turn) 및 단일 프롬프트(single-prompt) 지원
 * - 응답 생성 옵션 (temperature, maxTokens 등) 제어
 * - 안전 설정(Safety Settings) 적용
 * - 시스템 지시사항(System Instruction)을 통한 모델 역할 정의
 * - 도구(Tools) 사용 지원: 함수 호출(Function Calling), 코드 실행(Code Execution) 등
 *
 * ---------------------------------------------------------------------------------
 * 1. API 요청 객체 생성 (`Gemini2_5Request`)
 * ---------------------------------------------------------------------------------
 * 모든 API 요청은 `Gemini2_5Request` 객체로 시작합니다.
 *
 * 1.1. 간단한 요청 (단일 사용자 프롬프트)
 * Gemini2_5Request request = new Gemini2_5Request('오늘 날씨 알려줘');
 *
 * 1.2. 대화형 요청 (시스템 지시, 이전 대화 포함)
 * Gemini2_5Request request = new Gemini2_5Request(
 * '너는 친절한 AI 비서야.',  // 시스템 지시 (선택 사항)
 * '오늘 점심 메뉴 추천해줘.', // 현재 사용자 프롬프트
 * '어제 추천해준 메뉴는 좋았어.' // 이전 모델 응답 (선택 사항, 문맥 유지용)
 * );
 *
 * ---------------------------------------------------------------------------------
 * 2. 대화 내용 구성 (`contents` 필드 - `List<Gemini2_5RequestContent>`)
 * ---------------------------------------------------------------------------------
 * `contents`는 대화의 각 턴을 나타내는 `Gemini2_5RequestContent` 객체들의 리스트입니다.
 *
 * 2.1. `Gemini2_5RequestContent`
 * - `role` (String): 메시지 발화자 ('user' 또는 'model'). **필수**
 * - `parts` (List<Gemini2_5RequestPart>): 실제 메시지 조각들. **필수**
 *
 * 2.2. `Gemini2_5RequestPart` (메시지 조각)
 * - `text` (String): 일반 텍스트 메시지.
 * `new Gemini2_5RequestPart('안녕, Gemini!')`
 * - `inlineData` (Map<String, Object>): Base64 인코딩된 이미지 데이터 등.
 * `new Gemini2_5RequestPart('이미지_Base64_데이터_문자열', 'image/jpeg')`
 * (참고: `fileData`는 이 버전에서 제거되었습니다. 이미지 등은 `inlineData`를 사용하세요.)
 *
 * 2.3. 대화 순서의 중요성
 * 정확한 문맥 파악을 위해 `contents` 리스트 내 메시지들은 시간 순서대로 배열되어야 합니다.
 * (예: [사용자 질문1, 모델 답변1, 사용자 질문2 ...])
 *
 * ---------------------------------------------------------------------------------
 * 3. 응답 생성 제어 (`generationConfig` 필드 - `Gemini2_5GenerationConfig`)
 * ---------------------------------------------------------------------------------
 * AI 응답 생성 방식을 상세하게 제어합니다. `Gemini2_5Request` 생성 시 기본값이 할당되며,
 * 필요에 따라 각 필드 값을 직접 수정할 수 있습니다.
 *
 * request.generationConfig.temperature = 0.8; // 창의성 조절 (0.0 ~ 2.0)
 * request.generationConfig.maxOutputTokens = 1024; // 최대 응답 길이 (토큰 수)
 *
 * 3.1. JSON 형식 응답 요청
 * request.generationConfig.responseMimeType = 'application/json';
 * // 선택적으로, 응답 JSON의 스키마를 지정하여 원하는 구조로 응답을 유도할 수 있습니다.
 * request.generationConfig.responseSchema = YourCustomSchemaBuilder.getSchema();
 * // (예: 본 클래스의 getNewsApiJsonResponseFormat() 메서드 참고)
 *
 * ---------------------------------------------------------------------------------
 * 4. 안전 설정 (`safetySettings` 필드 - `List<Gemini2_5SafetySetting>`)
 * ---------------------------------------------------------------------------------
 * 유해 콘텐츠 필터링 수준을 설정합니다.
 * // 기본 설정 사용 시 (아래는 getDefaultSettings가 인스턴스 메서드로 변경된 경우의 예시)
 * Gemini2_5SafetySetting helper = new Gemini2_5SafetySetting(null, null);
 * request.safetySettings = helper.getDefaultSettings();
 * // 또는, 특정 카테고리(category)와 차단 임계값(threshold)을 지정하여 커스텀 설정 가능
 *
 * ---------------------------------------------------------------------------------
 * 5. 시스템 지시사항 (`systemInstruction` 필드 - `Gemini2_5SystemInstruction`) [선택 사항]
 * ---------------------------------------------------------------------------------
 * 모델의 역할, 페르소나, 행동 양식을 시스템 수준에서 지시합니다.
 * request.setSystemInstruction('너는 전문 번역가로서, 모든 답변을 한국어로 해야 해.');
 *
 * ---------------------------------------------------------------------------------
 * 6. 도구(Tools) 활용 (`tools` 필드 - `List<Gemini2_5Tool>`) [선택 사항]
 * ---------------------------------------------------------------------------------
 * 모델이 외부 도구(정의된 함수, 코드 실행기 등)를 사용할 수 있게 합니다.
 *
 * 6.1. 함수 호출 (Function Calling)
 * // 1. 함수 선언 (이름, 설명, 매개변수 스키마)
 * Gemini2_5FunctionDeclaration getWeatherFunc = new Gemini2_5FunctionDeclaration('getCurrentWeather', '특정 도시의 현재 날씨 정보를 가져옵니다.')
 * .addParameter('city', 'string', '날씨를 조회할 도시 이름', true);
 * // 2. 도구에 함수 추가
 * Gemini2_5Tool functionTool = new Gemini2_5Tool().addFunction(getWeatherFunc);
 * // 3. 요청에 도구 추가
 * request.addTool(functionTool);
 * // (모델이 함수 호출을 요청하면, Apex에서 해당 함수를 실행하고 결과를 다시 모델에게 전달해야 합니다.)
 *
 * 6.2. 코드 실행 (`codeExecution`)
 * Gemini2_5Tool codeTool = new Gemini2_5Tool().enableCodeExecution();
 * request.addTool(codeTool);
 *
 * 6.3. Google 검색 (`googleSearch`) - API 환경 및 지원 여부 확인 필요
 * Gemini2_5Tool searchTool = new Gemini2_5Tool().enableGoogleSearch();
 * request.addTool(searchTool);
 *
 * ---------------------------------------------------------------------------------
 * 7. 추론 설정 (`thinkingConfig` 필드 - `Gemini2_5ThinkingConfig`) [선택 사항, 고급]
 * ---------------------------------------------------------------------------------
 * 복잡한 도구 사용이나 다단계 추론 시, 모델의 "생각 예산(토큰)"을 설정합니다.
 * request.setThinkingConfig(new Gemini2_5ThinkingConfig(10000)); // 예: 10000 토큰 예산
 *
 * ---------------------------------------------------------------------------------
 * 8. API 호출 실행 및 설정 정보
 * ---------------------------------------------------------------------------------
 * `String responseText = Gemini2_5FlashApiController.askGemini2_5Flash(request);`
 *
 * API 엔드포인트 및 키는 `IFMaster__c` 및 `ApiConfiguration__mdt`에서 관리됩니다.
 * 이 설정들이 올바르게 구성되어야 정상적인 API 호출이 가능합니다.
 *
 * ---------------------------------------------------------------------------------
 * 각 DTO 클래스 및 필드에 대한 상세 설명은 코드 내 해당 클래스/필드 주석을 참고하세요.
 * =================================================================================================
 * 파일명          : Gemini2_5FlashApiController.cls
 * (이하 헤더 주석은 이전과 동일하며, 생략합니다.)
 * 수정 이력
 * ===================================================================================
 * 버전   수정일          작성자          수정 내용
 * ===================================================================================
   1.0   2025-05-25      최준석
*************************************************************************************/

public class Gemini2_5FlashApiController {
    // API 호출 타임아웃 (120초, Apex 최대치)
    private static final Integer DEFAULT_TIMEOUT = 120000;

    /**
     * Gemini 2.5 Flash API에 요청을 보내고 응답을 처리하는 메인 메서드입니다.
     * @param requestBody API 요청 정보를 담은 {@link Gemini2_5Request} 객체
     * @return String AI의 응답 텍스트
     * @throws Gemini2_5Exception API 호출 실패 또는 설정 오류 시 발생
     */
    public static String askGemini2_5Flash(Gemini2_5Request requestBody) {
        Api__mdt objApiMdt = Api__mdt.getInstance('GeminiApi');
        IFMaster__c objIfMaster;

        for (IFMaster__c obj : [
                SELECT Name, ContentType__c, Description__c, Endpoint__c, Method__c, Type__c, WebserviceType__c
                FROM IFMaster__c
                WHERE Name = 'GeminiFlash2_5Api'
                LIMIT 1
        ]) {
            objIfMaster = obj;
        }

        // API 설정 및 키 유효성 검사
        if (objIfMaster == null || objApiMdt == null || String.isBlank(objApiMdt.ApiKey__c)) {
            String missingConfigDetails = '';
            if (objIfMaster == null) {
                missingConfigDetails += 'IFMaster__c 레코드 \'GeminiFlash2_5Api\' 누락. ';
            }
            if (objApiMdt == null) {
                missingConfigDetails += 'ApiConfiguration__mdt 레코드 \'GeminiApi\' 누락. ';
            } else if (String.isBlank(objApiMdt.ApiKey__c)) {
                missingConfigDetails += 'ApiConfiguration__mdt \'GeminiApi\'의 ApiKey__c 누락. ';
            }
            throw new Gemini2_5Exception('설정 오류: ' + missingConfigDetails.trim() + 'IFMaster__c 및 ApiConfiguration__mdt 설정을 확인하세요.');
        }

        // IFMaster__c 필수 필드 (Endpoint, Method, ContentType) 검증
        if (String.isBlank(objIfMaster.Endpoint__c)) {
            throw new Gemini2_5Exception('IFMaster__c \'GeminiFlash2_5Api\': Endpoint__c 누락.');
        }
        if (String.isBlank(objIfMaster.Method__c)) {
            throw new Gemini2_5Exception('IFMaster__c \'GeminiFlash2_5Api\': Method__c 누락.');
        }
        if (String.isBlank(objIfMaster.ContentType__c)) { // Gemini API는 주로 'application/json' 형식 사용
            throw new Gemini2_5Exception('IFMaster__c \'GeminiFlash2_5Api\': ContentType__c 누락.');
        }

        try {
            HttpRequest req = new HttpRequest();

            // 엔드포인트에 API 키 추가
            String endpoint = objIfMaster.Endpoint__c;
            String fullEndpoint = endpoint.contains('?') ? endpoint + '&key=' + objApiMdt.ApiKey__c : endpoint + '?key=' + objApiMdt.ApiKey__c;
            req.setEndpoint(fullEndpoint);
            req.setMethod(objIfMaster.Method__c);
            req.setHeader('Content-Type', objIfMaster.ContentType__c);
            req.setTimeout(DEFAULT_TIMEOUT);

            // 요청 본문을 JSON으로 직렬화 (null 값 제외)
            String requestBodyJson = JSON.serialize(requestBody, true);
            req.setBody(requestBodyJson);

            System.debug('요청 엔드포인트: ' + req.getEndpoint());
            System.debug('요청 본문: ' + JSON.serializePretty(requestBody));

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('응답 상태: ' + res.getStatusCode());
            System.debug('응답 본문: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Gemini2_5ResponseBody response = (Gemini2_5ResponseBody) JSON.deserialize(
                        res.getBody(),
                        Gemini2_5ResponseBody.class
                );
                // 응답 JSON 역직렬화 결과 null 체크
                if (response == null) {
                    throw new Gemini2_5Exception('응답 본문 역직렬화 실패. 본문: ' + res.getBody());
                }
                return response.extractText();
            } else {
                // API 자체에서 오류 응답을 보낸 경우 (예: 4xx, 5xx 상태 코드)
                // 오류 응답 본문도 GeminiError DTO 등으로 파싱하여 상세 내용을 로깅하거나 반환할 수 있습니다.
                // 간단하게는 그대로 메시지에 포함합니다.
                throw new Gemini2_5Exception('API 오류: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            // 오류 발생 시 스택 트레이스 로깅
            System.debug('오류: ' + e.getMessage() + '\n스택 트레이스: ' + e.getStackTraceString());
            // 예외 유형별 처리 후 Gemini2_5Exception으로 통일
            if (e instanceof System.CalloutException) {
                throw new Gemini2_5Exception('Callout 실패: ' + e.getMessage() + '. 원본 예외: ' + e.getTypeName());
            } else if (e instanceof Gemini2_5Exception) {
                throw e; // 이미 Gemini2_5Exception이면 그대로 전달
            } else {
                // JSONException 등 다른 예외도 포함될 수 있습니다.
                throw new Gemini2_5Exception('요청 처리 중 예외 발생: ' + e.getMessage() + '. 원본 예외: ' + e.getTypeName());
            }
        }
    }

    /**
 * ContentDocument ID와 Gemini 요청 객체를 받아 PDF 파일과 함께 API 요청을 보내는 메소드
 * @param contentDocumentId 분석할 PDF 파일의 ContentDocument ID
 * @param request 기본 Gemini 요청 객체 (이 객체에 PDF 데이터가 추가됨)
 * @return String Gemini API 응답 텍스트
 * @throws Gemini2_5Exception 파일 처리 또는 API 호출 실패 시 발생
 */
    public static String askGeminiWithContentDocument(Id contentDocumentId, Gemini2_5FlashApiController.Gemini2_5Request request) {
        // 1. ContentDocument 및 ContentVersion 조회
        List<ContentVersion> contentVersions = [
                SELECT Id, Title, VersionData, FileType, ContentSize, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                LIMIT 1
        ];

        if (contentVersions.isEmpty()) {
            throw new Gemini2_5FlashApiController.Gemini2_5Exception('지정된 ContentDocument ID에 해당하는 파일을 찾을 수 없습니다: ' + contentDocumentId);
        }

        ContentVersion cv = contentVersions[0];

        // 2. 파일 타입 검증 (PDF만 허용)
        if (cv.FileType != 'PDF' && cv.FileExtension?.toLowerCase() != 'pdf') {
            throw new Gemini2_5FlashApiController.Gemini2_5Exception('PDF 파일만 지원됩니다. 현재 파일 타입: ' + cv.FileType + ', 확장자: ' + cv.FileExtension);
        }

        // 3. 파일 크기 검증 (20MB 제한)
        Integer maxSizeBytes = 20 * 1024 * 1024; // 20MB
        if (cv.ContentSize > maxSizeBytes) {
            throw new Gemini2_5FlashApiController.Gemini2_5Exception(
                    '파일 크기가 너무 큽니다. 최대 20MB까지 지원됩니다. 현재 파일 크기: ' +
                            String.valueOf(cv.ContentSize / 1024 / 1024) + 'MB'
            );
        }

        // 4. PDF 데이터를 Base64로 인코딩
        String pdfBase64 = EncodingUtil.base64Encode(cv.VersionData);

        // 5. 기존 요청 객체에 PDF 데이터 추가
        return addPdfToRequestAndSend(request, pdfBase64, cv.Title);
    }

    /**
     * ContentDocument ID와 텍스트 질문으로 간단하게 PDF 분석 요청을 보내는 메소드
     * @param contentDocumentId PDF 파일의 ContentDocument ID
     * @param question PDF에 대한 질문
     * @return String Gemini API 응답 텍스트
     */
    public static String askGeminiWithContentDocumentSimple(Id contentDocumentId, String question) {
        // 기본 요청 객체 생성
        Gemini2_5FlashApiController.Gemini2_5Request request = new Gemini2_5FlashApiController.Gemini2_5Request(question);

        // PDF 분석에 특화된 시스템 지시사항 추가
        request.setSystemInstruction('당신은 PDF 문서 분석 전문가입니다. 제공된 PDF 문서를 정확히 분석하고 사용자의 질문에 대해 문서 내용을 바탕으로 정확한 답변을 제공해주세요.');

        // PDF 분석에 최적화된 설정
        request.generationConfig.temperature = 0.1; // 정확성을 위해 낮은 온도
        request.generationConfig.maxOutputTokens = 8192; // 충분한 응답 길이

        return askGeminiWithContentDocument(contentDocumentId, request);
    }

    /**
     * 요청 객체에 PDF 데이터를 추가하고 API 호출을 실행하는 내부 헬퍼 메소드
     * @param request 기본 Gemini 요청 객체
     * @param pdfBase64 Base64로 인코딩된 PDF 데이터
     * @param fileName 파일명 (로깅용)
     * @return String Gemini API 응답 텍스트
     */
    private static String addPdfToRequestAndSend(Gemini2_5FlashApiController.Gemini2_5Request request, String pdfBase64, String fileName) {
        try {
            // 기존 contents가 있는지 확인하고 PDF 데이터 추가
            if (request.contents != null && !request.contents.isEmpty()) {
                // 마지막 사용자 메시지에 PDF 추가
                Gemini2_5FlashApiController.Gemini2_5RequestContent lastUserContent = null;

                // 마지막 'user' 역할의 content 찾기
                for (Integer i = request.contents.size() - 1; i >= 0; i--) {
                    if (request.contents[i].role == 'user') {
                        lastUserContent = request.contents[i];
                        break;
                    }
                }

                if (lastUserContent != null) {
                    // 기존 parts에 PDF 추가
                    if (lastUserContent.parts == null) {
                        lastUserContent.parts = new List<Gemini2_5FlashApiController.Gemini2_5RequestPart>();
                    }
                    // PDF를 첫 번째로 추가 (보통 파일을 먼저 제공하는 것이 좋음)
                    lastUserContent.parts.add(0, new Gemini2_5FlashApiController.Gemini2_5RequestPart(pdfBase64, 'application/pdf'));
                } else {
                    // user 역할의 content가 없으면 새로 생성
                    List<Gemini2_5FlashApiController.Gemini2_5RequestPart> parts = new List<Gemini2_5FlashApiController.Gemini2_5RequestPart>{
                            new Gemini2_5FlashApiController.Gemini2_5RequestPart(pdfBase64, 'application/pdf'),
                            new Gemini2_5FlashApiController.Gemini2_5RequestPart('첨부된 PDF 문서를 분석해주세요.')
                    };
                    request.contents.add(new Gemini2_5FlashApiController.Gemini2_5RequestContent('user', parts));
                }
            } else {
                // contents가 없으면 새로 생성
                List<Gemini2_5FlashApiController.Gemini2_5RequestPart> parts = new List<Gemini2_5FlashApiController.Gemini2_5RequestPart>{
                        new Gemini2_5FlashApiController.Gemini2_5RequestPart(pdfBase64, 'application/pdf'),
                        new Gemini2_5FlashApiController.Gemini2_5RequestPart('첨부된 PDF 문서를 분석해주세요.')
                };
                request.contents = new List<Gemini2_5FlashApiController.Gemini2_5RequestContent>{
                        new Gemini2_5FlashApiController.Gemini2_5RequestContent('user', parts)
                };
            }

            System.debug('PDF 파일 추가 완료: ' + fileName + ' (Base64 길이: ' + pdfBase64.length() + ')');

            // API 호출 실행
            return Gemini2_5FlashApiController.askGemini2_5Flash(request);

        } catch (Exception e) {
            System.debug('PDF 처리 중 오류 발생: ' + e.getMessage());
            throw new Gemini2_5FlashApiController.Gemini2_5Exception('PDF 처리 실패: ' + e.getMessage());
        }
    }

//    /**
//     * 계약서 분석 결과를 위한 JSON 스키마 예제
//     */
//    private static Map<String, Object> getContractAnalysisJsonSchema() {
//        return new Map<String, Object>{
//                'type' => 'object',
//                'properties' => new Map<String, Object>{
//                        'contractTitle' => new Map<String, Object>{'type' => 'string', 'description' => '계약서 제목'},
//                        'parties' => new Map<String, Object>{
//                                'type' => 'array',
//                                'items' => new Map<String, Object>{'type' => 'string'},
//                                'description' => '계약 당사자들'
//                        },
//                        'keyTerms' => new Map<String, Object>{
//                                'type' => 'array',
//                                'items' => new Map<String, Object>{
//                                        'type' => 'object',
//                                        'properties' => new Map<String, Object>{
//                                                'term' => new Map<String, Object>{'type' => 'string'},
//                                                'description' => new Map<String, Object>{'type' => 'string'},
//                                                'importance' => new Map<String, Object>{'type' => 'string', 'enum' => new List<String>{'HIGH', 'MEDIUM', 'LOW'}}
//                                        }
//                                }
//                        },
//                        'effectiveDate' => new Map<String, Object>{'type' => 'string', 'description' => '계약 시작일'},
//                        'expirationDate' => new Map<String, Object>{'type' => 'string', 'description' => '계약 종료일'},
//                        'summary' => new Map<String, Object>{'type' => 'string', 'description' => '계약서 요약'}
//                },
//                'required' => new List<String>{'contractTitle', 'parties', 'keyTerms', 'summary'}
//        };
//    }

    /**
     * 뉴스 기사 형식의 JSON 응답을 요청하기 위한 스키마를 생성합니다.
     * Gemini API가 이 스키마에 맞춰 응답하도록 유도할 수 있습니다.
     * @return Map<String, Object> JSON 스키마
     * @example request.generationConfig.responseSchema = getNewsApiJsonResponseFormat();
     */
    public static Map<String, Object> getNewsApiJsonResponseFormat() {
        return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                        'articles' => new Map<String, Object>{
                                'type' => 'array',
                                'items' => new Map<String, Object>{
                                        'type' => 'object',
                                        'properties' => new Map<String, Object>{
                                                'url' => new Map<String, Object>{
                                                        'type' => 'string'
                                                },
                                                'publishedTime' => new Map<String, Object>{
                                                        'type' => 'string'
                                                }
                                        },
                                        'required' => new List<String>{
                                                'url', 'publishedTime'
                                        }
                                }
                        }
                },
                'required' => new List<String>{
                        'articles'
                }
        };
    }

    /**
     * 간단한 텍스트 질문으로 Gemini API에 요청하고 응답을 받는 간편 메서드입니다.
     * @param question 질문 텍스트
     * @return String AI의 응답 텍스트
     * @example String answer = simpleQuery('오늘 날씨는 어때?');
     */
    public static String simpleQuery(String question) {
        Gemini2_5Request request = new Gemini2_5Request(question);
        return askGemini2_5Flash(request);
    }

    /**
     * Gemini API 호출 관련 오류 처리를 위한 사용자 정의 예외 클래스입니다.
     */
    public class Gemini2_5Exception extends Exception {
    }

    /**
     * Gemini API 요청 데이터를 표현하는 클래스입니다.
     * (이하 상세 주석은 이전과 동일하며, 생략합니다.)
     */
    public class Gemini2_5Request {
        public List<Gemini2_5RequestContent> contents;       // 대화 내용 목록
        public Gemini2_5GenerationConfig generationConfig;   // 응답 생성 방식 설정
        public Gemini2_5ThinkingConfig thinkingConfig;       // 추론 과정 설정 (예: 도구 사용 예산)
        public List<Gemini2_5SafetySetting> safetySettings;   // 안전 필터링 설정
        public Gemini2_5SystemInstruction systemInstruction;  // 시스템 지시사항 (모델의 역할 정의)
        public List<Gemini2_5Tool> tools;                    // 사용 가능 도구 목록

        public Gemini2_5Request(String userPrompt) {
            this.contents = new List<Gemini2_5RequestContent>{
                    new Gemini2_5RequestContent('user', userPrompt)
            };
            this.generationConfig = new Gemini2_5GenerationConfig();
            Gemini2_5SafetySetting safetySettingHelper = new Gemini2_5SafetySetting(null, null);
            this.safetySettings = safetySettingHelper.getDefaultSettings();
        }

        public Gemini2_5Request(String systemPrompt, String userPrompt, String assistantPrompt) {
            this.contents = new List<Gemini2_5RequestContent>();
            if (String.isNotBlank(systemPrompt)) {
                this.systemInstruction = new Gemini2_5SystemInstruction(systemPrompt);
            }
            if (String.isNotBlank(assistantPrompt)) {
                this.contents.add(new Gemini2_5RequestContent('model', assistantPrompt));
            }
            if (String.isNotBlank(userPrompt)) {
                this.contents.add(new Gemini2_5RequestContent('user', userPrompt));
            }
            this.generationConfig = new Gemini2_5GenerationConfig();
            Gemini2_5SafetySetting safetySettingHelper = new Gemini2_5SafetySetting(null, null);
            this.safetySettings = safetySettingHelper.getDefaultSettings();
        }

        public Gemini2_5Request addTool(Gemini2_5Tool tool) {
            if (this.tools == null) this.tools = new List<Gemini2_5Tool>();
            this.tools.add(tool);
            return this;
        }
        public Gemini2_5Request setThinkingConfig(Gemini2_5ThinkingConfig config) {
            this.thinkingConfig = config;
            return this;
        }
        public Gemini2_5Request setSystemInstruction(String instructionText) {
            if (String.isNotBlank(instructionText)) this.systemInstruction = new Gemini2_5SystemInstruction(instructionText);
            return this;
        }
    }

    public class Gemini2_5RequestContent {
        public String role;
        public List<Gemini2_5RequestPart> parts;
        public Gemini2_5RequestContent(String role, String text) {
            this.role = role;
            this.parts = new List<Gemini2_5RequestPart>{
                    new Gemini2_5RequestPart(text)
            };
        }
        public Gemini2_5RequestContent(String role, List<Gemini2_5RequestPart> parts) {
            this.role = role;
            this.parts = parts;
        }
    }

    public class Gemini2_5RequestPart {
        public String text;
        public Map<String, Object> inlineData;
        public Gemini2_5RequestPart(String text) {
            this.text = text;
        }
        public Gemini2_5RequestPart(String base64Data, String mimeType) {
            this.inlineData = new Map<String, Object>{
                    'mimeType' => mimeType, 'data' => base64Data
            };
        }
    }

    public class Gemini2_5GenerationConfig {
        public Decimal temperature = 0.0;
        public Integer maxOutputTokens = 30000;
        public Decimal topP = 0.95;
        public Integer topK = 40;
        public String responseMimeType = 'text/plain';
        public Map<String, Object> responseSchema;
        public Integer candidateCount = 1;
        public List<String> stopSequences;
    }

    public class Gemini2_5ThinkingConfig {
        public Integer thinkingBudget;
        public Gemini2_5ThinkingConfig(Integer budget) {
            this.thinkingBudget = budget;
        }
    }

    public class Gemini2_5SafetySetting {
        public String category;
        public String threshold;
        public Gemini2_5SafetySetting(String category, String threshold) {
            this.category = category; this.threshold = threshold;
        }
        public List<Gemini2_5SafetySetting> getDefaultSettings() {
            return new List<Gemini2_5SafetySetting>{
                    new Gemini2_5SafetySetting('HARM_CATEGORY_DANGEROUS_CONTENT', 'BLOCK_ONLY_HIGH'),
                    new Gemini2_5SafetySetting('HARM_CATEGORY_HARASSMENT', 'BLOCK_MEDIUM_AND_ABOVE'),
                    new Gemini2_5SafetySetting('HARM_CATEGORY_HATE_SPEECH', 'BLOCK_MEDIUM_AND_ABOVE'),
                    new Gemini2_5SafetySetting('HARM_CATEGORY_SEXUALLY_EXPLICIT', 'BLOCK_MEDIUM_AND_ABOVE')
            };
        }
    }

    public class Gemini2_5Tool {
        public List<Gemini2_5FunctionDeclaration> functionDeclarations;
        public Map<String, Object> codeExecution;
        public Map<String, Object> googleSearch;
        public Gemini2_5Tool enableCodeExecution() {
            this.codeExecution = new Map<String, Object>();
            return this;
        }
        public Gemini2_5Tool enableGoogleSearch() {
            this.googleSearch = new Map<String, Object>();
            return this;
        }
        public Gemini2_5Tool addFunction(Gemini2_5FunctionDeclaration func) {
            if (this.functionDeclarations == null) this.functionDeclarations = new List<Gemini2_5FunctionDeclaration>();
            this.functionDeclarations.add(func);
            return this;
        }
    }

    public class Gemini2_5FunctionDeclaration {
        public String name;
        public String description;
        public Map<String, Object> parameters;
        public Gemini2_5FunctionDeclaration(String name, String description) {
            this.name = name; this.description = description;
            this.parameters = new Map<String, Object>{
                    'type' => 'object',
                    'properties' => new Map<String, Object>(),
                    'required' => new List<String>()
            };
        }
        public Gemini2_5FunctionDeclaration addParameter(String paramName, String paramType, String paramDescription, Boolean isRequired) {
            Map<String, Object> properties = (Map<String, Object>) this.parameters.get('properties');
            properties.put(paramName, new Map<String, Object>{
                    'type' => paramType,
                    'description' => paramDescription
            });
            if (isRequired) {
                List<String> requiredList = (List<String>) this.parameters.get('required');
                if (!requiredList.contains(paramName)) requiredList.add(paramName);
            }
            return this;
        }
    }

    public class Gemini2_5SystemInstruction {
        public List<Gemini2_5RequestPart> parts;
        public Gemini2_5SystemInstruction(String instructionText) {
            this.parts = new List<Gemini2_5RequestPart>{
                    new Gemini2_5RequestPart(instructionText)
            };
        }
    }

    // ---- 응답 DTO 클래스들 ----

    /** API 사용량 상세 정보 중 프롬프트 토큰 상세 항목을 위한 DTO 클래스 */
    public class Gemini2_5PromptTokenDetail {
        public String modality;
        public Integer tokenCount;
    }

    /** API 사용량 메타데이터 상세 구조를 위한 DTO 클래스 */
    public class Gemini2_5UsageMetadata {
        public Integer promptTokenCount;
        public Integer candidatesTokenCount;
        public Integer totalTokenCount;
        public List<Gemini2_5PromptTokenDetail> promptTokensDetails;
        public Integer thoughtsTokenCount; // API 응답에 thoughtsTokenCount도 포함되어 추가
    }

    /** Gemini API 응답의 전체 구조를 나타냅니다. */
    public class Gemini2_5ResponseBody {
        public List<Gemini2_5ResponseCandidate> candidates; // 응답 후보 목록
        public String modelVersion;                         // 응답 모델 버전 (API 응답에 포함되어 활성화)
        public Gemini2_5UsageMetadata usageMetadata;        // API 사용량 정보 (타입 변경됨)
        /**
         * 입력 프롬프트에 대한 피드백 (안전성 등).
         * 만약 이 필드의 실제 응답 구조가 복잡하다면, usageMetadata와 유사하게
         * 별도의 DTO 클래스를 정의하여 사용하는 것이 좋습니다.
         */
        public Map<String, Object> promptFeedback;

        public String extractText() {
            if (candidates == null || candidates.isEmpty() || candidates[0] == null) return '';
            return candidates[0].extractText();
        }
        public List<String> extractAllTexts() {
            List<String> texts = new List<String>();
            if (candidates != null) {
                for (Gemini2_5ResponseCandidate candidate : candidates) {
                    if (candidate != null) texts.add(candidate.extractText());
                }
            }
            return texts;
        }
    }

    /** AI가 생성한 개별 응답 후보를 나타냅니다. */
    public class Gemini2_5ResponseCandidate {
        public Gemini2_5ResponseContent content;      // 응답 내용
        public String finishReason;                  // 생성 완료 이유
        public Integer index;                       // 후보 인덱스
        public List<Gemini2_5SafetyRating> safetyRatings; // 안전성 평가 결과
        public Map<String, Object> citationMetadata; // 인용 정보 (출처)
        public Integer tokenCount;                  // 해당 응답 후보의 토큰 수

        public String extractText() {
            return (content == null) ? '' : content.extractText();
        }
    }

    /** 응답 후보 내의 실제 콘텐츠 부분을 나타냅니다. */
    public class Gemini2_5ResponseContent {
        public List<Gemini2_5ResponsePart> parts; // 응답 콘텐츠의 파트 목록
        public String role;                      // 메시지 역할 (주로 'model')

        public String extractText() {
            if (parts == null || parts.isEmpty()) return '';
            String extractedText = '';
            for (Gemini2_5ResponsePart part : parts) {
                if (part != null && String.isNotBlank(part.text)) {
                    extractedText += part.text;
                }
            }
            return extractedText;
        }
    }

    /** 응답 콘텐츠의 개별 구성 요소 (텍스트, 함수 호출 등)입니다. */
    public class Gemini2_5ResponsePart {
        public String text;                         // 텍스트 응답
        public Map<String, Object> functionCall;     // 모델의 함수 호출 요청
        public Map<String, Object> functionResponse;
        public Map<String, Object> executableCode;      // 실행 가능한 코드 (코드 실행 도구용)
        public Map<String, Object> codeExecutionResult; // 코드 실행 결과 (코드 실행 도구용)
    }

    /** 응답 콘텐츠의 안전성 평가 결과를 나타냅니다. */
    public class Gemini2_5SafetyRating {
        public String category;    // 유해성 카테고리
        public String probability; // 유해성 확률 (NEGLIGIBLE, LOW, MEDIUM, HIGH 등)
        public Boolean blocked;    // 해당 카테고리로 응답이 차단되었는지 여부
    }
}