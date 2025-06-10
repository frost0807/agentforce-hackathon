/**
 * Created by Jiae.Tak on 2025-05-28.
 */

import { LightningElement, track, api } from 'lwc';
import getInit from '@salesforce/apex/ErrorReportController.getInit';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJS from '@salesforce/resourceUrl/ChartJS2';
import TYPEWRITER_JS from '@salesforce/resourceUrl/TypewriterEffect';
import spinnerImageUrl from '@salesforce/resourceUrl/spinnerImage';

export default class LwcErrorReport extends LightningElement {
    _isLoading = true;

    @track error = null;
    spinnerImageUrl = spinnerImageUrl;
    @track errorReportData = {
        hasPredictions: false,
        message: '예측 데이터를 불러오는 중입니다...',
        riskItems: []
    };

    // 타이핑 애니메이션용 상태
    @track displayedItems = []; // 화면에 표시될 아이템들
    @track isTyping = false; // 타이핑 중인지 여부

    uuid;
    chartJsInitialized = false;
    typewriterInitialized = false;
    chartsRendered = false;
    pieChart;
    barChart;
    typewriter;
    currentTypingIndex = 0;
    currentFieldIndex = 0;

    // 타이핑할 필드들의 순서 정의
    typingFields = [
        'expectedFaultDate',
        'componentLifeExpectancy',
        'usageAnalysis',
        'faultHistorySummary',
        'riskReason',
        'recommendedAction',
        'impactDescription',
        'selfRepairCost',
        'externalRepairCost',
        'costComparisonMessage'
    ];

    @api
    get isLoading() {
        return this._isLoading;
    }
    set isLoading(value) {
        this._isLoading = value;
        this.dispatchEvent(new CustomEvent('loadingchange', {
            detail: { isLoading: value },
            bubbles: true,
            composed: true
        }));
    }

    connectedCallback() {
        this.getUUIDToSFId();
        console.log('uuid time : ' + new Date().toLocaleTimeString());

        if (this.uuid) {
            this.isLoading = true;

            Promise.all([
                loadScript(this, ChartJS),
                loadScript(this, TYPEWRITER_JS)
            ])
                .then(() => {
                    this.chartJsInitialized = true;
                    this.typewriterInitialized = true;
                    this.initializeTypewriter();
                    this.getInit();
                })
                .catch(error => {
                    this.error = error.message;
                    console.error("Error loading libraries", error);
                    this.isLoading = false;
                });
        } else {
            this.isLoading = false;
            this.error = 'UUID가 제공되지 않았습니다.';
            this.errorReportData.message = 'UUID가 없어 예측 데이터를 불러올 수 없습니다.';
            this.errorReportData.hasPredictions = false;
        }
    }

    renderedCallback() {
        // 차트 렌더링 - 타이핑 완료 후에만
        if (this.chartJsInitialized && this.errorReportData.hasPredictions && !this.chartsRendered && !this.isTyping) {
            const pieChartCtx = this.template.querySelector('canvas.pieChart')?.getContext('2d');
            const barChartCtx = this.template.querySelector('canvas.barChart')?.getContext('2d');

            if (pieChartCtx && barChartCtx) {
                console.log('Rendering charts in renderedCallback...');
                this.renderCharts(this.errorReportData.riskItems);
                this.chartsRendered = true;
            }
        }
    }

    initializeTypewriter() {
        if (window.TypewriterEffect) {
            this.typewriter = window.TypewriterEffect.create({
                speed: 10,              // 더 빠른 타이핑 속도 (15 → 10)
                showCursor: false,      // 커서 숨김
                onComplete: () => {
                    console.log('Field typing completed');
                }
            });
        }
    }

    getUUIDToSFId() {
        const urlParams = new URLSearchParams(window.location.search);
        const jsonString = urlParams.get('c__jsonString');
        if (jsonString) {
            try {
                const parsed = JSON.parse(decodeURIComponent(jsonString));
                this.uuid = parsed.uuid;
                console.log('Extracted UUID:', this.uuid);
            } catch (e) {
                console.error('Error parsing jsonString:', e);
                this.error = 'URL 파라미터 파싱 중 오류가 발생했습니다.';
            }
        }
    }

