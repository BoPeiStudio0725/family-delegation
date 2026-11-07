package tw.taipei.codefest.delegation.service;

import org.springframework.stereotype.Service;
import tw.taipei.codefest.delegation.domain.ActionLog;
import tw.taipei.codefest.delegation.repo.ActionLogRepository;

@Service
public class AuditService {
    private final ActionLogRepository logs;

    public AuditService(ActionLogRepository logs) {
        this.logs = logs;
    }

    public void log(Long elderId, Long actorId, Long delegationId, String action, String message) {
        logs.save(new ActionLog(elderId, actorId, delegationId, action, message));
    }
}
