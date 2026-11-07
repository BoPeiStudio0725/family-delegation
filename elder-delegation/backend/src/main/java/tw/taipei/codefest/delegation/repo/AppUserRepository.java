package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.AppUser;

import java.util.Optional;

public interface AppUserRepository extends JpaRepository<AppUser, Long> {
    Optional<AppUser> findByTownpassId(String townpassId);
}