    async getInit() {
        console.log('fetchErrorReport initiated at: ' + new Date().toLocaleTimeString());
        this.isLoading = true;
        this.error = null;
        this.chartsRendered = false;

        try {
            const result = await getInit({ uuid: this.uuid });
            console.log('Apex Result:', result);

            if (result && result.hasPredictions) {
                this.errorReportData.riskItems = result.riskItems.map((item, index) => {
                    let severityClass = '';
                    let severityIcon = '';
                    let severityBadgeClass = 'slds-badge custom-badge-margin';

                    switch (item.faultSeverityLevel) {
                        case '매우 높음':
                            severityClass = 'slds-text-color_error';
                            severityIcon = 'utility:warning';
                            severityBadgeClass += ' slds-theme_error';
                            break;
                        case '높음':
                            severityClass = 'slds-text-color_warning';
                            severityIcon = 'utility:alert';
                            severityBadgeClass += ' slds-theme_warning';
                            break;
                        case '보통':
                            severityClass = 'slds-text-color_default';
                            severityIcon = 'utility:info';
                            severityBadgeClass += ' slds-theme_inverse';
                            break;
                        case '낮음':
                            severityClass = 'slds-text-color_success';
                            severityIcon = 'utility:success';
                            severityBadgeClass += ' slds-theme_success';
                            break;
                        default:
                            severityClass = 'slds-text-color_default';
                            severityIcon = 'utility:info';
                            severityBadgeClass += ' slds-theme_default';
                    }

                    return {
                        ...item,
                        severityClass,
                        severityIcon,
                        severityBadgeClass,
                        selfRepairCost: parseFloat(item.selfRepairCost || 0),
                        externalRepairCost: parseFloat(item.externalRepairCost || 0),
                        displayIndex: index,
                        uniqueId: `item-${index}-${Date.now()}`
                    };
                });

                this.errorReportData.hasPredictions = true;
                this.errorReportData.message = result.message;

                // 초기화
                this.displayedItems = [];
                this.currentTypingIndex = 0;
                this.currentFieldIndex = 0;

                // 타이핑 애니메이션 시작
                this.isLoading = false;
                this.startTypingAnimation();

            } else if (result && result.hasPredictions === false) {
                this.errorReportData.hasPredictions = false;
                this.errorReportData.message = result.message || '예측 데이터를 가져올 수 없습니다.';
                this.error = result.message;
                this.destroyCharts();
                this.isLoading = false;
            } else {
                this.errorReportData.hasPredictions = false;
                this.errorReportData.message = '서버 응답 형식이 올바르지 않습니다.';
                this.error = '서버 응답 형식이 올바르지 않습니다.';
                this.destroyCharts();
                this.isLoading = false;
            }
        } catch (error) {
            this.error = error.body && error.body.message ? error.body.message : '알 수 없는 오류가 발생했습니다.';
            this.errorReportData.hasPredictions = false;
            this.errorReportData.message = '데이터를 불러오는 중 오류가 발생했습니다.';
            this.destroyCharts();
            console.error('Error fetching prediction data:', error);
            this.isLoading = false;
        }
        console.log('end time : ' + new Date().toLocaleTimeString());
    }

    startTypingAnimation() {
        if (!this.typewriterInitialized || !this.errorReportData.riskItems.length) {
            return;
        }

        this.isTyping = true;

        // 모든 아이템을 한 번에 빈 데이터로 초기화해서 추가
        this.displayedItems = this.errorReportData.riskItems.map((item, index) => ({
            ...item,
            // 타이핑할 필드들을 빈 값으로 초기화
            expectedFaultDate: '',
            componentLifeExpectancy: '',
            usageAnalysis: '',
            faultHistorySummary: '',
            riskReason: '',
            recommendedAction: '',
            impactDescription: '',
            selfRepairCost: '',
            externalRepairCost: '',
            costComparisonMessage: '',
            displayIndex: index
        }));

        // DOM 업데이트 후 모든 아이템의 타이핑을 병렬로 시작
        setTimeout(() => {
            this.startParallelTyping();
        }, 300);
    }

    startParallelTyping() {
        const typingPromises = [];

        // 각 아이템별로 독립적인 타이핑 시작
        this.errorReportData.riskItems.forEach((item, itemIndex) => {
            const promise = this.typeItemFields(itemIndex);
            typingPromises.push(promise);

            // 아이템별로 약간의 시차를 두어 자연스럽게 시작
            setTimeout(() => {
                this.typeItemFields(itemIndex);
            }, itemIndex * 150); // 150ms씩 지연
        });

        // 모든 타이핑이 완료되면 상태 업데이트
        Promise.all(typingPromises).then(() => {
            this.isTyping = false;
            console.log('All parallel typing completed');
        });
    }

    async typeItemFields(itemIndex) {
        return new Promise((resolve) => {
            let currentFieldIndex = 0;

            const typeNextFieldForItem = () => {
                if (currentFieldIndex >= this.typingFields.length) {
                    // 현재 아이템의 모든 필드 타이핑 완료
                    resolve();
                    return;
                }

                const fieldName = this.typingFields[currentFieldIndex];
                const originalItem = this.errorReportData.riskItems[itemIndex];
                const fieldValue = originalItem[fieldName];

                // 해당 필드가 없거나 빈 값이면 다음 필드로
                if (!fieldValue) {
                    currentFieldIndex++;
                    setTimeout(typeNextFieldForItem, 50);
                    return;
                }

                const fieldElement = this.template.querySelector(
                    `[data-item-index="${itemIndex}"] .typing-target[data-field="${fieldName}"]`
                );

                if (!fieldElement) {
                    console.log(`Field element not found: ${fieldName} for item ${itemIndex}`);
                    currentFieldIndex++;
                    setTimeout(typeNextFieldForItem, 50);
                    return;
                }

                // 필드값 포맷팅 (숫자 필드인 경우)
                let displayValue = fieldValue;
                if (fieldName === 'selfRepairCost' || fieldName === 'externalRepairCost') {
                    displayValue = parseFloat(fieldValue || 0).toLocaleString();
                }

                // 타이핑 시작 (각 아이템별로 독립적인 typewriter 인스턴스 사용)
                fieldElement.textContent = '';

                if (window.TypewriterEffect) {
                    const itemTypewriter = window.TypewriterEffect.create({
                        speed: 10,
                        showCursor: false,
                        onComplete: () => {
                            currentFieldIndex++;
                            setTimeout(typeNextFieldForItem, 100);
                        }
                    });

                    itemTypewriter.typeText(fieldElement, displayValue);
                } else {
                    // 타이핑 효과가 없으면 즉시 표시
                    fieldElement.textContent = displayValue;
                    currentFieldIndex++;
                    setTimeout(typeNextFieldForItem, 100);
                }
            };

            // 첫 번째 필드부터 시작
            typeNextFieldForItem();
        });
    }

