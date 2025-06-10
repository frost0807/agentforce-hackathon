/**
 * Created by Jiae.Tak on 2025-06-08.
 */

import { LightningElement, track, api } from 'lwc';
import spinnerImageUrl from '@salesforce/resourceUrl/spinnerImage';

export default class LwcGlobalSpinner extends LightningElement {
    spinnerImageUrl = spinnerImageUrl;
    @track dotsText = '';
    dotInterval;

    // 컴포넌트가 DOM에 삽입될 때 애니메이션 시작
    connectedCallback() {
        this.startDotAnimation();
    }

    // 컴포넌트가 DOM에서 제거될 때 애니메이션 중지
    disconnectedCallback() {
        this.stopDotAnimation();
    }

    startDotAnimation() {
        if (this.dotInterval) {
            return; // 이미 실행 중이면 다시 시작하지 않음
        }
        let dotCount = 0;
        this.dotInterval = setInterval(() => {
            dotCount = (dotCount + 1) % 5; // 0, 1, 2, 3, 4 반복 (0개부터 4개까지)
            this.dotsText = '.'.repeat(dotCount);
        }, 300); // 0.3초마다 업데이트
    }

    stopDotAnimation() {
        if (this.dotInterval) {
            clearInterval(this.dotInterval);
            this.dotInterval = null;
            this.dotsText = '';
        }
    }
}