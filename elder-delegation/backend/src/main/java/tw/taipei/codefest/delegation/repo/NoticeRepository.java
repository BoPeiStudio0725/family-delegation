package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.Notice;

import java.util.List;

public interface NoticeRepository extends JpaRepository<Notice, Long> {
    List<Notice> findTop50ByRecipientIdOrderByIdDesc(Long recipientId);

    List<Notice> findByRecipientIdAndReadAtIsNull(Long recipientId);
}
