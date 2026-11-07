package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.Delegation;
import tw.taipei.codefest.delegation.domain.Enums;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface DelegationRepository extends JpaRepository<Delegation, Long> {
    List<Delegation> findByElderIdOrderByIdDesc(Long elderId);

    List<Delegation> findByFamilyIdOrderByIdDesc(Long familyId);

    List<Delegation> findByElderIdAndStatusOrderByIdDesc(Long elderId, Enums.DelegationStatus status);

    Optional<Delegation> findFirstByElderIdAndFamilyIdAndStatusOrderByIdDesc(
            Long elderId, Long familyId, Enums.DelegationStatus status);

    boolean existsByElderIdAndStatusIn(Long elderId, Collection<Enums.DelegationStatus> statuses);

    boolean existsByFamilyIdAndStatusIn(Long familyId, Collection<Enums.DelegationStatus> statuses);

    boolean existsByElderIdAndFamilyIdAndStatusIn(
            Long elderId, Long familyId, Collection<Enums.DelegationStatus> statuses);
}
