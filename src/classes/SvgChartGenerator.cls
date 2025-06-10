/************************************************************************************
* File Name : SvgChartGenerator.cls
* Author : 최준석
* Date : 2025-06-03
* Description :
* Modification Log
* ===================================================================================
* Ver       Date        Author      Modification
* ===================================================================================
1.0         2025-06-03  최준석         Create
*************************************************************************************/
public class SvgChartGenerator {

    // 차트 기본 설정
    private static final String DEFAULT_FONT = 'Arial,sans-serif';
    private static final String DEFAULT_BG_COLOR = '#f8f9fa';
    private static final String DEFAULT_BORDER_COLOR = '#dee2e6';

    // 색상 팔레트
    private static final List<String> CHART_COLORS = new List<String>{
            '#ff6384', '#36a2eb', '#ffce56', '#4bc0c0', '#9966ff',
            '#ff9f40', '#c9cbcf', '#20c997', '#e83e8c', '#17a2b8' // 더 다양한 색상 추가
    };

    /**
     * Map에서 숫자 값을 안전하게 Integer로 가져오는 헬퍼 메서드
     */
    private static Integer getSafeIntegerValue(Map<String, Object> dataMap, String key, Integer defaultValue) {
        if (dataMap != null && dataMap.containsKey(key)) {
            Object value = dataMap.get(key);
            if (value == null) {
                return defaultValue;
            }
            if (value instanceof Integer) {
                return (Integer) value;
            } else if (value instanceof Decimal) {
                return ((Decimal) value).intValue();
            } else if (value instanceof Long) {
                return ((Long)value).intValue();
            } else if (value instanceof String) {
                try {
                    return Integer.valueOf((String)value);
                } catch (Exception e) {
                    // System.debug(LoggingLevel.WARN, 'SvgChartGenerator: Could not parse String to Integer for key ' + key + ': ' + value);
                    return defaultValue;
                }
            }
            // System.debug(LoggingLevel.WARN, 'SvgChartGenerator: Unexpected type for key ' + key + ': ' + value.getType());
        }
        return defaultValue;
    }

    /**
     * Map에서 숫자 값을 안전하게 Decimal로 가져오는 헬퍼 메서드
     */
    private static Decimal getSafeDecimalValue(Map<String, Object> dataMap, String key, Decimal defaultValue) {
        if (dataMap != null && dataMap.containsKey(key)) {
            Object value = dataMap.get(key);
            if (value == null) {
                return defaultValue;
            }
            if (value instanceof Decimal) {
                return (Decimal) value;
            } else if (value instanceof Integer) {
                return (Decimal) value; // Integer를 Decimal로 변환
            } else if (value instanceof Long) {
                return (Decimal) value; // Long을 Decimal로 변환
            } else if (value instanceof String) {
                try {
                    return Decimal.valueOf((String)value);
                } catch (Exception e) {
                    // System.debug(LoggingLevel.WARN, 'SvgChartGenerator: Could not parse String to Decimal for key ' + key + ': ' + value);
                    return defaultValue;
                }
            }
            // System.debug(LoggingLevel.WARN, 'SvgChartGenerator: Unexpected type for key ' + key + ': ' + value.getType());
        }
        return defaultValue;
    }


    /**
     * 각도를 라디안으로 변환하는 유틸리티 메서드
     */
    private static Double toRadians(Double degrees) {
        return degrees * Math.PI / 180.0;
    }

