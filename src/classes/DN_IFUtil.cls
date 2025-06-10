/************************************************************************************
 * File Name        : DN_IFUtil.cls
 * Author           : 최준석
 * Date             : 2025-05-25
 * Description      :
 * Modification Log
 * ===================================================================================
 * Ver      Date            Author          Modification
 * ===================================================================================
   1.0      2025-05-25      최준석
*************************************************************************************/

public class DN_IFUtil {
    public static Datetime parseIso8601WithOffset(String isoString) {
        if (isoString == null) return null;
        // 지원 포맷: yyyy-MM-dd'T'HH:mm:ss±HH:mm (ex: 2025-05-19T07:52:00-04:00)
        Pattern p = Pattern.compile('^(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}:\\d{2})([+-])(\\d{2}):(\\d{2})$');
        Matcher m = p.matcher(isoString);
        if (!m.matches()) throw new IllegalArgumentException('날짜 형식 오류: ' + isoString);

        String datePart = m.group(1);
        String timePart = m.group(2);
        String sign = m.group(3);
        Integer offsetH = Integer.valueOf(m.group(4));
        Integer offsetM = Integer.valueOf(m.group(5));
        Datetime dt = Datetime.valueOfGmt(datePart + ' ' + timePart);
        Integer offsetTotal = offsetH * 60 + offsetM;
        if (sign == '+') offsetTotal = -offsetTotal; // Apex 기준
        return dt.addMinutes(offsetTotal);
    }

    public static Datetime parseIso8601Z(String isoString) {
        if (isoString == null) return null;
        // 지원 포맷: yyyy-MM-dd'T'HH:mm:ssZ (ex: 2025-05-19T15:55:00Z)
        String replaced = isoString.replace('T', ' ').replace('Z', '');
        return Datetime.valueOfGmt(replaced);
    }

    public static Datetime parseDatetimeSeparated(String dateStr, String timeStr) {
        if (dateStr == null || timeStr == null) return null;
        // Apex는 valueOfGmt("yyyy-MM-dd HH:mm:ss") 지원
        return Datetime.valueOfGmt(dateStr + ' ' + timeStr);
    }

    public static Time parseTimeOnly(String timeStr) {
        if (timeStr == null) return null;
        // 지원 포맷: HH:mm:ss
        List<String> parts = timeStr.split(':');
        if (parts.size() != 3) throw new IllegalArgumentException('시간 형식 오류: ' + timeStr);
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]), 0);
    }
    
    public static Date parseDateOnly(String dateStr) {
        if (dateStr == null) return null;
        // 지원 포맷: yyyy-MM-dd
        return Date.valueOf(dateStr);
    }

    public static void waitForSeconds(Integer seconds) {
        Long startTime = System.currentTimeMillis();
        Long endTime = startTime + (seconds * 1000);
        while (System.currentTimeMillis() < endTime) {}
    }
}