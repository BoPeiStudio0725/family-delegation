package tw.taipei.codefest.delegation.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import tw.taipei.codefest.delegation.domain.Booking;

import java.util.List;

public interface BookingRepository extends JpaRepository<Booking, Long> {
    List<Booking> findByElderIdOrderByIdDesc(Long elderId);

    boolean existsByElderIdAndActivityIdAndStatusIn(Long elderId, Long activityId,
                                                    java.util.Collection<tw.taipei.codefest.delegation.domain.Enums.BookingStatus> statuses);

    boolean existsByElderIdAndServicePointIdAndStatusIn(Long elderId, Long servicePointId,
                                                         java.util.Collection<tw.taipei.codefest.delegation.domain.Enums.BookingStatus> statuses);
}
