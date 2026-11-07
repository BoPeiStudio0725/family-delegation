package tw.taipei.codefest.delegation;

import org.junit.jupiter.api.Test;
import tw.taipei.codefest.delegation.domain.Activity;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.*;

/** 「每週X 時間」推算下一次上課日期。 */
class ActivitySessionTest {
    private static Activity act(String schedule) {
        Activity a = new Activity();
        a.schedule = schedule;
        return a;
    }

    @Test
    void nextOccurrenceOfWeekday() {
        // 2026/11/7 是星期六
        LocalDateTime sat = LocalDateTime.of(2026, 11, 7, 10, 0);
        var s = act("每週二 09:30–11:30").nextSession(sat);
        assertEquals(LocalDate.of(2026, 11, 10), s.date());
        assertEquals(LocalTime.of(9, 30), s.start());
        assertEquals(LocalTime.of(11, 30), s.end());
    }

    @Test
    void sameDayCountsUntilItEnds() {
        LocalDateTime tueMorning = LocalDateTime.of(2026, 11, 10, 10, 0);
        assertEquals(LocalDate.of(2026, 11, 10), act("每週二 09:30–11:30").nextSession(tueMorning).date());
        LocalDateTime tueEvening = LocalDateTime.of(2026, 11, 10, 12, 0);
        assertEquals(LocalDate.of(2026, 11, 17), act("每週二 09:30–11:30").nextSession(tueEvening).date());
    }

    @Test
    void noScheduleMeansNoSession() {
        assertNull(act(null).nextSession(LocalDateTime.now()));
        assertNull(act("不定期").nextSession(LocalDateTime.now()));
    }
}
