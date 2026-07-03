package com.project.WebAloTra.controller.admin;

import com.lowagie.text.DocumentException;
import com.project.WebAloTra.dto.Bill.*;
import com.project.WebAloTra.entity.Account;
import com.project.WebAloTra.entity.Bill;
import com.project.WebAloTra.entity.enumClass.BillStatus;
import com.project.WebAloTra.entity.enumClass.InvoiceType;
import com.project.WebAloTra.exception.NotFoundException;
import com.project.WebAloTra.repository.AccountRepository;
import com.project.WebAloTra.repository.BillRepository;
import com.project.WebAloTra.service.BillService;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import org.springframework.web.util.UriComponentsBuilder;
import org.springframework.security.core.Authentication;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.List;

@Controller
@RequestMapping("/admin")
public class BillController {

    @Autowired
    private AccountRepository accountRepository;

    @Autowired
    private BillRepository billRepository;

    @Autowired
    private BillService billService;

    // ✅ Helper method: Ensure STAFF only views/manages their own checkout bills
    private void checkBillOwnership(Long billId, Authentication authentication) {
        if (authentication == null)
            return;
        boolean isStaff = authentication.getAuthorities().stream()
                .anyMatch(r -> r.getAuthority().equals("ROLE_STAFF"));
        if (isStaff) {
            String email = authentication.getName();
            Account account = accountRepository.findByEmail(email);
            if (account != null) {
                Bill bill = billRepository.findById(billId)
                        .orElseThrow(() -> new NotFoundException("Không tìm thấy hóa đơn: " + billId));
                if (bill.getCashier() == null || !bill.getCashier().getId().equals(account.getId())) {
                    throw new NotFoundException(
                            "Bạn chỉ được xem hoặc thao tác trên hóa đơn do chính mình thanh toán!");
                }
            }
        }
    }

    @PersistenceContext
    private EntityManager entityManager;

