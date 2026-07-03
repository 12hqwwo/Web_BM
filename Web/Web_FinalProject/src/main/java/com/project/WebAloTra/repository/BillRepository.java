package com.project.WebAloTra.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.project.WebAloTra.dto.Bill.BillDetailDtoInterface;
import com.project.WebAloTra.dto.Bill.BillDetailProduct;
import com.project.WebAloTra.dto.Bill.BillDtoInterface;
import com.project.WebAloTra.dto.Refund.RefundDto;
import com.project.WebAloTra.dto.Statistic.BestSellerProduct;
import com.project.WebAloTra.dto.Statistic.OrderStatistic;
import com.project.WebAloTra.entity.Bill;
import com.project.WebAloTra.entity.enumClass.BillStatus;
import com.project.WebAloTra.entity.enumClass.InvoiceType;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface BillRepository extends JpaRepository<Bill, Long>, JpaSpecificationExecutor<Bill> {

	/*
	 * ============================= DANH SÁCH BILL (PHÂN TRANG)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    b.id AS maHoaDon,
			    b.code AS maDinhDanh,
			    c.name AS hoVaTen,
			    c.phone_number AS soDienThoai,
			    b.create_date AS ngayTao,
			    COALESCE(b.amount, 0) AS tongTien,
			    b.status AS trangThai,
			    b.invoice_type AS loaiDon,
			    pm.name AS hinhThucThanhToan,
			    COALESCE(ca.email, '') AS nhanVienThanhToan,
			    COALESCE(br.code, '') AS maDoiTra,
			    COALESCE(pmt.orderId, '') AS maGiaoDich
			FROM bill b
			LEFT JOIN customer c ON b.customer_id = c.id
			LEFT JOIN payment pmt ON b.id = pmt.bill_id
			LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
			LEFT JOIN account ca ON b.cashier_account_id = ca.id
			LEFT JOIN bill_return br ON b.id = br.bill_id
			""", countQuery = "SELECT COUNT(*) FROM bill", nativeQuery = true)
	Page<BillDtoInterface> listBill(Pageable pageable);

	/*
	 * ============================= DANH SÁCH BILL KHÔNG PHÂN TRANG
	 * =============================
	 */
	@Query(value = """
			SELECT
			    b.id AS maHoaDon,
			    b.code AS maDinhDanh,
			    c.name AS hoVaTen,
			    c.phone_number AS soDienThoai,
			    b.create_date AS ngayTao,
			    COALESCE(b.amount, 0) AS tongTien,
			    b.status AS trangThai,
			    b.invoice_type AS loaiDon,
			    pm.name AS hinhThucThanhToan,
			    COALESCE(ca.email, '') AS nhanVienThanhToan,
			    COALESCE(br.code, '') AS maDoiTra,
			    COALESCE(pmt.orderId, '') AS maGiaoDich
			FROM bill b
			LEFT JOIN customer c ON b.customer_id = c.id
			LEFT JOIN payment pmt ON b.id = pmt.bill_id
			LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
			LEFT JOIN account ca ON b.cashier_account_id = ca.id
			LEFT JOIN bill_return br ON b.id = br.bill_id
			""", nativeQuery = true)
	List<BillDtoInterface> listBill();

	/*
	 * ============================= TÌM BILL MỚI NHẤT =============================
	 */
	Bill findTopByOrderByIdDesc();

	/*
	 * ============================= CẬP NHẬT TRẠNG THÁI BILL
	 * =============================
	 */
	@Modifying
	@Transactional
	@Query(value = "UPDATE bill SET status = :status WHERE id = :id", nativeQuery = true)
	int updateStatus(@Param("status") String status, @Param("id") Long id);

	/*
	 * ============================= GẮN BILL ID VÀO PAYMENT SAU THANH TOÁN
	 * =============================
	 */
	@Modifying
	@Transactional
	@Query(value = "UPDATE payment SET bill_id = :billId, orderStatus = '1', statusExchange = 1 WHERE id = :paymentId", nativeQuery = true)
	int updateBillAndStatus(@Param("billId") Long billId, @Param("paymentId") Long paymentId);

	/*
	 * ============================= LẤY CHI TIẾT BILL =============================
	 */
	@Query(value = """
			SELECT
			    b.id AS "maDonHang",
			    b.code AS "maDinhDanh",
			    b.billing_address AS "diaChi",
			    COALESCE(SUM((bd.moment_price + COALESCE(t.toppingTotal, 0)) * bd.quantity), 0) AS "tongTien",
			    b.promotion_price AS "tienKhuyenMai",
			    c.name AS "tenKhachHang",
			    c.phone_number AS "soDienThoai",
			    c.email AS "email",
			    b.status AS "trangThaiDonHang",
			    pmt.orderId AS "maGiaoDich",
			    pm.name AS "phuongThucThanhToan",
			    b.invoice_type AS "loaiHoaDon",
			    dc.code AS "voucherName",
			    b.create_date AS "createdDate"
			FROM bill b
			LEFT JOIN customer c ON b.customer_id = c.id
			LEFT JOIN discount_code dc ON b.discount_code_id = dc.id
			LEFT JOIN bill_detail bd ON b.id = bd.bill_id
			LEFT JOIN (
			    SELECT bill_detail_id, SUM(topping_price) AS toppingTotal
			    FROM bill_detail_topping
			    GROUP BY bill_detail_id
			) t ON bd.id = t.bill_detail_id
			LEFT JOIN payment pmt ON b.id = pmt.bill_id
			LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
			WHERE b.id = :maHoaDon
			GROUP BY
			    b.id, b.code, b.billing_address, b.promotion_price,
			    c.name, c.phone_number, c.email,
			    b.status, pmt.orderId, pm.name,
			    b.invoice_type, dc.code, b.create_date
			""", nativeQuery = true)
	BillDetailDtoInterface getbill_detail(@Param("maHoaDon") Long maHoaDon);

	/*
	 * ============================= LỌC BILL (PHÂN TRANG)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    b.id AS maHoaDon,
			    b.code AS maDinhDanh,
			    c.name AS hoVaTen,
			    c.phone_number AS soDienThoai,
			    b.create_date AS ngayTao,
			    COALESCE(b.amount, 0) AS tongTien,
			    b.status AS trangThai,
			    b.invoice_type AS loaiDon,
			    pm.name AS hinhThucThanhToan,
			    COALESCE(ca.email, '') AS nhanVienThanhToan,
			    COALESCE(br.code, '') AS maDoiTra
			FROM bill b
			LEFT JOIN customer c ON b.customer_id = c.id
			LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
			LEFT JOIN account ca ON b.cashier_account_id = ca.id
			LEFT JOIN bill_return br ON b.id = br.bill_id
			WHERE (:maDinhDanh IS NULL OR b.code LIKE '%' || :maDinhDanh || '%')
			  AND (:ngayTaoStart IS NULL OR :ngayTaoEnd IS NULL OR (b.create_date BETWEEN :ngayTaoStart AND :ngayTaoEnd))
			  AND (:trangThai IS NULL OR b.status = :trangThai)
			  AND (:loaiDon IS NULL OR b.invoice_type = :loaiDon)
			  AND (:soDienThoai IS NULL OR c.phone_number LIKE '%' || :soDienThoai || '%')
			  AND (:hoVaTen IS NULL OR c.name LIKE '%' || :hoVaTen || '%')
			""", countQuery = "SELECT COUNT(*) FROM bill", nativeQuery = true)
	Page<BillDtoInterface> listSearchBill(@Param("maDinhDanh") String maDinhDanh,
			@Param("ngayTaoStart") LocalDateTime ngayTaoStart, @Param("ngayTaoEnd") LocalDateTime ngayTaoEnd,
			@Param("trangThai") BillStatus trangThai, @Param("loaiDon") InvoiceType loaiDon,
			@Param("soDienThoai") String soDienThoai, @Param("hoVaTen") String hoVaTen, Pageable pageable);

	/*
	 * ============================= LỌC BILL (KHÔNG PHÂN TRANG)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    b.id AS maHoaDon,
			    b.code AS maDinhDanh,
			    c.name AS hoVaTen,
			    c.phone_number AS soDienThoai,
			    b.create_date AS ngayTao,
			    COALESCE(b.amount, 0) AS tongTien,
			    b.status AS trangThai,
			    b.invoice_type AS loaiDon,
			    pm.name AS hinhThucThanhToan,
			    COALESCE(ca.email, '') AS nhanVienThanhToan,
			    COALESCE(br.code, '') AS maDoiTra
			FROM bill b
			LEFT JOIN customer c ON b.customer_id = c.id
			LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
			LEFT JOIN account ca ON b.cashier_account_id = ca.id
			LEFT JOIN bill_return br ON b.id = br.bill_id
			WHERE (:maDinhDanh IS NULL OR b.code LIKE '%' || :maDinhDanh || '%')
			  AND (:ngayTaoStart IS NULL OR :ngayTaoEnd IS NULL OR (b.create_date BETWEEN :ngayTaoStart AND :ngayTaoEnd))
			  AND (:trangThai IS NULL OR b.status = :trangThai)
			  AND (:loaiDon IS NULL OR b.invoice_type = :loaiDon)
			  AND (:soDienThoai IS NULL OR c.phone_number LIKE '%' || :soDienThoai || '%')
			  AND (:hoVaTen IS NULL OR c.name LIKE '%' || :hoVaTen || '%')
			""", nativeQuery = true)
	List<BillDtoInterface> listSearchBill(@Param("maDinhDanh") String maDinhDanh,
			@Param("ngayTaoStart") LocalDateTime ngayTaoStart, @Param("ngayTaoEnd") LocalDateTime ngayTaoEnd,
			@Param("trangThai") BillStatus trangThai, @Param("loaiDon") InvoiceType loaiDon,
			@Param("soDienThoai") String soDienThoai, @Param("hoVaTen") String hoVaTen);

	/*
	 * ============================= CÁC THỐNG KÊ DOANH THU
	 * =============================
	 */
	@Query(value = """
		    SELECT TRUNC(b.create_date) AS create_date,
		           COALESCE(SUM(b.amount), 0) 
		           - COALESCE(SUM(br.returnMoney), 0) 
		           + COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS revenue
		    FROM bill b
		    LEFT JOIN bill_return br ON b.id = br.bill_id
		    LEFT JOIN return_detail rd ON br.id = rd.return_id
		    LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id
		    WHERE EXTRACT(YEAR FROM b.create_date) = :year
		      AND EXTRACT(MONTH FROM b.create_date) = :month
		      AND b.status = 'HOAN_THANH'
		      AND (:branchId IS NULL OR b.branch_id = :branchId OR b.cashier_account_id = :branchId)
		    GROUP BY TRUNC(b.create_date)
		    ORDER BY TRUNC(b.create_date)
		    """, nativeQuery = true)
		List<Object[]> statisticRevenueDayInMonth(
		    @Param("month") String month,
		    @Param("year") String year,
		    @Param("branchId") Long branchId
		);


	/*
	 * ============================= THỐNG KÊ DOANH THU THEO NGÀY (DAILY)
	 * =============================
	 */
		@Query(value = """
			    SELECT TO_CHAR(b.create_date, 'YYYY-MM-DD') AS create_date,
			           COALESCE(SUM(b.amount), 0) 
			           - COALESCE(SUM(br.returnMoney), 0)
			           + COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS revenue
			    FROM bill b
			    LEFT JOIN bill_return br ON b.id = br.bill_id
			    LEFT JOIN return_detail rd ON br.id = rd.return_id
			    LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id
			    WHERE b.status = 'HOAN_THANH'
			      AND (b.create_date BETWEEN TO_TIMESTAMP(:fromDate, 'YYYY-MM-DD') AND TO_TIMESTAMP(:toDate, 'YYYY-MM-DD'))
			      AND (:branchId IS NULL OR b.branch_id = :branchId OR b.cashier_account_id = :branchId)
			    GROUP BY TO_CHAR(b.create_date, 'YYYY-MM-DD')
			    ORDER BY TO_CHAR(b.create_date, 'YYYY-MM-DD')
			    """, nativeQuery = true)
			List<Object[]> statisticRevenueDaily(
			    @Param("fromDate") String fromDate,
			    @Param("toDate") String toDate,
			    @Param("branchId") Long branchId
			);


			@Query(value = """
				    SELECT EXTRACT(MONTH FROM b.create_date) AS month,
				           COALESCE(SUM(b.amount), 0)
				           - COALESCE(SUM(br.returnMoney), 0)
				           + COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS revenue
				    FROM bill b
				    LEFT JOIN bill_return br ON b.id = br.bill_id
				    LEFT JOIN return_detail rd ON br.id = rd.return_id
				    LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id
				    WHERE EXTRACT(YEAR FROM b.create_date) = :year
				      AND b.status = 'HOAN_THANH'
				      AND (:branchId IS NULL OR b.branch_id = :branchId OR b.cashier_account_id = :branchId)
				    GROUP BY EXTRACT(MONTH FROM b.create_date)
				    ORDER BY EXTRACT(MONTH FROM b.create_date)
				    """, nativeQuery = true)
				List<Object[]> statisticRevenueMonthInYear(
				    @Param("year") String year,
				    @Param("branchId") Long branchId
				);


	/*
	 * ============================= REFUND / THỐNG KÊ KHÁC
	 * =============================
	 */
	@Query(value = "SELECT b.code AS billCode, b.id AS billId, pm.orderId AS orderId, c.name AS customerName, "
			+ "b.update_date AS cancelDate, b.amount AS totalAmount, pm.statusExchange AS statusExchange "
			+ "FROM bill b LEFT JOIN customer c ON b.customer_id = c.id "
			+ "LEFT JOIN payment pm ON pm.bill_id = b.id JOIN payment_method pme ON pme.id = b.payment_method_id "
			+ "WHERE b.status = 'HUY' AND pme.name = 'CHUYEN_KHOAN' ORDER BY b.update_date DESC", nativeQuery = true)
	List<RefundDto> findListNeedRefund();

	/*
	 * ============================= BILL ĐỦ ĐIỀU KIỆN TRẢ HÀNG (7 NGÀY)
	 * =============================
	 */
	@Query(value = "SELECT * FROM bill b " + "WHERE (SYSDATE - b.create_date) <= 7 "
			+ "AND b.status = 'HOAN_THANH'", nativeQuery = true)
	Page<Bill> findValidBillToReturn(Pageable pageable);

	/*
	 * ============================= THỐNG KÊ SỐ ĐƠN THEO TRẠNG THÁI
	 * =============================
	 */
	@Query(value = """
			SELECT
			    b.status AS status,
			    COUNT(*) AS quantity,
			    COALESCE(SUM(b.amount), 0) AS revenue
			FROM bill b
			GROUP BY b.status
			""", nativeQuery = true)
	List<com.project.WebAloTra.dto.Statistic.OrderStatistic> statisticOrder();

	/*
	 * ============================= BILL DETAIL (PRODUCTS)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    bd.id AS "bill_detailId",
			    pd.id AS "productDetailId",
			    p.name AS "tenSanPham",
			    c.name AS "tenMau",
			    s.name AS "kichCo",
			    bd.moment_price AS "giaTien",
			    bd.quantity AS "soLuong",
			    COALESCE(SUM(bt.topping_price), 0) AS "tongTopping",
			    LISTAGG(bt.topping_name, ', ') WITHIN GROUP (ORDER BY bt.topping_name) AS "tenTopping",
			    (bd.moment_price * bd.quantity) AS "tongTien",
			    (SELECT link FROM image WHERE p.id = image.product_id AND ROWNUM = 1) AS "imageUrl"
			FROM bill b
			JOIN bill_detail bd ON b.id = bd.bill_id
			JOIN product_detail pd ON bd.product_detail_id = pd.id
			JOIN product p ON pd.product_id = p.id
			JOIN color c ON pd.color_id = c.id
			JOIN size_product s ON pd.size_id = s.id
			LEFT JOIN bill_detail_topping bt ON bd.id = bt.bill_detail_id
			WHERE b.id = :maHoaDon
			GROUP BY bd.id, pd.id, p.name, c.name, s.name, bd.moment_price, bd.quantity, p.id
			""", nativeQuery = true)
	List<BillDetailProduct> getbill_detailProduct(@Param("maHoaDon") Long maHoaDon);

	/*
	 * ============================= BILL DÀNH CHO USER (/cart-status)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    q.id,
			    q.amount,
			    q.billing_address,
			    q.code,
			    q.create_date,
			    q.invoice_type,
			    q.promotion_price,
			    q.return_status,
			    q.status,
			    q.update_date,
			    q.customer_id,
			    q.discount_code_id,
			    q.payment_method_id,
			    q.branch_id, q.cashier_account_id
			FROM (
			    SELECT
			        b.id,
			        COALESCE(SUM((bd.moment_price + COALESCE(t.toppingTotal, 0)) * bd.quantity), 0) AS amount,
			        b.billing_address,
			        b.code,
			        b.create_date,
			        b.invoice_type,
			        b.promotion_price,
			        b.return_status,
			        b.status,
			        b.update_date,
			        b.customer_id,
			        b.discount_code_id,
			        b.payment_method_id,
			        b.branch_id, b.cashier_account_id
			    FROM bill b
			    LEFT JOIN bill_detail bd ON b.id = bd.bill_id
			    LEFT JOIN (
			        SELECT bill_detail_id, SUM(topping_price) AS toppingTotal
			        FROM bill_detail_topping
			        GROUP BY bill_detail_id
			    ) t ON bd.id = t.bill_detail_id
			    /* VPD tự lọc theo customer_id */
			    GROUP BY
			        b.id, b.billing_address, b.code, b.create_date, b.invoice_type,
			        b.promotion_price, b.return_status, b.status, b.update_date,
			        b.customer_id, b.discount_code_id, b.payment_method_id, b.branch_id, b.cashier_account_id
			) q
			ORDER BY q.create_date DESC
			""", countQuery = """
			    SELECT COUNT(*)
			    FROM bill
			    /* VPD tự lọc theo customer_id */
			""", nativeQuery = true)
	Page<Bill> getBillByAccount(Pageable pageable);

	/*
	 * ============================= BILL DÀNH CHO USER THEO TRẠNG THÁI
	 * =============================
	 */
	@Query(value = """
			SELECT
			    q.id,
			    q.amount,
			    q.billing_address,
			    q.code,
			    q.create_date,
			    q.invoice_type,
			    q.promotion_price,
			    q.return_status,
			    q.status,
			    q.update_date,
			    q.customer_id,
			    q.discount_code_id,
			    q.payment_method_id,
			    q.branch_id, q.cashier_account_id
			FROM (
			    SELECT
			        b.id,
			        COALESCE(SUM((bd.moment_price + COALESCE(t.toppingTotal, 0)) * bd.quantity), 0) AS amount,
			        b.billing_address,
			        b.code,
			        b.create_date,
			        b.invoice_type,
			        b.promotion_price,
			        b.return_status,
			        b.status,
			        b.update_date,
			        b.customer_id,
			        b.discount_code_id,
			        b.payment_method_id,
			        b.branch_id, b.cashier_account_id
			    FROM bill b
			    LEFT JOIN bill_detail bd ON b.id = bd.bill_id
			    LEFT JOIN (
			        SELECT bill_detail_id, SUM(topping_price) AS toppingTotal
			        FROM bill_detail_topping
			        GROUP BY bill_detail_id
			    ) t ON bd.id = t.bill_detail_id
			    /* VPD tự lọc theo customer_id */
			      AND b.status = :status
			    GROUP BY
			        b.id, b.billing_address, b.code, b.create_date, b.invoice_type,
			        b.promotion_price, b.return_status, b.status, b.update_date,
			        b.customer_id, b.discount_code_id, b.payment_method_id, b.branch_id, b.cashier_account_id
			) q
			ORDER BY q.create_date DESC
			""", countQuery = """
			    SELECT COUNT(*)
			    FROM bill
			    /* VPD tự lọc theo customer_id */ AND status = :status
			""", nativeQuery = true)
	Page<Bill> getBillByStatus(@Param("status") String status, Pageable pageable);

	/*
	 * ============================= THỐNG KÊ DOANH THU THEO THÁNG (FORM MONTH)
	 * =============================
	 */
	
	@Query(value = """
		    SELECT TO_CHAR(b.create_date, 'MM-YYYY') AS month,
		           COALESCE(SUM(b.amount), 0)
		           - COALESCE(SUM(br.returnMoney), 0)
		           + COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS revenue
		    FROM bill b
		    LEFT JOIN bill_return br ON b.id = br.bill_id
		    LEFT JOIN return_detail rd ON br.id = rd.return_id
		    LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id
		    WHERE b.status = 'HOAN_THANH'
		      AND (b.create_date BETWEEN TO_TIMESTAMP(:fromDate, 'YYYY-MM-DD') AND TO_TIMESTAMP(:toDate, 'YYYY-MM-DD'))
		      AND (:branchId IS NULL OR b.branch_id = :branchId OR b.cashier_account_id = :branchId)
		    GROUP BY TO_CHAR(b.create_date, 'MM-YYYY')
		    ORDER BY TO_CHAR(b.create_date, 'MM-YYYY')
		    """, nativeQuery = true)
		List<Object[]> statisticRevenueFormMonth(
		    @Param("fromDate") String fromDate,
		    @Param("toDate") String toDate,
		    @Param("branchId") Long branchId
		);


	/*
	 * ============================= TỔNG DOANH THU TOÀN HỆ THỐNG
	 * =============================
	 */
	@Query(value = "SELECT " + "COALESCE(SUM(b.amount), 0) - COALESCE(SUM(br.returnMoney), 0) + "
			+ "COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS total " + "FROM bill b "
			+ "LEFT JOIN bill_return br ON b.id = br.bill_id " + "LEFT JOIN return_detail rd ON br.id = rd.return_id "
			+ "LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id "
			+ "WHERE b.status = 'HOAN_THANH'", nativeQuery = true)
	Double calculateTotalRevenue();

	/*
	 * ============================= TỔNG SỐ BILL CHỜ XÁC NHẬN
	 * =============================
	 */
	@Query(value = "SELECT COUNT(*) FROM bill WHERE status = 'CHO_XAC_NHAN'", nativeQuery = true)
	int getTotalBillStatusWaiting();

	/*
	 * ============================= TỔNG DOANH THU TRONG KHOẢNG NGÀY (FROM - TO)
	 * =============================
	 */
	@Query(value = """
			SELECT
			    COALESCE(SUM(b.amount), 0)
			    - COALESCE(SUM(br.returnMoney), 0)
			    + COALESCE(SUM(rd.quantityReturn * pd.price), 0) AS total
			FROM bill b
			LEFT JOIN bill_return br ON b.id = br.bill_id
			LEFT JOIN return_detail rd ON br.id = rd.return_id
			LEFT JOIN product_detail pd ON rd.product_detail_id = pd.id
			WHERE b.status = 'HOAN_THANH'
			  AND (b.create_date BETWEEN TO_TIMESTAMP(:startDate, 'YYYY-MM-DD HH24:MI:SS') AND TO_TIMESTAMP(:endDate, 'YYYY-MM-DD HH24:MI:SS'))
			""", nativeQuery = true)
	Double calculateTotalRevenueFromDate(@Param("startDate") String startDate, @Param("endDate") String endDate);

	@Query(value = """
			    SELECT
			        br.branch_name AS branchName,
			        COUNT(b.id) AS totalOrders,
			        COALESCE(SUM(b.amount), 0) AS totalRevenue
			    FROM bill b
			    JOIN branch br ON b.branch_id = br.id
			    WHERE b.status = 'HOAN_THANH'
			    GROUP BY br.branch_name
			    ORDER BY totalRevenue DESC
			""", nativeQuery = true)
	List<Object[]> statisticRevenueByBranch();

	@Query(value = """
			    SELECT
			        TO_CHAR(b.create_date, 'YYYY-MM-DD') AS date,
			        COALESCE(SUM(b.amount), 0) AS revenue
			    FROM bill b
			    WHERE b.branch_id = :branchId
			      AND b.status = 'HOAN_THANH'
			      AND b.create_date BETWEEN TO_TIMESTAMP(:fromDate, 'YYYY-MM-DD') AND TO_TIMESTAMP(:toDate, 'YYYY-MM-DD')
			    GROUP BY TO_CHAR(b.create_date, 'YYYY-MM-DD')
			    ORDER BY TO_CHAR(b.create_date, 'YYYY-MM-DD')
			""", nativeQuery = true)
	List<Object[]> statisticRevenueByBranchAndDate(@Param("branchId") Long branchId, @Param("fromDate") String fromDate,
			@Param("toDate") String toDate);

	@Query(value = """
			    SELECT
			        EXTRACT(MONTH FROM b.create_date) AS month,
			        COALESCE(SUM(b.amount), 0) AS revenue
			    FROM bill b
			    WHERE b.branch_id = :branchId
			      AND b.status = 'HOAN_THANH'
			      AND EXTRACT(YEAR FROM b.create_date) = :year
			    GROUP BY EXTRACT(MONTH FROM b.create_date)
			    ORDER BY EXTRACT(MONTH FROM b.create_date)
			""", nativeQuery = true)
	List<Object[]> statisticRevenueMonthByBranch(@Param("branchId") Long branchId, @Param("year") String year);
	
	// ================== DOANH THU THEO CHI NHÁNH ==================

	// ✅ Tổng doanh thu theo chi nhánh (Dùng Oracle Function FN_GET_BRANCH_REVENUE)
	@Query(value = """
	    SELECT FN_GET_BRANCH_REVENUE(:branchId, DATE '2000-01-01', SYSDATE) FROM DUAL
	""", nativeQuery = true)
	Double calculateTotalRevenueByBranch(@Param("branchId") Long branchId);


	// ✅ Tổng doanh thu theo ngày và chi nhánh (Dùng Oracle Function FN_GET_BRANCH_REVENUE)
	@Query(value = """
	    SELECT FN_GET_BRANCH_REVENUE(:branchId, :fromDate, :toDate) FROM DUAL
	""", nativeQuery = true)
	Double calculateTotalRevenueFromDateByBranch(
	        @Param("fromDate") LocalDateTime fromDate,
	        @Param("toDate") LocalDateTime toDate,
	        @Param("branchId") Long branchId);

	
		@Query(value = """
			    SELECT * FROM (
			        SELECT p.name AS productName,
			               SUM(bd.quantity) AS totalQuantity,
			               SUM(bd.moment_price * bd.quantity) AS totalRevenue
			        FROM bill b
			        JOIN bill_detail bd ON b.id = bd.bill_id
			        JOIN product_detail pd ON bd.product_detail_id = pd.id
			        JOIN product p ON pd.product_id = p.id
			        WHERE b.status = 'HOAN_THANH' 
			          AND b.branch_id = :branchId
			        GROUP BY p.name
			        ORDER BY SUM(bd.quantity) DESC
			    ) WHERE ROWNUM <= 10
			""", nativeQuery = true)
			List<BestSellerProduct> getBestSellerProductByBranch(@Param("branchId") Long branchId);
		@Query(value = """
		        SELECT 
		            b.id AS maHoaDon,
		            b.code AS maDinhDanh,
		            c.name AS hoVaTen,
		            c.phone_number AS soDienThoai,
		            b.create_date AS ngayTao,
		            COALESCE(b.amount, 0) AS tongTien,
		            b.status AS trangThai,
		            b.invoice_type AS loaiDon,
		            pm.name AS hinhThucThanhToan,
		            COALESCE(ca.email, '') AS nhanVienThanhToan,
		            COALESCE(br.code, '') AS maDoiTra
		        FROM bill b
		        LEFT JOIN customer c ON b.customer_id = c.id
		        LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
		        LEFT JOIN account ca ON b.cashier_account_id = ca.id
		        LEFT JOIN bill_return br ON b.id = br.bill_id
		        WHERE b.branch_id = :branchId
		        """,
		        countQuery = "SELECT COUNT(*) FROM bill WHERE branch_id = :branchId",
		        nativeQuery = true)
		Page<BillDtoInterface> findByBranchId(@Param("branchId") Long branchId, Pageable pageable);

		@Query(value = """
		        SELECT 
		            b.id AS maHoaDon,
		            b.code AS maDinhDanh,
		            c.name AS hoVaTen,
		            c.phone_number AS soDienThoai,
		            b.create_date AS ngayTao,
		            COALESCE(b.amount, 0) AS tongTien,
		            b.status AS trangThai,
		            b.invoice_type AS loaiDon,
		            pm.name AS hinhThucThanhToan,
		            COALESCE(ca.email, '') AS nhanVienThanhToan,
		            COALESCE(br.code, '') AS maDoiTra
		        FROM bill b
		        LEFT JOIN customer c ON b.customer_id = c.id
		        LEFT JOIN payment_method pm ON b.payment_method_id = pm.id
		        LEFT JOIN account ca ON b.cashier_account_id = ca.id
		        LEFT JOIN bill_return br ON b.id = br.bill_id
		        WHERE b.cashier_account_id = :cashierId
		          AND (:branchId IS NULL OR b.branch_id = :branchId)
		        """,
		        countQuery = """
		        SELECT COUNT(*)
		        FROM bill b
		        WHERE b.cashier_account_id = :cashierId
		          AND (:branchId IS NULL OR b.branch_id = :branchId)
		        """,
		        nativeQuery = true)
		Page<BillDtoInterface> findByCashierIdAndBranchId(@Param("cashierId") Long cashierId, @Param("branchId") Long branchId, Pageable pageable);



}