    /**
     * SVG 컨테이너를 생성하는 유틸리티 메서드
     */
    private static String createSvgContainer(Integer width, Integer height, String title) {
        String svg = '<svg width="' + width + '" height="' + height + '" xmlns="http://www.w3.org/2000/svg" font-family="' + DEFAULT_FONT + '">';
        svg += '<defs><style type="text/css"><![CDATA['; // CDATA 추가
        svg += '.label{font-size:12px;fill:#333;}';
        svg += '.label-small{font-size:10px;fill:#555;}';
        svg += '.title{font-size:14px;fill:#333;font-weight:bold;text-anchor:middle;}'; // text-anchor 추가
        svg += '.grid{stroke:#e0e0e0;stroke-dasharray:2,2;}';
        svg += '.bar{stroke-width:1;}'; // 기본 bar 테두리 두께
        svg += '.slice{stroke:#fff;stroke-width:1;}'; // 파이 조각 테두리 두께 1로 줄임
        svg += '.line{fill:none;stroke-width:2;}';
        svg += ']]></style></defs>';
        svg += '<rect width="100%" height="100%" fill="' + DEFAULT_BG_COLOR + '"/>'; // 테두리 여기서 제거, 필요시 각 차트에서 추가

        if (String.isNotBlank(title)) {
            svg += '<text x="' + (width/2) + '" y="25" class="title">' + title + '</text>';
        }
        return svg;
    }

    /**
     * 범례를 생성하는 유틸리티 메서드
     */
    private static String createLegend(List<LegendItem> items, Integer x, Integer y, Integer itemWidth) {
        String legend = '';
        Integer currentY = y;
        Integer rectSize = 10; // 범례 사각형 크기
        Integer textOffsetX = rectSize + 5; // 텍스트 오프셋

        for (LegendItem item : items) {
            legend += '<rect x="' + x + '" y="' + (currentY - rectSize/2 -1) + '" width="' + rectSize + '" height="' + rectSize + '" fill="' + item.color + '"/>';
            legend += '<text x="' + (x + textOffsetX) + '" y="' + currentY + '" class="label-small" dominant-baseline="middle">' + item.label + '</text>';
            currentY += 18; // 범례 항목 간 간격
        }
        return legend;
    }

    /**
     * 막대 차트를 생성하는 범용 메서드
     */
    private static String createBarChart(List<BarData> data, ChartConfig config) {
        String svg = createSvgContainer(config.width, config.height, config.title);

        Integer barY = config.startY;
        Decimal maxValueDecimal = 0.0;

        for (BarData bar : data) {
            if (bar.value > maxValueDecimal) maxValueDecimal = bar.value;
        }
        if (maxValueDecimal == 0) maxValueDecimal = 1.0;

        // X축 선 (0 라인)
        svg += '<line x1="' + config.barStartX + '" y1="' + (config.startY - config.barSpacing + config.barHeight) + '" x2="' + config.barStartX + '" y2="' + (config.startY + (data.size() * config.barSpacing) - config.barSpacing + config.barHeight) + '" class="grid"/>';


        for (BarData bar : data) {
            Integer barWidth = Math.round(bar.value * config.maxBarWidth / maxValueDecimal);
            if (barWidth < 0) barWidth = 0; // 음수 너비 방지

            svg += '<rect x="' + config.barStartX + '" y="' + barY + '" width="' + barWidth + '" height="' + config.barHeight + '" fill="' + bar.color + '" class="bar" stroke="' + bar.color + '"/>'; // stroke 색상을 fill과 동일하게
            svg += '<text x="' + (config.barStartX - 10) + '" y="' + (barY + config.barHeight/2) + '" text-anchor="end" dominant-baseline="middle" class="label">' + bar.label + '</text>';
            svg += '<text x="' + (config.barStartX + barWidth + 5) + '" y="' + (barY + config.barHeight/2) + '" dominant-baseline="middle" class="label-small">' + bar.displayValue + '</text>';

            barY += config.barSpacing;
        }

        svg += '</svg>';
        return svg;
    }

