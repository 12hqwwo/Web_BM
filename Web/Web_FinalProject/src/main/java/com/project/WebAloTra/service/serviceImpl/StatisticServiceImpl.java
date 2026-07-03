package com.project.WebAloTra.service.serviceImpl;

import org.springframework.stereotype.Service;

import com.project.WebAloTra.dto.Statistic.*;
import com.project.WebAloTra.repository.BillRepository;
import com.project.WebAloTra.repository.CustomerRepository;
import com.project.WebAloTra.repository.ProductRepository;
import com.project.WebAloTra.service.StatisticService;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class StatisticServiceImpl implements StatisticService {

    private final BillRepository billRepository;
    private final ProductRepository productRepository;
    private final CustomerRepository customerRepository;

    public StatisticServiceImpl(BillRepository billRepository, ProductRepository productRepository,
            CustomerRepository customerRepository) {
        this.billRepository = billRepository;
        this.productRepository = productRepository;
        this.customerRepository = customerRepository;
    }

    // =============================================================
    // 🟩 1. Doanh thu theo ngày trong tháng (có thể lọc theo chi nhánh)
    // =============================================================
    @Override
    public List<DayInMonthStatistic> getDayInMonthStatistic(String month, String year, Long branchId) {
        List<Object[]> results = billRepository.statisticRevenueDayInMonth(month, year, branchId);
        List<DayInMonthStatistic> dayInMonthStatisticList = new ArrayList<>();

        YearMonth yearMonthObject = YearMonth.of(Integer.parseInt(year), Integer.parseInt(month));
        int numDaysInMonth = yearMonthObject.lengthOfMonth();

        LocalDate currentDate = yearMonthObject.atDay(1);
        Map<LocalDate, Double> revenueMap = new HashMap<>();

        for (Object[] result : results) {
            // Oracle DATE (TRUNC) ó thể trả về java.sql.Date hoặc java.sql.Timestamp tùy JDBC driver
            LocalDate date;
            if (result[0] instanceof java.sql.Timestamp) {
                date = ((java.sql.Timestamp) result[0]).toLocalDateTime().toLocalDate();
            } else if (result[0] instanceof java.sql.Date) {
                date = ((java.sql.Date) result[0]).toLocalDate();
            } else {
                // Fallback: convert toString
                date = LocalDate.parse(result[0].toString().substring(0, 10));
            }
            Double revenue = result[1] != null ? ((Number) result[1]).doubleValue() : 0.0;
            revenueMap.put(date, revenue);
        }

        for (int i = 1; i <= numDaysInMonth; i++) {
            LocalDate date = yearMonthObject.atDay(i);
            Double revenue = revenueMap.getOrDefault(date, 0.0);
            dayInMonthStatisticList.add(new DayInMonthStatistic(date.toString().substring(5), revenue));
        }

        return dayInMonthStatisticList;
    }

    // =============================================================
    // 🟩 2. Doanh thu hàng ngày (fromDate - toDate, có thể lọc chi nhánh)
    // =============================================================
    @Override
    public List<DayInMonthStatistic2> getDailyRevenue2(String startDate, String endDate, Long branchId) {
        LocalDateTime startDateTime = LocalDateTime.parse(startDate + "T00:00:00");
        LocalDateTime endDateTime = LocalDateTime.parse(endDate + "T23:59:59");
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

        List<Object[]> results = billRepository.statisticRevenueDaily(
                startDateTime.format(formatter),
                endDateTime.format(formatter),
                branchId);

        Map<LocalDate, BigDecimal> result = new LinkedHashMap<>();

        LocalDate currentDate = startDateTime.toLocalDate();
        while (!currentDate.isAfter(endDateTime.toLocalDate())) {
            result.put(currentDate, BigDecimal.ZERO);
            currentDate = currentDate.plusDays(1);
        }

        for (Object[] object : results) {
            LocalDate orderDate = LocalDate.parse((String) object[0]);
            BigDecimal totalAmount = BigDecimal.valueOf(((Number) object[1]).doubleValue());
            result.put(orderDate, result.getOrDefault(orderDate, BigDecimal.ZERO).add(totalAmount));
        }

        return result.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> new DayInMonthStatistic2(entry.getKey().toString().substring(5), entry.getValue()))
                .collect(Collectors.toList());
    }

    // =============================================================
    // 🟩 3. Doanh thu theo tháng trong năm (có thể lọc chi nhánh)
    // =============================================================
    @Override
    public List<MonthInYearStatistic> getMonthInYearStatistic(String year, Long branchId) {
        List<Object[]> results = billRepository.statisticRevenueMonthInYear(year, branchId);

        Map<Integer, BigDecimal> revenueMap = new HashMap<>();
        for (Object[] result : results) {
            int month = ((Number) result[0]).intValue();
            BigDecimal totalAmount = BigDecimal.valueOf(((Number) result[1]).doubleValue());
            revenueMap.put(month, revenueMap.getOrDefault(month, BigDecimal.ZERO).add(totalAmount));
        }

        List<MonthInYearStatistic> reportEntries = new ArrayList<>();
        for (int month = 1; month <= 12; month++) {
            BigDecimal revenue = revenueMap.getOrDefault(month, BigDecimal.ZERO);
            reportEntries.add(new MonthInYearStatistic(month, revenue));
        }

        return reportEntries;
    }

    // =============================================================
    // 🟩 4. Doanh thu giữa 2 tháng (MM-yyyy) có thể lọc chi nhánh
    // =============================================================
    @Override
    public List<MonthInYearStatistic2> getMonthlyRevenue(String fromDate, String toDate, Long branchId) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        LocalDate startDate = LocalDate.parse(fromDate + "-01", formatter);
        LocalDate endDate = LocalDate.parse(toDate + "-01", formatter).plusMonths(1).minusDays(1);

        List<Object[]> results = billRepository.statisticRevenueFormMonth(
                startDate.format(formatter),
                endDate.format(formatter),
                branchId);

        DateTimeFormatter outputFormatter = DateTimeFormatter.ofPattern("MM-yyyy");
        Map<String, BigDecimal> revenueMap = results.stream()
                .collect(Collectors.groupingBy(
                        result -> (String) result[0],
                        Collectors.reducing(BigDecimal.ZERO, r -> BigDecimal.valueOf(((Number) r[1]).doubleValue()),
                                BigDecimal::add)));

        return startDate.datesUntil(endDate.plusDays(1), java.time.Period.ofMonths(1))
                .map(month -> {
                    String monthYear = month.format(outputFormatter);
                    BigDecimal revenue = revenueMap.getOrDefault(monthYear, BigDecimal.ZERO);
                    return new MonthInYearStatistic2(monthYear, revenue);
                })
                .collect(Collectors.toList());
    }

    // =============================================================
    // 🟦 5. Sản phẩm bán chạy theo thời gian
    // =============================================================
    @Override
    public List<BestSellerProduct> getBestSellerProduct(String fromDate, String toDate) {
        return productRepository.getBestSellerProduct(fromDate, toDate);
    }

    // =============================================================
    // 🟦 6. Sản phẩm bán chạy toàn hệ thống
    // =============================================================
    @Override
    public List<BestSellerProduct> getBestSellerProductAll() {
        return productRepository.getBestSellerProduct();
    }

    // =============================================================
    // 🟨 7. Thống kê sản phẩm trong thời gian
    // =============================================================
    @Override
    public List<ProductStatistic> getStatisticProductInTime(String fromDate, String toDate) {
        return productRepository.getStatisticProduct(fromDate, toDate);
    }

    // =============================================================
    // 🟨 8. Thống kê đơn hàng theo trạng thái
    // =============================================================
    @Override
    public List<OrderStatistic> getStatisticOrder() {
        return billRepository.statisticOrder();
    }

    @Override
    public List<BestSellerProduct> getBestSellerProductByBranch(Long branchId) {
        return billRepository.getBestSellerProductByBranch(branchId);
    }
}
