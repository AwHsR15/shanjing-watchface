import Toybox.Lang;

// 节气与农历。数据表由 generate_assets.py 生成（CalData），覆盖 2024–2050。
module Cal {
    const TERMS = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
                   "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"];
    const MONTHS = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"];
    const DIGITS = ["一", "二", "三", "四", "五", "六", "七", "八", "九"];
    const TENS = ["初", "十", "廿"];
    const CUM = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

    function isLeapYear(y as Number) as Boolean { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0; }

    function dayOfYear(y as Number, m as Number, d as Number) as Number {
        return CUM[m - 1] + d + ((m > 2 && isLeapYear(y)) ? 1 : 0);
    }

    // solar term falling on this date, or null
    function term(y as Number, m as Number, d as Number) as String or Null {
        var words = CalData.TERMS;
        if (y < CalData.TERM_FIRST || y >= CalData.TERM_FIRST + words.size() / 3) { return null; }
        var base = (y - CalData.TERM_FIRST) * 3;
        for (var j = (m - 1) * 2; j < m * 2; j++) {
            var day = ((words[base + (j >> 3)] >> (3 * (j & 7))) & 7) + (j % 2 == 1 ? 18 : 3);
            if (day == d) { return TERMS[j]; }
        }
        return null;
    }

    // [month, day, isLeapMonth] or null outside the table
    function lunar(y as Number, m as Number, d as Number) as Array or Null {
        var table = CalData.LUNAR;
        var idx = y - CalData.LUNAR_FIRST;
        if (idx < 0 || idx >= table.size()) { return null; }
        var off = dayOfYear(y, m, d) - (((table[idx] >> 17) & 31) + 21);
        if (off < 0) {
            idx -= 1;
            if (idx < 0) { return null; }
            off = dayOfYear(y, m, d) + (isLeapYear(y - 1) ? 366 : 365) - (((table[idx] >> 17) & 31) + 21);
        }
        var w = table[idx];
        var leap = (w >> 13) & 15;
        var month = 1;
        for (var i = 0; i < (leap > 0 ? 13 : 12); i++) {
            var len = ((w >> i) & 1) == 1 ? 30 : 29;
            var isLeap = leap > 0 && i == leap;
            if (off < len) { return [isLeap ? leap : month, off + 1, isLeap]; }
            off -= len;
            if (!isLeap) { month += 1; }
        }
        return null;
    }

    function lunarText(y as Number, m as Number, d as Number) as String or Null {
        var l = lunar(y, m, d);
        if (l == null) { return null; }
        var day = l[1] as Number;
        var name;
        if (day == 10) { name = "初十"; }
        else if (day == 20) { name = "二十"; }
        else if (day == 30) { name = "三十"; }
        else { name = TENS[day / 10] + DIGITS[day % 10 - 1]; }
        return ((l[2] as Boolean) ? "闰" : "") + MONTHS[(l[0] as Number) - 1] + "月" + name;
    }
}