    /**
     * 파이 차트를 생성하는 범용 메서드
     */
    private static String createPieChart(List<PieData> data, ChartConfig config) {
        String svg = createSvgContainer(config.width, config.height, config.title);

        Double currentAngle = -90.0; // 12시 방향에서 시작
        List<LegendItem> legendItems = new List<LegendItem>();
        Decimal cumulativePercentage = 0.0;

        for (Integer i = 0; i < data.size(); i++) {
            PieData pie = data[i];
            if (pie.percentage == 0) continue; // 0%인 항목은 그리지 않음

            cumulativePercentage += pie.percentage;
            Double sweepAngle = pie.percentage.doubleValue() * 360.0 / 100.0;
            Double endAngle = currentAngle + sweepAngle;

            Double startX = config.centerX + config.radius * Math.cos(toRadians(currentAngle));
            Double startY = config.centerY + config.radius * Math.sin(toRadians(currentAngle));
            Double endX = config.centerX + config.radius * Math.cos(toRadians(endAngle));
            Double endY = config.centerY + config.radius * Math.sin(toRadians(endAngle));

            Integer largeArcFlag = sweepAngle > 180 ? 1 : 0;
            String color = CHART_COLORS[Math.mod(i, CHART_COLORS.size())];

            String pathData = 'M ' + config.centerX + ',' + config.centerY +
                    ' L ' + startX.intValue() + ',' + startY.intValue() +
                    ' A ' + config.radius + ',' + config.radius + ' 0 ' + largeArcFlag + ',1 ' +
                    endX.intValue() + ',' + endY.intValue() + ' Z';
            svg += '<path d="' + pathData + '" fill="' + color + '" class="slice"/>';

            // 라벨 위치 계산 (조각의 중간 각도)
            Double labelAngle = currentAngle + sweepAngle / 2;
            Double labelX = config.centerX + config.radius * 0.7 * Math.cos(toRadians(labelAngle));
            Double labelY = config.centerY + config.radius * 0.7 * Math.sin(toRadians(labelAngle));
            if (pie.percentage >= 10) { // 일정 비율 이상일 때만 차트 내부에 라벨 표시
                svg += '<text x="' + labelX.intValue() + '" y="' + labelY.intValue() + '" text-anchor="middle" dominant-baseline="middle" fill="#fff" font-size="10px">' + pie.percentage.setScale(0) + '%</text>';
            }

            legendItems.add(new LegendItem(pie.label + ' (' + pie.percentage.setScale(1) + '%)', color));
            currentAngle = endAngle;
        }

        if (cumulativePercentage < 100 && cumulativePercentage > 0) { // 기타 항목 처리 (100% 미만일 시)
            // 로직 추가 가능
        }


        if (config.showLegend && !legendItems.isEmpty()) {
            svg += createLegend(legendItems, config.legendX, config.legendY, 100);
        }

        svg += '</svg>';
        return svg;
    }

