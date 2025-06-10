/**
 * Typewriter Effect Library
 * 타이핑 애니메이션 효과를 제공하는 라이브러리
 */
window.TypewriterEffect = (function() {
    
    class Typewriter {
        constructor(options = {}) {
            this.speed = options.speed || 50; // 타이핑 속도 (밀리초)
            this.delay = options.delay || 0; // 시작 지연시간
            this.cursor = options.cursor || '|'; // 커서 문자
            this.showCursor = options.showCursor !== false; // 커서 표시 여부
            this.cursorBlinkSpeed = options.cursorBlinkSpeed || 500; // 커서 깜빡임 속도
            this.onComplete = options.onComplete || null; // 완료 콜백
            this.onCharacterTyped = options.onCharacterTyped || null; // 글자별 콜백
            
            this.isTyping = false;
            this.currentText = '';
            this.targetElement = null;
            this.cursorInterval = null;
            this.typingTimeout = null;
        }

        /**
         * 지정된 엘리먼트에 텍스트 타이핑 효과 적용
         * @param {HTMLElement} element - 대상 엘리먼트
         * @param {string} text - 타이핑할 텍스트
         */
        typeText(element, text) {
            if (this.isTyping) {
                this.stop();
            }

            this.targetElement = element;
            this.currentText = '';
            this.isTyping = true;

            // 초기 상태 설정
            element.innerHTML = this.showCursor ? this.cursor : '';
            
            // 커서 깜빡임 시작
            if (this.showCursor) {
                this.startCursorBlink();
            }

            // 지연 후 타이핑 시작
            this.typingTimeout = setTimeout(() => {
                this._typeCharacter(text, 0);
            }, this.delay);

            return this;
        }

        /**
         * 한 글자씩 타이핑하는 내부 메서드
         */
        _typeCharacter(fullText, index) {
            if (index >= fullText.length) {
                this.isTyping = false;
                if (this.onComplete) {
                    this.onComplete();
                }
                return;
            }

            const char = fullText[index];
            this.currentText += char;
            
            // HTML 태그가 포함된 경우 처리
            const displayText = this.currentText + (this.showCursor ? this.cursor : '');
            this.targetElement.innerHTML = displayText;

            // 글자별 콜백 실행
            if (this.onCharacterTyped) {
                this.onCharacterTyped(char, this.currentText);
            }

            // 다음 글자 타이핑 예약
            this.typingTimeout = setTimeout(() => {
                this._typeCharacter(fullText, index + 1);
            }, this._getTypingSpeed(char));
        }

        /**
         * 글자별 타이핑 속도 계산 (구두점에서 약간 정지)
         */
        _getTypingSpeed(char) {
            const pauseChars = ['.', '!', '?', ',', ';', ':'];
            const longPauseChars = ['.', '!', '?'];
            
            if (longPauseChars.includes(char)) {
                return this.speed * 3;
            } else if (pauseChars.includes(char)) {
                return this.speed * 2;
            }
            
            // 랜덤한 변화로 더 자연스럽게
            return this.speed + Math.random() * 20 - 10;
        }

        /**
         * 커서 깜빡임 시작
         */
        startCursorBlink() {
            this.stopCursorBlink();
            
            let showCursor = true;
            this.cursorInterval = setInterval(() => {
                if (!this.isTyping && this.targetElement) {
                    const baseText = this.currentText;
                    this.targetElement.innerHTML = baseText + (showCursor ? this.cursor : '');
                    showCursor = !showCursor;
                }
            }, this.cursorBlinkSpeed);
        }

        /**
         * 커서 깜빡임 중지
         */
        stopCursorBlink() {
            if (this.cursorInterval) {
                clearInterval(this.cursorInterval);
                this.cursorInterval = null;
            }
        }

        /**
         * 타이핑 효과 즉시 완료
         */
        complete() {
            if (this.isTyping && this.targetElement) {
                this.stop();
                // 전체 텍스트 즉시 표시
                this.targetElement.innerHTML = this.currentText;
                if (this.onComplete) {
                    this.onComplete();
                }
            }
        }

        /**
         * 타이핑 효과 중지
         */
        stop() {
            this.isTyping = false;
            this.stopCursorBlink();
            
            if (this.typingTimeout) {
                clearTimeout(this.typingTimeout);
                this.typingTimeout = null;
            }
        }

        /**
         * 텍스트 지우기 효과
         */
        eraseText(callback) {
            if (!this.targetElement || this.currentText.length === 0) {
                if (callback) callback();
                return;
            }

            const eraseSpeed = this.speed / 2;
            const eraseStep = () => {
                this.currentText = this.currentText.slice(0, -1);
                this.targetElement.innerHTML = this.currentText + (this.showCursor ? this.cursor : '');
                
                if (this.currentText.length > 0) {
                    setTimeout(eraseStep, eraseSpeed);
                } else {
                    if (callback) callback();
                }
            };

            eraseStep();
        }

        /**
         * 설정 업데이트
         */
        updateSettings(newOptions) {
            Object.assign(this, newOptions);
            return this;
        }
    }

    // 유틸리티 함수들
    const utils = {
        /**
         * 여러 텍스트를 순차적으로 타이핑
         */
        typeSequence(element, texts, options = {}) {
            const typewriter = new Typewriter(options);
            let currentIndex = 0;

            const typeNext = () => {
                if (currentIndex >= texts.length) {
                    if (options.onAllComplete) {
                        options.onAllComplete();
                    }
                    return;
                }

                const currentText = texts[currentIndex];
                typewriter.typeText(element, currentText);
                
                typewriter.onComplete = () => {
                    currentIndex++;
                    if (currentIndex < texts.length) {
                        setTimeout(() => {
                            if (options.eraseBeforeNext) {
                                typewriter.eraseText(() => {
                                    setTimeout(typeNext, options.pauseBetween || 500);
                                });
                            } else {
                                setTimeout(typeNext, options.pauseBetween || 1000);
                            }
                        }, options.pauseAfterComplete || 1000);
                    } else {
                        if (options.onAllComplete) {
                            options.onAllComplete();
                        }
                    }
                };
            };

            typeNext();
            return typewriter;
        },

        /**
         * HTML 요소의 기존 텍스트를 타이핑 효과로 교체
         */
        replaceWithTyping(element, newText, options = {}) {
            const originalText = element.textContent || element.innerText;
            const typewriter = new Typewriter(options);
            
            // 기존 텍스트 지우기
            typewriter.currentText = originalText;
            typewriter.targetElement = element;
            
            typewriter.eraseText(() => {
                setTimeout(() => {
                    typewriter.typeText(element, newText);
                }, options.pauseBetweenErase || 300);
            });

            return typewriter;
        }
    };

    // Public API
    return {
        Typewriter: Typewriter,
        create: function(options) {
            return new Typewriter(options);
        },
        typeSequence: utils.typeSequence,
        replaceWithTyping: utils.replaceWithTyping
    };
})();