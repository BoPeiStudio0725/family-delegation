package tw.taipei.codefest.delegation.controller;

import org.springframework.web.bind.annotation.*;
import tw.taipei.codefest.delegation.controller.Dtos.NoticeView;
import tw.taipei.codefest.delegation.domain.AppUser;
import tw.taipei.codefest.delegation.domain.Notice;
import tw.taipei.codefest.delegation.repo.NoticeRepository;
import tw.taipei.codefest.delegation.web.AuthInterceptor;

import java.time.Instant;
import java.util.List;
import java.util.Map;

/** 我的通知（家屬會收到長輩確認 / 取消報名的通知）。 */
@RestController
@RequestMapping("/api/notices")
public class NoticeController {
    private final NoticeRepository notices;

    public NoticeController(NoticeRepository notices) {
        this.notices = notices;
    }

    @GetMapping
    public List<NoticeView> mine(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        return notices.findTop50ByRecipientIdOrderByIdDesc(me.id).stream().map(NoticeView::of).toList();
    }

    /** 全部標成已讀。 */
    @PostMapping("/read")
    public Map<String, Object> readAll(@RequestAttribute(AuthInterceptor.CURRENT_USER) AppUser me) {
        List<Notice> unread = notices.findByRecipientIdAndReadAtIsNull(me.id);
        Instant now = Instant.now();
        unread.forEach(n -> n.readAt = now);
        notices.saveAll(unread);
        return Map.of("ok", true, "count", unread.size());
    }
}
