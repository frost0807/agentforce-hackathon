/*
 * Created by Jiae.Tak on 2025-05-29.
 */

import {LightningElement, wire, track} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import getSessionId from '@salesforce/apex/AgentronAnalysisController.getSessionId';
import getRiskAnalyzeReportId from '@salesforce/apex/AgentronAnalysisController.getRiskAnalyzeReportId';

export default class LwcAgentronAnalysis extends LightningElement {
    targetChannel = '/event/AgentronEvent__e';
    subscription = {};
    receivedData = {};

    receivedEventMessages = [];
    errorDetails = [];
    connectionStatus = 'Initializing';

    cometd;
    sessionId;
    reportId;
    trackingId;

    @track isLoading = false; // 부모 컴포넌트의 전역 로딩 상태 (초기값 false)
    @track isLoadingNormal = false; // 부모 컴포넌트의 전역 로딩 상태 (초기값 false)

    showErrorReport = false;
    showSelfCheckList = false;
    showActionRec = false;
    showSummaryManual = false;
    showPartSelect = false;
    showSelfQuote = false;
    showTrackingStatus = false;

    // 현재 활성화된 하위 컴포넌트의 로딩 상태를 추적 (여러개가 동시에 로딩될 수 있으므로 Set 사용)
    activeLoadingChildren = new Set();

    // ACTION_REC_SAVE 이벤트로 인한 로딩 상태 추적
    isActionRecSaveProcessing = false;

    // 일반적인 스피너 제어 상태 추적 (주문 생성 등)
    isGeneralProcessing = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.attributes.recordId;
            this.urlStateParameters = currentPageReference.state;

            const channelName = this.urlStateParameters?.c__channelName;
            const jsonString = this.urlStateParameters?.c__jsonString;

            if (channelName === 'ERROR_REPORT' && jsonString) {
                const uuid = JSON.parse(jsonString).uuid;
                // 리포트 ID 가져오는 동안에도 로딩 스피너 표시
                this.isLoading = true; // 중요: CometD 초기화와 별개로 Apex 호출이 시작되면 로딩 시작
                getRiskAnalyzeReportId({uuid: uuid})
                    .then(result => {
                        console.log('result : ' + result);
                        this.reportId = result;
                    })
                    .catch(e => {
                        console.log('ERROR : ', JSON.stringify(e));
                    })
                    .finally(() => {
                        // 모든 초기 로딩이 완료되면 isLoading을 false로 설정 (CometD 핸드셰이크까지 고려)
                        this.updateGlobalLoadingState();
                    });
            }