    /**
     * 위험도 추이 차트를 생성합니다.
     */
    public static String generateRiskTrendChart(Map<String, Object> data) {
        if (data == null) return '';

        Integer current = getSafeIntegerValue(data, 'current', 50);
        Integer month1 = getSafeIntegerValue(data, 'month1', 50);
        Integer month2 = getSafeIntegerValue(data, 'month2', 50);

        String svg = createSvgContainer(380, 200, '위험도 변화 추이'); // 크기 약간 축소

        Integer paddingLeft = 60, paddingTop = 40, paddingRight = 20, paddingBottom = 40;
        Integer chartWidth = 380 - paddingLeft - paddingRight;
        Integer chartHeight = 200 - paddingTop - paddingBottom;

        // Y축 (0-100)
        svg += '<line x1="' + paddingLeft + '" y1="' + paddingTop + '" x2="' + paddingLeft + '" y2="' + (paddingTop + chartHeight) + '" class="grid"/>';
        svg += '<text x="' + (paddingLeft - 8) + '" y="' + paddingTop + '" text-anchor="end" dominant-baseline="middle" class="label-small">100</text>';
        svg += '<text x="' + (paddingLeft - 8) + '" y="' + (paddingTop + chartHeight/2) + '" text-anchor="end" dominant-baseline="middle" class="label-small">50</text>';
        svg += '<text x="' + (paddingLeft - 8) + '" y="' + (paddingTop + chartHeight) + '" text-anchor="end" dominant-baseline="middle" class="label-small">0</text>';

        // X축
        Integer xAxisY = paddingTop + chartHeight;
        svg += '<line x1="' + paddingLeft + '" y1="' + xAxisY + '" x2="' + (paddingLeft + chartWidth) + '" y2="' + xAxisY + '" class="grid"/>';

        Decimal scaleFactor = (Decimal)chartHeight / 100.0;
        Integer yOrigin = paddingTop + chartHeight;

        Integer x1 = paddingLeft + chartWidth / 4;
        Integer y1 = yOrigin - Math.round(current * scaleFactor);
        Integer x2 = paddingLeft + chartWidth / 2;
        Integer y2 = yOrigin - Math.round(month1 * scaleFactor);
        Integer x3 = paddingLeft + chartWidth * 3 / 4;
        Integer y3 = yOrigin - Math.round(month2 * scaleFactor);

        svg += '<polyline points="' + x1 + ',' + y1 + ' ' + x2 + ',' + y2 + ' ' + x3 + ',' + y3 + '" class="line" stroke="#dc3545"/>';
        svg += '<circle cx="' + x1 + '" cy="' + y1 + '" r="3" fill="#dc3545" class="slice"/>';
        svg += '<circle cx="' + x2 + '" cy="' + y2 + '" r="3" fill="#dc3545" class="slice"/>';
        svg += '<circle cx="' + x3 + '" cy="' + y3 + '" r="3" fill="#dc3545" class="slice"/>';

        Integer labelY = xAxisY + 15;
        svg += '<text x="' + x1 + '" y="' + labelY + '" text-anchor="middle" class="label-small">현재(' + current + ')</text>';
        svg += '<text x="' + x2 + '" y="' + labelY + '" text-anchor="middle" class="label-small">1개월후(' + month1 + ')</text>';
        svg += '<text x="' + x3 + '" y="' + labelY + '" text-anchor="middle" class="label-small">2개월후(' + month2 + ')</text>';

        svg += '</svg>';
        return svg;
    }

    /**
     * 부품별 상태 차트를 생성합니다. (수평 막대 차트)
     */
    public static String generateComponentStatusChart(List<Object> data) {
        if (data == null || data.isEmpty()) return '';

        List<BarData> barDataList = new List<BarData>();
        for (Object item : data) {
            Map<String, Object> component = (Map<String, Object>) item;
            String name = (String) component.get('name');
            Decimal statusValue = getSafeDecimalValue(component, 'status', 50.0);

            String color = statusValue >= 80 ? CHART_COLORS[7] : (statusValue >= 60 ? CHART_COLORS[2] : CHART_COLORS[0]);
            barDataList.add(new BarData(name, statusValue, statusValue.setScale(0) + '%', color));
        }

        ChartConfig config = new ChartConfig();
        config.width = 420;
        config.barSpacing = 35;
        config.barHeight = 18;
        config.startY = 50; // 제목 아래 시작
        config.height = config.startY + (barDataList.size() * config.barSpacing) + 10; // 높이 동적 조절
        if(barDataList.isEmpty()) config.height = 200;

        config.title = '주요 부품 상태 (%)';
        config.barStartX = 120; // 라벨 너비 고려
        config.maxBarWidth = (Decimal)(config.width - config.barStartX - 60); // 값 표시 공간 고려

        return createBarChart(barDataList, config);
    }


