/*
 * Created by Jiae.Tak on 2025-05-23.
 */

import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CSOrderListCmp extends NavigationMixin(LightningElement)  {
    /* 데이터 구조 예시*/
    @track productData = {
        productName: 'WIZ0050C',
        imageUrl : 'productTest.png',
        purchaseDate: '2016-12-05',
        totalRepairCount: 8,
        visitServiceCount: 3,
        averageWaitDays: 10,
        lastRepairDate: '2025-05-03',
        parts: [
            {
                id : 'id1',
                name: '통신포트',
                price: 339900,
                quantity: 1,
                imageUrl: 'test1.png',
                repairCount: 8,
                visitCount: 3,
                waitDays: 10,
                lastRepair: '2024-12-03'
            },
            {
                id : 'id2',
                name: 'PLC',
                price: 1239900,
                quantity: 3,
                imageUrl: 'test2.png',
                repairCount: 1,
                visitCount: 1,
                waitDays: 2,
                lastRepair: '2023-04-03'
            }
        ]
    };
    renderedCallback() {
        console.log('orderList component ');
    }
    get formattedParts() {
        return this.productData.parts.map((part) => {
            return {
                ...part,
                formattedPrice: part.price.toLocaleString() + '원',
                formattedQuantity: part.quantity + '개',
                cssClass: part.repairCount >= 5 ? 'order-item-highlight' : 'order-item'
            };
        });
    }

    async doResult() {
        try {
            const params = [{ redirect: 'test' }]; // dummy input
            const result = await doTest(params); // Apex 호출
            console.log('doTest result:', result);

            if (result && result.length > 0 && result[0].isRedirect) {
                this.handleStartChat(); // 페이지 이동
            } else {
                console.log('isRedirect가 false거나 응답 없음');
            }
        } catch (error) {
            console.error('Apex 호출 실패:', error);
        }
    }

    handleStartChat() {
        // 확실한 이동을 위해 window.location.href 사용
        window.location.href = '/s/faulttypelist';
    }

//    handleStartChat(){
//            console.log('Navigating to /faulttypelist');
//
//        this[NavigationMixin.Navigate]({
//            type: 'standard__webPage',
//            attributes: {
//                url: `/faulttypelist`
//            }
//        });
//    }

}