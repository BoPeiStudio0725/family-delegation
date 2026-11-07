package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.Enums;
import tw.taipei.codefest.delegation.domain.Invitation;

import java.util.Optional;

public interface InvitationRepository extends JpaRepository<Invitation, Long> {
    Optional<Invitation> findFirstByCodeAndStatusOrderByIdDesc(String code, Enums.InvitationStatus status);

    boolean existsByCodeAndStatus(String code, Enums.InvitationStatus status);
}