    /**
     * 고장 유형별 비용 파이 차트를 생성합니다.
     */
    public static String generateFailureCostChart(List<Object> data) {
        if (data == null || data.isEmpty()) return '';

        List<PieData> pieDataList = new List<PieData>();
        for (Object item : data) {
            Map<String, Object> failure = (Map<String, Object>) item;
            String type = (String) failure.get('type');
            Decimal percentageValue = getSafeDecimalValue(failure, 'percentage', 0.0);
            pieDataList.add(new PieData(type, percentageValue));
        }

        ChartConfig config = new ChartConfig();
        config.width = 400;
        Integer legendApproxHeight = pieDataList.size() * 18;
        config.height = 220 + (pieDataList.size() > 5 ? legendApproxHeight - 90 : 0) ; // 기본 높이 + 범례 길이에 따른 추가 높이
        config.title = '고장 유형별 예상 비용 (%)';
        config.centerX = 130;
        config.centerY = 130;
        config.radius = 75;
        config.showLegend = true;
        config.legendX = config.centerX + config.radius + 20;
        config.legendY = 50;

        return createPieChart(pieDataList, config);
    }


    /**
     * 수리 방식별 비용 비교 차트를 생성합니다. (스택형 막대 차트로 변경)
     */
    public static String generateMaintenanceCostChart(List<Object> data) {
        if (data == null || data.isEmpty()) return '';

        Integer containerWidth = 500;
        Integer containerHeight = 320;
        String svg = createSvgContainer(containerWidth, containerHeight, '수리 방식별 비용 비교 (단위: 만원)');

        Decimal maxTotalCost = 0.0;
        List<Map<String, Object>> typedData = new List<Map<String, Object>>();

        for (Object item : data) {
            Map<String, Object> repair = (Map<String, Object>) item;
            typedData.add(repair);
            Decimal selfCost = getSafeDecimalValue(repair, 'selfRepair', 0.0);
            Decimal outsideCost = getSafeDecimalValue(repair, 'outsideRepair', 0.0);
            Decimal totalCost = selfCost + outsideCost; // + 연산자 사용
            if (totalCost > maxTotalCost) {
                maxTotalCost = totalCost;
            }
        }
        if (maxTotalCost == 0) maxTotalCost = 100.0; // 기본 최대값 설정 (0 방지)

        Integer paddingLeft = 70, paddingTop = 50, paddingRight = 130, paddingBottom = 50; // 오른쪽 범례 공간 확보
        Integer chartWidth = containerWidth - paddingLeft - paddingRight;
        Integer chartHeight = containerHeight - paddingTop - paddingBottom;

        Integer numberOfGroups = typedData.size();
        if (numberOfGroups == 0) numberOfGroups = 1;

        Integer barGroupTotalWidth = chartWidth / numberOfGroups; // 각 그룹이 차지하는 전체 너비
        Integer barWidth = Math.min(40, barGroupTotalWidth * 2 / 3); // 막대 너비, 최대 40
        Integer barGroupSpacing = barGroupTotalWidth - barWidth; // 막대와 다음 그룹 시작까지의 간격

        // Y축
        Integer yAxisStartX = paddingLeft;
        Integer yAxisStartY = paddingTop;
        Integer yAxisEndY = paddingTop + chartHeight;
        svg += '<line x1="' + yAxisStartX + '" y1="' + yAxisStartY + '" x2="' + yAxisStartX + '" y2="' + yAxisEndY + '" class="grid"/>';

        for(Integer i=0; i<=4; i++) { // Y축 눈금 5개 (0, 25%, 50%, 75%, 100%)
            Decimal tickValue = maxTotalCost * i / 4;
            Integer tickY = yAxisEndY - Math.round( (tickValue / maxTotalCost) * chartHeight );
            svg += '<text x="' + (yAxisStartX - 8) + '" y="' + tickY + '" text-anchor="end" dominant-baseline="middle" class="label-small">' + tickValue.setScale(0) + '</text>';
            svg += '<line x1="' + (yAxisStartX - 4) + '" y1="' + tickY + '" x2="' + yAxisStartX + '" y2="' + tickY + '" class="grid"/>'; // 짧은 눈금선
        }

        // X축
        Integer xAxisStartY = yAxisEndY;
        svg += '<line x1="' + yAxisStartX + '" y1="' + xAxisStartY + '" x2="' + (paddingLeft + chartWidth) + '" y2="' + xAxisStartY + '" class="grid"/>';

        Integer currentX = paddingLeft + (barGroupTotalWidth - barWidth) / 2;

        for (Map<String, Object> repair : typedData) {
            String type = (String) repair.get('type');
            Decimal selfCost = getSafeDecimalValue(repair, 'selfRepair', 0.0);
            Decimal outsideCost = getSafeDecimalValue(repair, 'outsideRepair', 0.0);

            Integer outsideHeight = Math.round((outsideCost / maxTotalCost) * chartHeight);
            Integer selfHeight = Math.round((selfCost / maxTotalCost) * chartHeight);

            // 외부수리 (아래)
            svg += '<rect x="' + currentX + '" y="' + (xAxisStartY - outsideHeight) + '" width="' + barWidth + '" height="' + outsideHeight + '" fill="' + CHART_COLORS[1] + '" class="bar" stroke="'+CHART_COLORS[1]+'"/>';
            // 자가수리 (위, 스택)
            svg += '<rect x="' + currentX + '" y="' + (xAxisStartY - outsideHeight - selfHeight) + '" width="' + barWidth + '" height="' + selfHeight + '" fill="' + CHART_COLORS[0] + '" class="bar" stroke="'+CHART_COLORS[0]+'"/>';

            Decimal totalForBar = selfCost + outsideCost;
            Integer totalHeight = selfHeight + outsideHeight;
            if (totalForBar > 0) {
                svg += '<text x="' + (currentX + barWidth / 2) + '" y="' + Math.max(paddingTop, xAxisStartY - totalHeight - 6) + '" text-anchor="middle" class="label-small">' + totalForBar.setScale(0) + '</text>';
            }

            svg += '<text x="' + (currentX + barWidth / 2) + '" y="' + (xAxisStartY + 15) + '" text-anchor="middle" class="label-small">' + type + '</text>';

            currentX += barGroupTotalWidth;
        }

        List<LegendItem> legendItems = new List<LegendItem>{
                new LegendItem('자가수리', CHART_COLORS[0]),
                new LegendItem('외부수리', CHART_COLORS[1])
        };
        svg += createLegend(legendItems, paddingLeft + chartWidth + 15, paddingTop, 100);

        svg += '</svg>';
        return svg;
    }