            this.setComponent(channelName, jsonString);
        }
    }

    connectedCallback() {
        console.log('[AgentronAnalysis] connectedCallback: 컴포넌트가 DOM에 연결되었습니다.');
        this.isLoading = true; // 컴포넌트 초기화 및 CometD 로드 시작 시 전역 스피너 띄우기
        this.initializeCometD().catch(e => {
            console.error('[AgentronAnalysis] 초기화 실패:', e);
            this.connectionStatus = 'Failed';
            this.errorDetails.push({
                id: `err-${Date.now()}`,
                message: `초기화 실패: ${e.message}`
            });
            this.updateGlobalLoadingState(); // 초기화 실패 시에도 로딩 상태 업데이트
        });
    }

    disconnectedCallback() {
        console.log('[AgentronAnalysis] disconnectedCallback');
        this.cometd?.disconnect();
        this.updateGlobalLoadingState(); // 컴포넌트 파괴 시 로딩 상태 업데이트
    }

    async initializeCometD() {
        // Session ID 획득
        this.connectionStatus = 'Getting Session ID';
        this.sessionId = await getSessionId();

        // CometD CDN 로드
        this.connectionStatus = 'Loading CometD';
        await this.loadCometD();

        // 연결 및 구독
        this.connectionStatus = 'Connecting';
        await this.connect();

        this.updateGlobalLoadingState(); // CometD 연결 완료 후 로딩 상태 업데이트
    }

    loadCometD() {
        // ... (기존 loadCometD 로직 그대로 유지) ...
        return new Promise((resolve, reject) => {
            if (window.org?.cometd?.CometD) {
                resolve();
                return;
            }

            const cdnUrls = [
                'https://cdn.jsdelivr.net/npm/cometd@3.1.4/cometd.js',
                'https://cdnjs.cloudflare.com/ajax/libs/cometd/3.1.1/cometd.min.js',
                'https://unpkg.com/cometd@8.0.8/cometd.js'
            ];

            let currentIndex = 0;

            const tryNextCDN = () => {
                if (currentIndex >= cdnUrls.length) {
                    reject(new Error('모든 CDN 로드 실패'));
                    return;
                }

                const script = document.createElement('script');
                script.src = cdnUrls[currentIndex];
                script.async = true;

                script.onload = () => {
                    console.log(`[AgentronAnalysis] CDN 로드 시도: ${script.src}`);
                    if (window.org?.cometd?.CometD) {
                        console.log(`[AgentronAnalysis] CDN 로드 성공: ${script.src}`);
                        resolve();
                    } else {
                        console.warn(`[AgentronAnalysis] CDN ${currentIndex + 1} 객체 없음, window.org:`, window.org);
                        currentIndex++;
                        tryNextCDN();
                    }
                };

                script.onerror = (error) => {
                    console.error(`[AgentronAnalysis] CDN ${currentIndex + 1} 로드 실패: ${script.src}`, error);
                    currentIndex++;
                    tryNextCDN();
                };

                document.head.appendChild(script);
            };

            tryNextCDN();
        });
    }

    connect() {
        // ... (기존 connect 로직 그대로 유지) ...
        return new Promise((resolve, reject) => {
            this.cometd = new window.org.cometd.CometD();

            this.cometd.configure({
                url: `${window.location.protocol}//${window.location.hostname}/cometd/47.0/`,
                requestHeaders: {Authorization: `OAuth ${this.sessionId}`},
                appendMessageTypeToURL: false
            });
            this.cometd.websocketEnabled = false;

            this.cometd.addListener('/meta/subscribe', (msg) => {
                if (msg.successful) {
                    console.log('[AgentronAnalysis] 구독 성공');
                    this.connectionStatus = 'Subscribed';
                    resolve();
                } else {
                    reject(new Error('구독 실패'));
                }
            });

            this.cometd.handshake((reply) => {
                if (reply.successful) {
                    console.log('[AgentronAnalysis] Handshake 성공');
                    this.connectionStatus = 'Connected';
                    this.cometd.subscribe(this.targetChannel, (message) => {
                        this.handlePlatformEvent(message);
                    });
                } else {
                    reject(new Error('Handshake 실패'));
                }
            });
        });
    }

    handlePlatformEvent(message) {
        // ... (기존 handlePlatformEvent 로직 그대로 유지) ...
        console.log('[AgentronAnalysis] 메시지 수신:', JSON.stringify(message));

        this.receivedEventMessages.push({
            id: `evt-${Date.now()}`,
            payload: JSON.stringify(message.data.payload),
            timestamp: new Date().toLocaleString()
        });

        const eventPayload = message.data.payload;
        const channelName = eventPayload.ChannelName__c;
        const jsonString = eventPayload.JsonString__c;

        console.log('[AgentronAnalysis] 🔎 채널:', channelName);
        console.log('[AgentronAnalysis] 🧾 데이터:', jsonString);

        this.setComponent(channelName, jsonString);
    }

    async setComponent(channelName, jsonString) {
        // ... (기존 setComponent 로직 그대로 유지) ...
        try {
            const parsedData = jsonString ? JSON.parse(jsonString) : '';
            console.log('[AgentronAnalysis] ✅ 파싱 완료:', parsedData);

            if (parsedData?.uuid) {
                this.uuid = parsedData.uuid;
                console.log('[AgentronAnalysis] Extracted UUID:', this.uuid);
            }

            //Tracking Event일 경우 삽입
            if(channelName === 'TRACKING_STATUS') this.trackingId = parsedData.trackingId;
            this.setComponentVisibility(channelName);
            this.receivedData = parsedData;
        } catch (e) {
            console.error('[AgentronAnalysis] ❌ JSON 파싱 실패:', JSON.stringify(e));
        }
    }

    // 하위 LWC에서 로딩 상태를 전달받는 핸들러
    handleChildLoadingChange(event) {
        const componentName = event.target.tagName; // 이벤트 발생시킨 컴포넌트의 태그 이름 (예: C-LWC-ERROR-REPORT)
        const isLoading = event.detail.isLoading; // 하위 컴포넌트가 전달한 로딩 상태

        if (isLoading) {
            this.activeLoadingChildren.add(componentName);
            console.log(`[Parent] ${componentName} is now loading. Active loaders:`, this.activeLoadingChildren.size);
        } else {
            this.activeLoadingChildren.delete(componentName);
            console.log(`[Parent] ${componentName} has finished loading. Active loaders:`, this.activeLoadingChildren.size);
        }

        this.updateGlobalLoadingState();
    }

    // 전역 로딩 상태를 업데이트하는 헬퍼 메서드
    updateGlobalLoadingState() {
        const initialLoadingComplete = (this.connectionStatus === 'Connected' || this.connectionStatus === 'Subscribed') && this.reportId != null; // CometD 및 리포트 ID 로딩 완료 기준

        const isParentInitialLoading = !(this.connectionStatus === 'Connected' || this.connectionStatus === 'Subscribed') || (this.urlStateParameters?.c__channelName === 'ERROR_REPORT' && !this.reportId);

        const isChildLoading = this.activeLoadingChildren.size > 0;

        // ACTION_REC_SAVE 처리 중인지 확인
        const isActionRecProcessing = this.isActionRecSaveProcessing;

        // 일반적인 처리 중인지 확인 (주문 생성 등)
        const isGeneralProcessing = this.isGeneralProcessing;

        this.isLoading = isParentInitialLoading || isChildLoading || isActionRecProcessing || isGeneralProcessing;

        console.log(`[Parent] Global isLoading: ${this.isLoading}, Initial Parent Loading: ${isParentInitialLoading}, Child Loading: ${isChildLoading}, ActionRec Processing: ${isActionRecProcessing}, General Processing: ${isGeneralProcessing}, Active Children: ${this.activeLoadingChildren.size}`);
    }

    get displayedEventMessages() {
        return this.receivedEventMessages.slice().reverse();
    }

    get displayedErrorDetails() {
        return this.errorDetails;
    }

    get statusClass() {
        switch (this.connectionStatus) {
            case 'Connected':
            case 'Subscribed':
                return 'slds-text-color_success';
            case 'Connecting':
            case 'Getting Session ID':
            case 'Loading CometD':
            case 'Initializing':
                return 'slds-text-color_default';
            default:
                return 'slds-text-color_error';
        }
    }

    get isConnected() {
        return this.connectionStatus === 'Subscribed';
    }

    setComponentVisibility(channelName) {
        console.log('setComponentVisibility ::: IN ' + channelName);

        this.activeLoadingChildren.clear();
        this.updateGlobalLoadingState();

        switch (channelName) {
            case 'ERROR_REPORT':
                this.initComponent();
                this.showErrorReport = true;
                break;
            case 'SELF_CHECKLIST':
                this.initComponent();
                this.showSelfCheckList = true;
                break;
            case 'ACTION_REC':
                this.initComponent();
                this.showActionRec = true;
                break;
            case 'SUMMARY_MANUAL':
                this.initComponent();
                this.showSummaryManual = true;
                break;
            case 'PART_SELECT':
                this.initComponent();
                this.showPartSelect = true;
                break;
            case 'SELF_QUOTE':
                this.initComponent();
                this.showSelfQuote = true;
                break;
            case 'TRACKING_STATUS':
                this.initComponent();
                this.showTrackingStatus = true;
                break;
            case 'ACTION_REC_SAVE':
                // ACTION_REC_SAVE 이벤트 수신 시 스피너 시작
                console.log('[AgentronAnalysis] ACTION_REC_SAVE 이벤트 수신 - 매뉴얼 생성 프로세스 시작');
                this.isActionRecSaveProcessing = true;
                this.updateGlobalLoadingState();
                this.refs.refActionRec.doSave();
                break;
            case 'ACTION_REC_ACTIVE_DOWNLOAD':
                // ACTION_REC_ACTIVE_DOWNLOAD 이벤트 수신 시 스피너 종료
                console.log('[AgentronAnalysis] ACTION_REC_ACTIVE_DOWNLOAD 이벤트 수신 - 매뉴얼 생성 프로세스 완료');
                this.isActionRecSaveProcessing = false;
                this.updateGlobalLoadingState();
                this.refs.refActionRec.showDownloadButton = true;
                break;
            case 'SHOW_SPINNER':
                // 글로벌 스피너 활성화 (주문 생성 등)
                console.log('[AgentronAnalysis] SHOW_SPINNER 이벤트 수신 - 일반 프로세스 시작');
                this.isGeneralProcessing = true;
                this.updateGlobalLoadingState();
                break;
            case 'DISABLE_SPINNER':
                // 글로벌 스피너 비활성화
                console.log('[AgentronAnalysis] DISABLE_SPINNER 이벤트 수신 - 일반 프로세스 완료');
                this.isGeneralProcessing = false;
                this.updateGlobalLoadingState();
                break;
            case 'SHOW_SPINNER_NORMAL':
                // 일반적인 스피너 활성화
                console.log('[AgentronAnalysis] SHOW_SPINNER_NORMAL 이벤트 수신 - 일반 프로세스 시작');
                this.isLoadingNormal = true;
                break;
            case 'DISABLE_SPINNER_NORMAL':
                // 일반적인 스피너 비활성화
                console.log('[AgentronAnalysis] DISABLE_SPINNER_NORMAL 이벤트 수신 - 일반 프로세스 완료');
                this.isLoadingNormal = false;
                break;
        }
        console.log('this.showErrorReport : ' + this.showErrorReport);
        console.log('this.showSelfCheckList : ' + this.showSelfCheckList);
        console.log('this.showActionRec : ' + this.showActionRec);
        console.log('this.showSummaryManual : ' + this.showSummaryManual);
        console.log('this.showPartSelect : ' + this.showPartSelect);
        console.log('this.showSelfQuote : ' + this.showSelfQuote);

        console.log('setComponentVisibility ::: OUT');
    }

    initComponent() {
        this.showErrorReport = false;
        this.showSelfCheckList = false;
        this.showActionRec = false;
        this.showSummaryManual = false;
        this.showPartSelect = false;
        this.showSelfQuote = false;
        this.showTrackingStatus = false;
    }

    /* 자가점검 제출하기 Btn Action 성공시*/
    handleSelfCheckCompleted() {
        console.log('Self check completed event received from child.');
        this.showSelfCheckList = false;
        this.showActionRec = true;
        // 컴포넌트 전환 시 activeLoadingChildren을 다시 비우는 것이 좋습니다.
        this.activeLoadingChildren.clear();
        this.updateGlobalLoadingState();
    }

    /* 행동추천 제출하기 Btn Action 성공시*/
    handleActionRecommend() {
        console.log('Action Recommend completed event received from child.');
        this.showActionRec = false;
        this.showSummaryManual = true;
        // 컴포넌트 전환 시 activeLoadingChildren을 다시 비우는 것이 좋습니다.
        this.activeLoadingChildren.clear();
        this.updateGlobalLoadingState();
    }
}