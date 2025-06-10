import {LightningElement, api, track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import getRecommendedParts from '@salesforce/apex/PartSelectController.getRecommendedParts';
import getBaseProductCode from '@salesforce/apex/PartSelectController.getBaseProductCode';
import saveSelectedParts from '@salesforce/apex/PartSelectController.saveSelectedParts';
import generateQuoteAndTransition from '@salesforce/apex/PartSelectController.generateQuoteAndTransition';
import saveComponentStatus from '@salesforce/apex/AgentronAnalysisController.saveComponentStatus';

export default class lwcPartSelect extends LightningElement {
    riskAnalyzeReportId; // 위험 분석 보고서 ID
    _isLoading = true;
    // eventData를 api로 받아서 변경 감지
    _eventData = {};
    @api
    get eventData() {
        return this._eventData;
    }
    set eventData(value) {
        this._eventData = value;
        // eventData가 변경되면 초기화 수행
        if (value && Object.keys(value).length > 0) {
            this.handleEventDataChange();
        }
    }

    @api
    get isLoading() {
        return this._isLoading;
    }
    set isLoading(value) {
        this._isLoading = value;
        // 로딩 상태 변경 시 부모에게 이벤트 디스패치
        this.dispatchEvent(new CustomEvent('loadingchange', {
            detail: { isLoading: value },
            bubbles: true, // 버블링하여 부모에서 감지
            composed: true // Shadow DOM 경계를 넘어 이벤트 전파
        }));
    }

    @track searchTerm = '';
    @track baseProductCode = '';
    @track allProducts = []; // Product2 목록
    @track filteredProducts = []; // 필터링된 Product2 목록
    @track selectedParts = new Map(); // 선택된 가상 SelectedPartItem들 (Product ID -> 가상 레코드)
    @track showSuccessMessage = false;
    @track isLoading = true; // 기본값을 true로 설정하여 처음에 스피너 표시
    @track isInitialized = false; // 초기화 완료 여부

    // 현재 사용 중인 RiskAnalyzeReportId 반환
    get effectiveRiskAnalyzeReportId() {
        return this.riskAnalyzeReportId;
    }

    get hasResults() {
        return this.filteredProducts.length > 0;
    }

    get noResultsMessage() {
        return this.searchTerm ? `"${this.searchTerm}"에 대한 검색 결과가 없습니다.` : '부품이 없습니다.';
    }

    get selectedCount() {
        return this.selectedParts.size;
    }

    get isSaveButtonDisabled() {
        return this.selectedCount === 0 || this.isLoading;
    }

    get isQuoteButtonDisabled() {
        return this.selectedCount === 0 || this.isLoading;
    }

    // eventData가 있는지 확인하여 컨텐츠 표시 여부 결정
    get shouldShowContent() {
        return this.isInitialized && this.eventData && Object.keys(this.eventData).length > 0;
    }

    // 스피너 표시 여부
    get shouldShowSpinner() {
        return this.isLoading || !this.shouldShowContent;
    }

    // === 라이프사이클 메서드 ===

    connectedCallback() {
        // eventData가 이미 있으면 즉시 초기화
        if (this.eventData && Object.keys(this.eventData).length > 0) {
            this.isLoading = true;
            this.handleEventDataChange();
        }
    }

    // eventData 변경 시 호출되는 메서드
    async handleEventDataChange() {
        if (this.isInitialized) {
            return;
        }

        try {
            this.isLoading = true;

            const objMessagingSession = this.eventData;
            const originalId = objMessagingSession.RiskAnalyzeReportId__c;

            // RiskAnalyzeReportId가 없으면 샘플 ID 사용
            this.riskAnalyzeReportId = originalId || 'a0PQy000001ebWXMAY';

            // 현재 컴포넌트 상태 저장
            await saveComponentStatus({
                messagingSessionId: objMessagingSession.Id,
                riskAnalyzeReportId: objMessagingSession.RiskAnalyzeReportId__c || this.riskAnalyzeReportId,
                type: 'PART_SELECT'
            });

            await this.loadAllData();

            this.isInitialized = true;

        } catch (error) {
            console.error('handleEventDataChange 오류:', error);
            this.isInitialized = false; // 오류 시 재시도 가능하도록
            this.showToast('Error', 'eventData 처리 중 오류가 발생했습니다: ' + error.message, 'error');
        }
    }

    // === 데이터 로딩 메서드 ===

    async loadAllData() {
        this.isLoading = true;
        try {
            // eventData와 riskAnalyzeReportId가 없으면 로딩 중단
            if (!this.eventData || Object.keys(this.eventData).length === 0) {
                return;
            }

            if (!this.riskAnalyzeReportId) {
                return;
            }

            // 1. 기준 ProductCode 조회
            await this.loadBaseProductCode();

            // 2. Product2 목록 및 선택된 부품 데이터 조회
            await this.loadProductsAndSelectedParts();

        } catch (error) {
            console.error('Data loading error:', error);
            this.showToast('Error', '데이터를 불러오는 중 오류가 발생했습니다: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadBaseProductCode() {
        this.isLoading = true;
        try {
            const result = await getBaseProductCode({
                riskAnalyzeReportId: this.effectiveRiskAnalyzeReportId
            });

            this.baseProductCode = result || 'Unknown Product';

        } catch (error) {
            console.error('Error getting base product code:', error);
            this.baseProductCode = 'Unknown Product';
        }
    }

    async loadProductsAndSelectedParts() {
        this.isLoading = true;
        try {
            // 캐시 무효화를 위해 현재 시간을 파라미터로 추가
            const timestamp = new Date().getTime();

            const result = await getRecommendedParts({
                riskAnalyzeReportId: this.effectiveRiskAnalyzeReportId,
                timestamp: timestamp // 캐시 우회용 파라미터
            });

            if (result.success && result.products && result.products.length > 0) {
                this.processProductsAndSelectedParts(result.products, result.selectedParts || []);
            } else {
                this.allProducts = [];
                this.filteredProducts = [];
                this.selectedParts = new Map();
            }

        } catch (error) {
            console.error('Error loading products and selected parts:', error);
            this.showToast('Error', '부품 데이터를 불러오는 중 오류가 발생했습니다: ' + error.message, 'error');
        }
    }

    processProductsAndSelectedParts(products, selectedParts) {
        // 1. SelectedPartItem을 Product ID 기준으로 Map 생성
        const selectedPartsMap = new Map();
        selectedParts.forEach(part => {
            selectedPartsMap.set(part.Product__c, part);
        });

        // 2. 선택된 부품 Map 생성 (UI 상태 관리용) - 먼저 초기화
        this.selectedParts = new Map();
        selectedParts.forEach(part => {
            this.selectedParts.set(part.Product__c, {
                productId: part.Product__c,
                quantity: part.Quantity__c,
                listPrice: part.ListPrice__c || 0
            });
        });

        // 3. Product2 기준으로 화면용 데이터 생성
        this.allProducts = products.map(product => {
            const selectedPart = selectedPartsMap.get(product.Id);
            const isSelected = selectedPart ? true : false;

            // 가격 결정 로직
            let displayPrice = 0;
            if (selectedPart && selectedPart.ListPrice__c != null) {
                // 선택된 부품이고 SelectedPartItem의 ListPrice가 있는 경우
                displayPrice = selectedPart.ListPrice__c;
            } else if (product.Price__c != null) {
                // Product2의 Price__c 사용
                displayPrice = product.Price__c;
            }

            return {
                // Product2 원본 데이터
                Id: product.Id,
                Name: product.Name,
                ProductCode: product.ProductCode,
                ProductClassification__c: product.ProductClassification__c,
                Replacement_Cycle__c: product.Replacement_Cycle__c,
                Purchase_Company__c: product.Purchase_Company__c,
                Shipping_Lead_Time__c: product.Shipping_Lead_Time__c,
                Quantity__c: product.Quantity__c,
                Price__c: product.Price__c,

                // UI 표시용 필드명 매핑
                PartCode__c: product.ProductCode,
                PartName__c: product.Name,
                ReplacementCycle__c: product.Replacement_Cycle__c,
                PurchaseCompany__c: product.Purchase_Company__c,
                ShippingLeadTime__c: product.Shipping_Lead_Time__c,
                StockQuantity__c: product.Quantity__c,

                // 선택 상태 및 수량 (중요: 여기서 올바른 맵핑)
                isSelected: isSelected,
                selectedQuantity: selectedPart ? selectedPart.Quantity__c : 1,
                ListPrice__c: displayPrice,

                // UI 상태
                formattedPrice: this.formatPrice(displayPrice),
                stockClass: this.getStockClass(product.Quantity__c),
                rowClass: isSelected ? 'table-row selected' : 'table-row'
            };
        });

        // 4. 필터링된 제품 업데이트
        this.updateFilteredProducts();
    }

    // === UI 업데이트 메서드 ===

    updateFilteredProducts() {
        this.filteredProducts = this.allProducts.map(product => {
            const isSelected = this.selectedParts.has(product.Id);
            const selectedPart = isSelected ? this.selectedParts.get(product.Id) : null;

            // 가격은 이미 processProductsAndSelectedParts에서 결정됨
            let displayPrice = product.ListPrice__c || 0;

            // 단, 현재 선택된 부품의 경우 UI 상에서 변경된 가격이 있으면 사용
            if (isSelected && selectedPart && selectedPart.listPrice != null) {
                displayPrice = selectedPart.listPrice;
            }

            return {
                ...product,
                isSelected: isSelected,
                stockClass: this.getStockClass(product.StockQuantity__c),
                rowClass: isSelected ? 'table-row selected' : 'table-row',
                formattedPrice: this.formatPrice(displayPrice),
                selectedQuantity: isSelected ? selectedPart.quantity : 1
            };
        });
    }

    filterProducts() {
        let filtered;
        if (!this.searchTerm) {
            filtered = [...this.allProducts];
        } else {
            filtered = this.allProducts.filter(product =>
                (product.ProductCode && product.ProductCode.toLowerCase().includes(this.searchTerm)) ||
                (product.Name && product.Name.toLowerCase().includes(this.searchTerm)) ||
                (product.Purchase_Company__c && product.Purchase_Company__c.toLowerCase().includes(this.searchTerm)) ||
                (product.ProductClassification__c && product.ProductClassification__c.toLowerCase().includes(this.searchTerm))
            );
        }

        this.filteredProducts = filtered.map(product => {
            const isSelected = this.selectedParts.has(product.Id);
            const selectedPart = isSelected ? this.selectedParts.get(product.Id) : null;

            // 가격 결정 로직
            let displayPrice = product.ListPrice__c || 0; // 기본적으로 Product2의 가격 사용

            // 선택된 부품인 경우 SelectedPartItem의 가격이 있으면 그것을 우선 사용
            if (isSelected && selectedPart && selectedPart.listPrice != null && selectedPart.listPrice > 0) {
                displayPrice = selectedPart.listPrice;
            }

            return {
                ...product,
                isSelected: isSelected,
                stockClass: this.getStockClass(product.StockQuantity__c),
                rowClass: isSelected ? 'table-row selected' : 'table-row',
                formattedPrice: this.formatPrice(displayPrice), // 모든 부품의 가격 표시
                selectedQuantity: isSelected ? selectedPart.quantity : 1
            };
        });
    }

    // === 이벤트 핸들러 ===

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterProducts();
    }

    handleRowClick(event) {
        const productId = event.currentTarget.dataset.partId;

        if (this.selectedParts.has(productId)) {
            // 선택 해제
            this.selectedParts.delete(productId);
        } else {
            // 선택 - 기본 수량 1로 설정
            const product = this.allProducts.find(p => p.Id === productId);
            const defaultPrice = product ? (product.Price__c || 0) : 0;

            this.selectedParts.set(productId, {
                productId: productId,
                quantity: 1,
                listPrice: defaultPrice
            });
        }

        this.updateFilteredProducts();
    }

    handleSelectAll(event) {
        if (event.target.checked) {
            // 모든 필터링된 제품을 선택
            this.filteredProducts.forEach(product => {
                if (!this.selectedParts.has(product.Id)) {
                    const defaultPrice = product.Price__c || 0;
                    this.selectedParts.set(product.Id, {
                        productId: product.Id,
                        quantity: 1,
                        listPrice: defaultPrice
                    });
                }
            });
        } else {
            // 현재 필터링된 제품들만 선택 해제
            this.filteredProducts.forEach(product => {
                if (this.selectedParts.has(product.Id)) {
                    this.selectedParts.delete(product.Id);
                }
            });
        }

        this.updateFilteredProducts();
    }

    handleQuantityChange(event) {
        const productId = event.target.dataset.partId;
        let newQuantity = parseInt(event.target.value) || 1;

        // 1-999 사이의 값으로 제한
        if (newQuantity < 1) newQuantity = 1;
        if (newQuantity > 999) newQuantity = 999;

        // 선택된 부품의 수량 업데이트
        if (this.selectedParts.has(productId)) {
            const selectedPart = this.selectedParts.get(productId);
            selectedPart.quantity = newQuantity;
            this.selectedParts.set(productId, selectedPart);
        } else {
            // 선택되지 않은 부품이면 선택 상태로 만들고 수량 설정
            const product = this.allProducts.find(p => p.Id === productId);
            const defaultPrice = product ? (product.Price__c || 0) : 0;

            this.selectedParts.set(productId, {
                productId: productId,
                quantity: newQuantity,
                listPrice: defaultPrice
            });
        }

        this.updateFilteredProducts();
    }

    handleNumberOnly(event) {
        const charCode = event.charCode;
        if (charCode < 48 || charCode > 57) {
            event.preventDefault();
        }
    }

    handleStopPropagation(event) {
        event.stopPropagation();
    }

    // === 액션 메서드 ===

    async handleSaveSelectedParts() {
        this.isLoading = true;

        try {
            const selectedPartsArray = this.getSelectedPartsData();
            const result = await saveSelectedParts({selectedParts: selectedPartsArray});

            if (result.success) {
                // 성공 메시지 표시
                this.showSuccessMessage = true;
                this.showToast('Success', result.message, 'success');

                // 3초 후 성공 메시지 숨김
                setTimeout(() => {
                    this.showSuccessMessage = false;
                }, 3000);

                // 저장 후 데이터 완전 새로고침
                await this.refreshAllData();

            } else {
                this.showToast('Error', result.message || '저장 중 오류가 발생했습니다.', 'error');
            }
        } catch (error) {
            console.error('Save error:', error);
            this.showToast('Error', '저장 중 오류가 발생했습니다: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateQuote() {
        this.isLoading = true;

        try {
            const selectedPartsArray = this.getSelectedPartsData();
            const result = await generateQuoteAndTransition({
                riskAnalyzeReportId: this.effectiveRiskAnalyzeReportId,
                selectedParts: selectedPartsArray
            });

            if (result.success) {
                this.showToast('Success', '견적서가 성공적으로 생성되었습니다.', 'success');
                //견적서 생성 후 데이터 완전 새로고침
                await this.refreshAllData();
            } else {
                this.showToast('Error', result.message || '견적서 생성 중 오류가 발생했습니다.', 'error');
            }

        } catch (error) {
            console.error('Quote generation error:', error);
            this.showToast('Error', '견적서 생성 중 오류가 발생했습니다: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async clearSelection() {
        try {
            this.isLoading = true;

            // 빈 배열로 저장 (모든 선택 해제)
            const result = await saveSelectedParts({selectedParts: []});

            if (result.success) {
                this.showToast('Success', '모든 선택이 해제되었습니다.', 'success');
                // 데이터 새로고침
                await this.refreshAllData();
            } else {
                this.showToast('Error', '선택 해제 중 오류가 발생했습니다.', 'error');
            }

        } catch (error) {
            console.error('Error clearing selection:', error);
            this.showToast('Error', '선택 해제 중 오류가 발생했습니다: ' + error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // === 새로고침 메서드 ===

    async refreshAllData() {
        try {
            // 1. 기존 상태 초기화
            this.selectedParts = new Map();
            this.allProducts = [];
            this.filteredProducts = [];

            // 2. 기준 ProductCode 새로고침
            await this.loadBaseProductCode();

            // 3. Product2 목록 및 선택된 부품 데이터 새로고침
            await this.loadProductsAndSelectedParts();

            // 4. 검색 필터 다시 적용 (검색어가 있는 경우)
            if (this.searchTerm) {
                this.filterProducts();
            }

        } catch (error) {
            console.error('Error during data refresh:', error);
            this.showToast('Error', '데이터 새로고침 중 오류가 발생했습니다: ' + error.message, 'error');
        }
    }

    // === 기존 메서드들 ===

    getSelectedPartsData() {
        const selectedPartsArray = [];
        const effectiveId = this.effectiveRiskAnalyzeReportId;

        this.selectedParts.forEach((selectedPart, productId) => {
            const partData = {
                riskAnalyzeReportId: effectiveId,
                productId: productId,
                listPrice: selectedPart.listPrice,
                quantity: selectedPart.quantity
            };
            selectedPartsArray.push(partData);
        });

        return selectedPartsArray;
    }

    getStockClass(stock) {
        if (stock === 0) return 'stock-out';
        if (stock <= 5) return 'stock-low';
        return 'stock-normal';
    }

    formatPrice(price) {
        if (price == null || price === '') return '0';
        return new Intl.NumberFormat('ko-KR').format(price);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}