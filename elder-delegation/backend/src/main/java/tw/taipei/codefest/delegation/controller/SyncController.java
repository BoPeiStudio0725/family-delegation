package tw.taipei.codefest.delegation.controller;

import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Booking;
import tw.taipei.codefest.delegation.domain.Delegation;
import tw.taipei.codefest.delegation.domain.Enums;
import tw.taipei.codefest.delegation.repo.BookingRepository;
import tw.taipei.codefest.delegation.repo.DelegationRepository;
import tw.taipei.codefest.delegation.repo.NoticeRepository;
import tw.taipei.codefest.delegation.controller.Dtos.NoticeView;
import tw.taipei.codefest.delegation.web.AuthInterceptor;

import java.util.*;

/**
 * 自動更新用：回傳一個「版本戳記」。
 * 長輩或家屬對活動（報名、確認、取消）或授權（申請、同意、收回）有任何新動作，
 * 戳記就會改變；前端每幾秒問一次，戳記變了就重新整理畫面。
 *
 * 只算「跟我有關」的資料：長輩看自己的報名；家屬看自己照顧的長輩的報名。
 */
@RestController
@RequestMapping("/api/sync")
public class SyncController {
    private final BookingRepository bookings;
    private final DelegationRepository delegations;
    private final NoticeRepository notices;

    public SyncController(BookingRepository bookings, DelegationRepository delegations, NoticeRepository notices) {
        this.bookings = bookings;
        this.delegations = delegations;
        this.notices = notices;
    }

    @GetMapping
    public Map<String, Object> stamp(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        StringBuilder sb = new StringBuilder();
        List<Delegation> mine = me.role == Enums.Role.ELDER
                ? delegations.findByElderIdOrderByIdDesc(me.id)
                : delegations.findByFamilyIdOrderByIdDesc(me.id);
        for (Delegation d : mine) {
            sb.append('d').append(d.id).append(d.status).append(d.scopes).append(';');
        }

        Set<Long> elderIds = new TreeSet<>();
        if (me.role == Enums.Role.ELDER) {
            elderIds.add(me.id);
        } else {
            mine.stream().filter(d -> d.status == Enums.DelegationStatus.ACTIVE).forEach(d -> elderIds.add(d.elderId));
        }
        for (Long elderId : elderIds) {
            for (Booking b : bookings.findByElderIdOrderByIdDesc(elderId)) {
                sb.append('b').append(b.id).append(b.statusOrDefault()).append(';');
            }
        }
        // 通知也一起帶回去：前端每 5 秒只要一個請求（透過 ngrok / 手機網路時，請求數越少越快）
        List<NoticeView> myNotices = notices.findTop50ByRecipientIdOrderByIdDesc(me.id).stream()
                .map(NoticeView::of).toList();
        return Map.of("stamp", Integer.toHexString(sb.toString().hashCode()) + "-" + sb.length(),
                "notices", myNotices);
    }
}
