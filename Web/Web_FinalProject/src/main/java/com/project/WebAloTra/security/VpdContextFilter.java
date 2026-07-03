package com.project.WebAloTra.security;

import com.project.WebAloTra.entity.Account;
import com.project.WebAloTra.repository.AccountRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceContext;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * VpdContextFilter — Chạy mỗi request, set Oracle Application Context cho VPD
 * và OLS.
 *
 * VPD (Virtual Private Database) — file 3, 4, 5:
 * - Gọi pkg_vpd_security.set_account_id() để set ctx_trasua.account_id +
 * customer_id
 * - Nếu thiếu → VPD policy trả '1=2' → cart/address/bill của user đều rỗng
 *
 * OLS (Oracle Label Security) — file 8:
 * - Gọi SA_SESSION.SET_LABEL() theo role
 * - STAFF xem bill mức STAFF+, MANAGER xem MANAGER+, DIRECTOR xem tất cả
 */
@Component
public class VpdContextFilter extends OncePerRequestFilter {

    private final AccountRepository accountRepository;

    @PersistenceContext
    private EntityManager entityManager;

    public VpdContextFilter(AccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain)
            throws ServletException, IOException {

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();

        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getPrincipal())) {
            String email = auth.getName();
            try {
                Account account = accountRepository.findByEmail(email);
                if (account != null) {
                    org.hibernate.Session session = entityManager.unwrap(org.hibernate.Session.class);
                    session.doWork(connection -> {
                        // ===== FIX 3 (VPD - Khang): Set account_id + customer_id vào context =====
                        try (java.sql.CallableStatement cs = connection
                                .prepareCall("{call TRASUA.pkg_vpd_security.set_account_id(?)}")) {
                            cs.setLong(1, account.getId());
                            cs.execute();
                        }

                        // ===== FIX 3C (VPD - Yên): Set context cho Wishlist =====
                        try (java.sql.CallableStatement cs5 = connection
                                .prepareCall("{call TRASUA.pkg_auth_yen.set_account_id(?)}")) {
                            cs5.setLong(1, account.getId());
                            cs5.execute();
                        } catch (Exception ex) {
                            // Bỏ qua nếu chưa chạy file 03 của Yên
                        }

                        // ===== FIX 3B (VPD - Tín): Set context chi nhánh =====
                        try (java.sql.CallableStatement cs3 = connection
                                .prepareCall("{call TRASUA.pkg_branch_sec.set_context(?, ?, ?)}")) {
                            cs3.setLong(1, account.getBranch() != null ? account.getBranch().getId() : -1L);
                            cs3.setString(2, account.getRole() != null ? account.getRole().getName().name() : "");
                            cs3.setLong(3, account.getId());
                            cs3.execute();
                        } catch (Exception ex) {
                            // Bỏ qua nếu chưa chạy file 02 của Tín
                        }

                        // ===== FIX 5 (OLS - Khang/Yên): Set label theo role cho bảng BILL (cũ) =====
                        String olsLabel = resolveOlsLabel(account);
                        try (java.sql.CallableStatement cs2 = connection
                                .prepareCall("{call SA_SESSION.SET_LABEL('BILL_OLS_POL', ?)}")) {
                            cs2.setString(1, olsLabel);
                            cs2.execute();
                        } catch (Exception olsEx) {
                            // Bỏ qua
                        }

                        // ===== FIX 5B (OLS - Tín): Set ACCESS_POLICY label (mới) =====
                        String tinOlsLabel = resolveTinsOlsLabel(account);
                        try (java.sql.CallableStatement cs4 = connection
                                .prepareCall("{call SA_SESSION.SET_LABEL('ACCESS_POLICY', ?)}")) {
                            cs4.setString(1, tinOlsLabel);
                            cs4.execute();
                        } catch (Exception ex) {
                            // Bỏ qua nếu OLS của Tín chưa được apply
                        }

                        // ===== FIX 5C (OLS - Quỳnh): Set BRANCH_OLS_POLICY label (mới) =====
                        String quynhOlsLabel = resolveQuynhOlsLabel(account);
                        try (java.sql.CallableStatement cs6 = connection
                                .prepareCall("{call SA_SESSION.SET_LABEL('BRANCH_OLS_POLICY', ?)}")) {
                            cs6.setString(1, quynhOlsLabel);
                            cs6.execute();
                        } catch (Exception ex) {
                            // Bỏ qua nếu OLS của Quỳnh chưa được apply
                        }
                    });
                }
            } catch (Exception ex) {
                // VPD context lỗi → log warning, không làm crash request
                logger.warn("VPD context set thất bại: " + ex.getMessage());
            }
        } else {
            // Khi chưa đăng nhập (Anonymous), cần Reset Context để dùng chung Connection
            // Pool
            // Nếu không, connection sẽ giữ nhãn của user trước đó, gây lỗi không tìm thấy
            // Account để login
            try {
                org.hibernate.Session session = entityManager.unwrap(org.hibernate.Session.class);
                session.doWork(connection -> {
                    // ===== [FIX] Reset VPD Context của Khang (address + cart + bill) =====
                    // Khi anonymous, phải xóa account_id trước khi thực hiện query khác
                    // Nếu không, connection pool có thể giữ account_id của user trước
                    try (java.sql.CallableStatement csKhang = connection
                            .prepareCall("{call TRASUA.pkg_vpd_security.set_account_id(NULL)}")) {
                        csKhang.execute();
                    } catch (Exception ex) {
                        // Bỏ qua nếu chưa cài
                    }

                    // Xóa VPD Context của Tín (Truyền rỗng để VPD hiểu là Admin/Bypass, cho phép
                    // query bảng account)
                    try (java.sql.CallableStatement cs3 = connection
                            .prepareCall("{call TRASUA.pkg_branch_sec.set_context(-1, '', -1)}")) {
                        cs3.execute();
                    } catch (Exception ex) {
                    }

                    // Xóa VPD Context của Yên
                    try (java.sql.CallableStatement csYen = connection
                            .prepareCall("{call TRASUA.pkg_auth_yen.set_account_id(NULL)}")) {
                        csYen.execute();
                    } catch (Exception ex) {
                    }

                    // Gán OLS Label cao nhất cho ứng dụng để nó có thể query bảng account phục vụ
                    // Login
                    try (java.sql.CallableStatement cs4 = connection
                            .prepareCall("{call SA_SESSION.SET_LABEL('ACCESS_POLICY', 'SEC:BR1,BR2:MNG,OPR')}")) {
                        cs4.execute();
                    } catch (Exception ex) {
                    }

                    // Gán OLS Label cho Quỳnh (Để khách vãng lai hoặc Admin chưa Login cũng không
                    // bị lỗi khi đọc branch_inventory)
                    try (java.sql.CallableStatement cs5 = connection
                            .prepareCall("{call SA_SESSION.SET_LABEL('BRANCH_OLS_POLICY', 'PUBLIC')}")) {
                        cs5.execute();
                    } catch (Exception ex) {
                    }
                });
            } catch (Exception ex) {
                logger.warn("Không thể reset VPD Context: " + ex.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Map role của account sang OLS label string.
     * Khớp với 3 levels đã tạo trong 8_OLS_BILL.sql:
     * STAFF(10), MANAGER(20), DIRECTOR(30)
     */
    private String resolveOlsLabel(Account account) {
        if (account.getRole() == null || account.getRole().getName() == null) {
            return "STAFF";
        }
        String roleName = account.getRole().getName().name(); // enum → String
        return switch (roleName) {
            case "ROLE_ADMIN" -> "DIRECTOR";
            case "ROLE_VENDOR" -> "MANAGER";
            default -> "STAFF"; // ROLE_STAFF, ROLE_USER, ROLE_GUEST
        };
    }

    /**
     * Map role của account sang OLS label string theo logic của Tín (File 02).
     * Admin -> SEC:BR1,BR2:MNG,OPR
     * Vendor -> CONF:BRx:MNG,OPR
     * Staff -> PUB:BRx:OPR
     */
    private String resolveTinsOlsLabel(Account account) {
        String roleName = (account.getRole() != null && account.getRole().getName() != null)
                ? account.getRole().getName().name()
                : "";
        String branchId = account.getBranch() != null ? String.valueOf(account.getBranch().getId()) : "";
        String branchCompartment = "";

        if ("1".equals(branchId))
            branchCompartment = "BR1";
        else if ("2".equals(branchId))
            branchCompartment = "BR2";
        else
            branchCompartment = "BR1,BR2"; // default cho admin hoặc không có chi nhánh

        return switch (roleName) {
            case "ROLE_ADMIN" -> "SEC:BR1,BR2:MNG,OPR";
            case "ROLE_VENDOR" -> "CONF:" + branchCompartment + ":MNG,OPR";
            case "ROLE_STAFF" -> "PUB:" + branchCompartment + ":OPR";
            default -> "PUB"; // ROLE_USER, ROLE_GUEST
        };
    }

    /**
     * Map role của account sang OLS label của Quỳnh (BRANCH_OLS_POLICY)
     */
    private String resolveQuynhOlsLabel(Account account) {
        if (account.getRole() == null || account.getRole().getName() == null) {
            return "PUBLIC";
        }
        String roleName = account.getRole().getName().name(); 
        if ("ROLE_ADMIN".equals(roleName)) {
            // Khai báo ALL Compartments (Hoặc cấp quyền bypass cho user pool TRASUA)
            return "CONFIDENTIAL:CN1,CN2,CN3,CN4"; 
        }
        
        if (account.getBranch() != null && account.getBranch().getId() != null) {
            return "CONFIDENTIAL:CN" + account.getBranch().getId();
        }
        return "PUBLIC";
    }
}