    /**
     * Hiển thị danh sách hóa đơn với phân quyền theo vai trò.
     *
     * [ORACLE SECURITY — Defense in Depth]
     * Bộ lọc dưới đây (Java-level) là lớp bảo vệ thứ nhất ở tầng Ứng dụng.
     * Vì Spring Boot dùng HikariCP Connection Pool (tất cả user cùng chia sẻ
     * 1 kết nối TRASUA), Oracle VPD (Virtual Private Database) không thể tự
     * nhận diện nhân viên nào đang đăng nhập.
     *
     * Do đó, việc lọc branch_id / cashier_id tại Java là CẦN THIẾT và
     * bổ sung cho Oracle VPD — không phải thủ công thay thế VPD.
     *
     * Phân quyền:
     * - ADMIN → xem tất cả đơn hàng
     * - VENDOR → chỉ xem đơn theo chi nhánh của mình
     * - STAFF → chỉ xem đơn do chính mình tạo (cashier_account_id = account.id)
     */
    @GetMapping("/bill-list")
    public String getBill(
            Model model,
            Authentication authentication,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "sort", defaultValue = "ngayTao,desc") String sortField,
            @RequestParam(name = "maDinhDanh", required = false) String maDinhDanh,
            @RequestParam(name = "ngayTaoStart", required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date ngayTaoStart,
            @RequestParam(name = "ngayTaoEnd", required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date ngayTaoEnd,
            @RequestParam(name = "trangThai", required = false) String trangThai,
            @RequestParam(name = "loaiDon", required = false) String loaiDon,
            @RequestParam(name = "soDienThoai", required = false) String soDienThoai,
            @RequestParam(name = "hoVaTen", required = false) String hoVaTen) {
        int pageSize = 8;
        String[] sortParams = sortField.split(",");
        String sortFieldName = sortParams[0];
        Sort.Direction sortDirection = (sortParams.length > 1 && sortParams[1].equalsIgnoreCase("desc"))
                ? Sort.Direction.DESC
                : Sort.Direction.ASC;

        switch (sortFieldName) {
            case "createDate":
            case "ngayTao":
                sortFieldName = "ngayTao";
                break;
            case "code":
            case "maDinhDanh":
                sortFieldName = "maDinhDanh";
                break;
            case "hoVaTen":
                sortFieldName = "hoVaTen";
                break;
            case "tongTien":
                sortFieldName = "tongTien";
                break;
            default:
                sortFieldName = "ngayTao";
        }

        Pageable pageable = PageRequest.of(page, pageSize, Sort.by(sortDirection, sortFieldName));

        LocalDateTime convertedNgayTaoStart = null;
        LocalDateTime convertedNgayTaoEnd = null;
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        if (ngayTaoStart != null) {
            convertedNgayTaoStart = ngayTaoStart.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime();
            model.addAttribute("ngayTaoStart", convertedNgayTaoStart.format(formatter));
        }
        if (ngayTaoEnd != null) {
            convertedNgayTaoEnd = ngayTaoEnd.toInstant().atZone(ZoneId.systemDefault()).toLocalDateTime();
            model.addAttribute("ngayTaoEnd", convertedNgayTaoEnd.format(formatter));
        }

        Page<BillDtoInterface> bills;

        boolean isStaff = authentication != null && authentication.getAuthorities().stream()
                .anyMatch(r -> r.getAuthority().equals("ROLE_STAFF"));
        boolean isVendor = authentication != null && authentication.getAuthorities().stream()
                .anyMatch(r -> r.getAuthority().equals("ROLE_VENDOR"));

        // ✅ STAFF chỉ xem bill do chính mình thanh toán (và theo chi nhánh đang gán nếu
        // có)
        if (isStaff) {
            String email = authentication.getName();
            Account account = accountRepository.findByEmail(email);
            if (account == null) {
                throw new NotFoundException("Không tìm thấy tài khoản nhân viên: " + email);
            }
            Long branchId = account.getBranch() != null ? account.getBranch().getId() : null;
            bills = billService.findByCashierIdAndBranchId(account.getId(), branchId, pageable);

            // ✅ Nếu là vendor → chỉ lấy bill theo chi nhánh
        } else if (isVendor) {
            String email = authentication.getName();
            Long branchId = accountRepository.findBranchIdByEmail(email)
                    .orElseThrow(() -> new NotFoundException("Không tìm thấy chi nhánh cho vendor: " + email));

            bills = billService.findByBranchId(branchId, pageable);

        } else {
            // ✅ Admin thì lấy toàn bộ
            if (maDinhDanh != null || ngayTaoStart != null || ngayTaoEnd != null ||
                    trangThai != null || loaiDon != null || soDienThoai != null || hoVaTen != null) {
                bills = billService.searchListBill(
                        maDinhDanh != null ? maDinhDanh.trim() : "",
                        convertedNgayTaoStart, convertedNgayTaoEnd,
                        trangThai, loaiDon,
                        soDienThoai != null ? soDienThoai.trim() : "",
                        hoVaTen != null ? hoVaTen.trim() : "",
                        pageable);
            } else {
                bills = billService.findAll(pageable);
            }
        }

        model.addAttribute("items", bills);
        model.addAttribute("billStatus", BillStatus.values());
        model.addAttribute("invoiceType", InvoiceType.values());
        return "admin/bill";
    }

    @GetMapping("/update-bill-status/{billId}")
    public String updateBillStatus(Model model, Authentication authentication,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "sort", defaultValue = "createDate,desc") String sortField, @PathVariable Long billId,
            @RequestParam String trangThaiDonHang, RedirectAttributes redirectAttributes) {
        try {
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(r -> r.getAuthority().equals("ROLE_ADMIN"));
            if (isAdmin) {
                redirectAttributes.addFlashAttribute("message", "Lỗi: Admin chỉ được xem, không có quyền thay đổi trạng thái đơn hàng!");
                return "redirect:/admin/bill-list";
            }
            checkBillOwnership(billId, authentication);
            Bill bill = billService.updateStatus(trangThaiDonHang, billId);
            redirectAttributes.addFlashAttribute("message",
                    "Hóa đơn " + bill.getCode() + " cập nhật trạng thái thành công!");
        } catch (Exception e) {
            e.printStackTrace();
            model.addAttribute("message", "Error updating status");
        }

        return "redirect:/admin/bill-list";
    }

    @GetMapping("/update-bill-status2/{billId}")
    public String updateBillStatus2(Model model, Authentication authentication, @PathVariable Long billId,
            @RequestParam String trangThaiDonHang, RedirectAttributes redirectAttributes) {
        try {
            boolean isAdmin = authentication.getAuthorities().stream()
                    .anyMatch(r -> r.getAuthority().equals("ROLE_ADMIN"));
            if (isAdmin) {
                redirectAttributes.addFlashAttribute("message", "Lỗi: Admin chỉ được xem, không có quyền thay đổi trạng thái đơn hàng!");
                return "redirect:/admin/getbill-detail/" + billId;
            }
            checkBillOwnership(billId, authentication);
            Bill bill = billService.updateStatus(trangThaiDonHang, billId);
            redirectAttributes.addFlashAttribute("message",
                    "Hóa đơn " + bill.getCode() + " cập nhật trạng thái thành công!");
        } catch (Exception e) {
            e.printStackTrace();
            model.addAttribute("message", "Error updating status");
        }

        return "redirect:/admin/getbill-detail/" + billId;
    }

