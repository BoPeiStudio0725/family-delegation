package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.ActionLog;

import java.util.List;

public interface ActionLogRepository extends JpaRepository<ActionLog, Long> {
    List<ActionLog> findTop100ByElderIdOrderByIdDesc(Long elderId);
}