    typeNextField() {
        // 이 메서드는 더 이상 사용하지 않음 (병렬 처리로 대체)
        console.log('typeNextField is deprecated - using parallel typing instead');
    }

    // 사용자가 타이핑 애니메이션을 건너뛸 수 있는 메서드
    skipTypingAnimation() {
        if (this.isTyping) {
            this.isTyping = false;
            this.displayedItems = this.errorReportData.riskItems.map((item, index) => ({
                ...item,
                displayIndex: index
            }));

            // 모든 typewriter 인스턴스 정리
            if (window.TypewriterEffect) {
                // 전역적으로 모든 타이핑 중단
                const allTypingElements = this.template.querySelectorAll('.typing-target');
                allTypingElements.forEach(element => {
                    if (element.typewriterInstance) {
                        element.typewriterInstance.stop();
                    }
                });
            }
        }
    }

    renderCharts(riskItems) {
        const pieChartCtx = this.template.querySelector('canvas.pieChart')?.getContext('2d');
        const barChartCtx = this.template.querySelector('canvas.barChart')?.getContext('2d');

        if (!pieChartCtx || !barChartCtx) {
            console.error('Canvas context still not found during renderCharts execution.');
            return;
        }

        const faultTypeCosts = {};
        let totalSelfRepairCost = 0;
        let totalExternalRepairCost = 0;

        riskItems.forEach(item => {
            const faultType = item.componentName || '기타';
            const selfCost = item.selfRepairCost;
            const externalCost = item.externalRepairCost;

            faultTypeCosts[`${faultType}`] = (faultTypeCosts[`${faultType}`] || 0) + Math.max(selfCost, externalCost);

            totalSelfRepairCost += selfCost;
            totalExternalRepairCost += externalCost;
        });

        // 원형 차트
        if (this.pieChart) {
            this.pieChart.destroy();
        }
        this.pieChart = new Chart(pieChartCtx, {
            type: 'doughnut',
            data: {
                labels: Object.keys(faultTypeCosts),
                datasets: [{
                    data: Object.values(faultTypeCosts),
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.7)',
                        'rgba(54, 162, 235, 0.7)',
                        'rgba(255, 206, 86, 0.7)',
                        'rgba(75, 192, 192, 0.7)',
                        'rgba(153, 102, 255, 0.7)',
                        'rgba(255, 159, 64, 0.7)',
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                    },
                    tooltip: {
                        callbacks: {
                            label: function(tooltipItem) {
                                return tooltipItem.label + ': ' + parseFloat(tooltipItem.raw).toLocaleString() + '원';
                            }
                        }
                    }
                }
            }
        });

        // 막대 차트
        if (this.barChart) {
            this.barChart.destroy();
        }
        this.barChart = new Chart(barChartCtx, {
            type: 'bar',
            data: {
                labels: ['총 예상 유지보수 비용'],
                datasets: [{
                    label: '자가 수리 예상 비용',
                    data: [totalSelfRepairCost],
                    backgroundColor: 'rgba(75, 192, 192, 0.7)',
                    borderColor: 'rgba(75, 192, 192, 1)',
                    borderWidth: 1
                }, {
                    label: '외부 수리 예상 비용',
                    data: [totalExternalRepairCost],
                    backgroundColor: 'rgba(255, 159, 64, 0.7)',
                    borderColor: 'rgba(255, 159, 64, 1)',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                    },
                    tooltip: {
                        callbacks: {
                            label: function(tooltipItem) {
                                return tooltipItem.dataset.label + ': ' + parseFloat(tooltipItem.raw).toLocaleString() + '원';
                            }
                        }
                    }
                }
            },
            scales: {
                x: {
                    stacked: true,
                },
                y: {
                    stacked: true,
                    beginAtZero: true,
                    ticks: {
                        callback: function(value) {
                            return value.toLocaleString() + '원';
                        },
                        stepSize: Math.max(100000, Math.ceil(Math.max(totalSelfRepairCost, totalExternalRepairCost) / 10 / 100000) * 100000)
                    }
                }
            }
        });
    }

    destroyCharts() {
        if (this.pieChart) {
            this.pieChart.destroy();
            this.pieChart = null;
        }
        if (this.barChart) {
            this.barChart.destroy();
            this.barChart = null;
        }
        this.chartsRendered = false;
    }
}