    @GetMapping("/getbill-detail/{maHoaDon}")
    public String getBillDetail(Model model, Authentication authentication, @PathVariable("maHoaDon") Long maHoaDon) {
        checkBillOwnership(maHoaDon, authentication);

        BillDetailDtoInterface billDetailDtoInterface = billService.getBillDetail(maHoaDon);
        List<BillDetailProduct> billDetailProducts = billService.getBillDetailProduct(maHoaDon);
        Double total = 0.0;
        for (BillDetailProduct billDetailProduct : billDetailProducts) {
            int q = billDetailProduct.getSoLuong();

            // ✅ Lấy tổng topping (nếu có)
            double tongTopping = 0.0;
            if (billDetailProduct.getTongTopping() != null) {
                tongTopping = billDetailProduct.getTongTopping();
            }

            // ✅ Tổng tiền = (giá sản phẩm + topping) * số lượng
            double thanhTien = (billDetailProduct.getTongTien() + tongTopping) * q;
            total += thanhTien;
        }
        model.addAttribute("billDetailProduct", billDetailProducts);
        model.addAttribute("billdetail", billDetailDtoInterface);
        model.addAttribute("total", total);
        return "admin/bill-detail";
    }

    @GetMapping("/export-bill")
    public void exportBill(
            HttpServletResponse response,
            Authentication authentication,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "sort", defaultValue = "createDate,desc") String sortField,
            @RequestParam(name = "ngayTaoStart", required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date ngayTaoStart,
            @RequestParam(name = "ngayTaoEnd", required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") Date ngayTaoEnd,
            UriComponentsBuilder uriBuilder) throws IOException {
        int pageSize = 10;
        String[] sortParams = sortField.split(",");
        String sortFieldName = sortParams[0];
        Sort.Direction sortDirection = Sort.Direction.ASC;

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

        if (sortParams.length > 1 && sortParams[1].equalsIgnoreCase("desc")) {
            sortDirection = Sort.Direction.DESC;
        }

        Sort sort = Sort.by(sortDirection, sortFieldName);

        Pageable pageable = PageRequest.of(page, pageSize, sort);
        Page<BillDtoInterface> bills;

        if (authentication != null) {
            boolean isStaff = authentication.getAuthorities().stream()
                    .anyMatch(r -> r.getAuthority().equals("ROLE_STAFF"));
            boolean isVendor = authentication.getAuthorities().stream()
                    .anyMatch(r -> r.getAuthority().equals("ROLE_VENDOR"));

            if (isStaff) {
                String email = authentication.getName();
                Account account = accountRepository.findByEmail(email);
                if (account == null)
                    throw new NotFoundException("Không tìm thấy tài khoản nhân viên: " + email);
                Long branchId = account.getBranch() != null ? account.getBranch().getId() : null;
                bills = billService.findByCashierIdAndBranchId(account.getId(), branchId, pageable);
            } else if (isVendor) {
                String email = authentication.getName();
                Long branchId = accountRepository.findBranchIdByEmail(email)
                        .orElseThrow(() -> new NotFoundException("Không tìm thấy chi nhánh cho vendor: " + email));
                bills = billService.findByBranchId(branchId, pageable);
            } else {
                bills = billService.findAll(pageable);
            }
        } else {
            bills = billService.findAll(pageable);
        }

        String exportUrl = uriBuilder.path("/export-bill")
                .queryParam("page", page)
                .queryParam("sort", sortField)
                .queryParam("ngayTaoStart", ngayTaoStart)
                .queryParam("ngayTaoEnd", ngayTaoEnd)
                .toUriString();

        billService.exportToExcel(response, bills, exportUrl);
    }

    @GetMapping("/export-pdf/{maHoaDon}")
    public String exportPdf(HttpServletResponse response, Authentication authentication,
            @PathVariable("maHoaDon") Long maHoaDon) throws DocumentException, IOException {
        checkBillOwnership(maHoaDon, authentication);
        return billService.exportPdf(response, maHoaDon);
    }

    @GetMapping("/generate-pdf/{maHoaDon}")
    public ResponseEntity<String> generatePDF(Authentication authentication, @PathVariable Long maHoaDon) {
        checkBillOwnership(maHoaDon, authentication);
        // Your HTML content as a string
        String htmlContent = billService.getHtmlContent(maHoaDon);

        HttpHeaders headers = new HttpHeaders();
        headers.add("Content-Type", "text/html; charset=utf-8");

        return new ResponseEntity<>(htmlContent, headers, HttpStatus.OK);
    }

    @ResponseBody
    @GetMapping("/api/product/{billId}/bill")
    public ResponseEntity<List<BillDetailProduct>> getAllProductByBillId(Authentication authentication,
            @PathVariable Long billId) {
        checkBillOwnership(billId, authentication);
        return ResponseEntity.ok(billService.getBillDetailProduct(billId));
    }

    @ResponseBody
    @GetMapping("/api/bill/validToReturn")
    public Page<BillDto> getAllValidBillToReturn(Pageable pageable) {
        return billService.getAllValidBillToReturn(pageable);
    }

    @ResponseBody
    @GetMapping("/api/bill/validToReturn/search")
    public Page<BillDto> getAllValidBillToReturnSearch(SearchBillDto searchBillDto, Pageable pageable) {
        return billService.searchBillJson(searchBillDto, pageable);
    }
}