    // 내부 데이터 구조 클래스들
    private class BarData {
        String label;
        Decimal value; // Integer에서 Decimal로 변경됨
        String displayValue;
        String color;

        BarData(String label, Decimal value, String displayValue, String color) {
            this.label = label;
            this.value = value;
            this.displayValue = displayValue;
            this.color = color;
        }
    }

    private class PieData {
        String label;
        Decimal percentage; // Integer에서 Decimal로 변경됨

        PieData(String label, Decimal percentage) {
            this.label = label;
            this.percentage = percentage;
        }
    }

    private class LegendItem {
        String label;
        String color;

        LegendItem(String label, String color) {
            this.label = label;
            this.color = color;
        }
    }

    // 차트 구성 기본값 클래스
    private class ChartConfig {
        Integer width = 400;
        Integer height = 300;
        String title = '';

        // Bar chart specific
        Integer startY = 50;
        Integer barHeight = 20;
        Integer barSpacing = 30;
        Integer barStartX = 120; // 라벨 표시를 위한 충분한 왼쪽 여백
        Decimal maxBarWidth = 180.0; // 막대 최대 너비 (전체 너비 - 시작 X - 오른쪽 여백)

        // Pie chart specific
        Integer centerX = 150; // 기본값, 필요시 조정
        Integer centerY = 150; // 기본값, 필요시 조정
        Integer radius = 70;   // 기본값, 필요시 조정
        Boolean showLegend = true; // 범례 표시 여부 기본값 true
        Integer legendX = 300; // 범례 시작 X 위치
        Integer legendY = 50;  // 범례 시작 Y 위치
    }
}