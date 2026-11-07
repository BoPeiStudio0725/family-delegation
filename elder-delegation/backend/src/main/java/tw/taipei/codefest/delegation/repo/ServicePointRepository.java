package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.ServicePoint;

import java.util.List;

public interface ServicePointRepository extends JpaRepository<ServicePoint, Long> {
    List<ServicePoint> findByDistrictOrderByName(String district);

    List<ServicePoint> findByNameContainingOrAddressContainingOrderByName(String name, String address);
}
