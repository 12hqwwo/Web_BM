package com.project.WebAloTra.controller.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.project.WebAloTra.config.ConfigVNPay;
import com.project.WebAloTra.dto.Order.OrderDto;
import com.project.WebAloTra.dto.Payment.PaymentResultDto;
import com.project.WebAloTra.entity.Payment;
import com.project.WebAloTra.repository.PaymentRepository;
import com.project.WebAloTra.service.CartService;

import org.springframework.stereotype.Controller;
import javax.persistence.EntityManager;
import javax.persistence.ParameterMode;
import javax.persistence.StoredProcedureQuery;
import com.project.WebAloTra.utils.UserLoginUtil;
import org.springframework.beans.factory.annotation.Autowired;

import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;

@Controller
public class PaymentController {

    private final PaymentRepository paymentRepository;
    private final CartService cartService;
    private final ObjectMapper objectMapper;

    @Autowired
    private EntityManager entityManager;


    public PaymentController(PaymentRepository paymentRepository, CartService cartService, ObjectMapper objectMapper) {
        this.paymentRepository = paymentRepository;
        this.cartService = cartService;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/payment-result")
    public String viewPaymentResult(HttpServletRequest request, Model model, HttpSession session) throws UnsupportedEncodingException {
        Map<String, String> fields = new HashMap<>();

        for (Enumeration<String> params = request.getParameterNames(); params.hasMoreElements();) {
            String fieldName = params.nextElement();
            String fieldValue = request.getParameter(fieldName);
            if (fieldValue != null && !fieldValue.isEmpty()) {
                fields.put(fieldName, fieldValue);
            }
        }

        String vnp_SecureHash = request.getParameter("vnp_SecureHash");
        fields.remove("vnp_SecureHashType");
        fields.remove("vnp_SecureHash");

        String signValue = ConfigVNPay.hashAllFields(fields);

        PaymentResultDto paymentResultDto = new PaymentResultDto();
        paymentResultDto.setTxnRef(fields.get("vnp_TxnRef"));
        paymentResultDto.setAmount(String.valueOf(Double.parseDouble(fields.get("vnp_Amount")) / 100));
        paymentResultDto.setBankCode(fields.get("vnp_BankCode"));
        paymentResultDto.setDatePay(fields.get("vnp_PayDate"));
        paymentResultDto.setResponseCode(fields.get("vnp_ResponseCode"));
        paymentResultDto.setTransactionStatus(fields.get("vnp_TransactionStatus"));

        model.addAttribute("result", paymentResultDto);

        if (signValue.equals(vnp_SecureHash)) {
            boolean checkOrderId = paymentRepository.existsByOrderId(paymentResultDto.getTxnRef());
            if (checkOrderId) {
                Payment paymentUpdate = paymentRepository.findByOrderId(paymentResultDto.getTxnRef());
                double amountFromVNPay = Double.parseDouble(paymentResultDto.getAmount());
                double amountFromDB = Double.parseDouble(paymentUpdate.getAmount());
                boolean checkAmount = amountFromVNPay == amountFromDB;
                boolean checkOrderStatus = paymentUpdate.getOrderStatus().equals("0");

                if (checkAmount) {
                    if (checkOrderStatus) {
                        if ("00".equals(request.getParameter("vnp_TransactionStatus"))) {

                            try {
                                // ✅ BƯỚC 1: Lấy dataSend từ session (được gửi từ frontend qua sessionStorage)
                                String orderTempJson = (String) session.getAttribute("orderTemp");
                                if (orderTempJson == null) {
                                    model.addAttribute("status", "Không tìm thấy dữ liệu đơn hàng tạm thời!");
                                    model.addAttribute("paymentSuccess", false);
                                    return "user/payment-result";
                                }

                                // ✅ BƯỚC 2: Parse JSON thành OrderDto
                                OrderDto orderDto = objectMapper.readValue(orderTempJson, OrderDto.class);
                                orderDto.setOrderId(paymentResultDto.getTxnRef());

                                // ✅ BƯỚC 3: Gọi cartService.orderUser() để tạo Bill + tự liên kết Payment
                                // orderUser() đã xử lý: tạo bill → link payment theo orderId → không cần step 4 nữa
                                
                                // [BẢO MẬT CƠ SỞ DỮ LIỆU: ÁP DỤNG STORED PROCEDURE]
                                // Thay vì gọi cartService.orderUser(orderDto) (dùng PROC_CREATE_ORDER),
                                // ta gọi PROC_CONFIRM_PAYMENT để bảo vệ an toàn:
                                // - Chặn chống dội lệnh (Duplicate callback) từ VNPay.
                                // - Xác thực hóa đơn hợp lệ trước khi tạo.

                                /* === CODE CŨ ĐÃ COMMENT ===
                                cartService.orderUser(orderDto);
                                === KẾT THÚC CODE CŨ === */

                                Long customerId = null;
                                if (orderDto.getCustomer() != null && orderDto.getCustomer().getId() != null) {
                                    customerId = orderDto.getCustomer().getId();
                                }
                                Double promotionDiscount = orderDto.getPromotionPrice();
                                if (promotionDiscount == null || Double.isNaN(promotionDiscount) || promotionDiscount < 0) {
                                    promotionDiscount = 0.0;
                                }
                                String orderDetailsJson = objectMapper.writeValueAsString(orderDto.getOrderDetailDtos());

                                StoredProcedureQuery query = entityManager.createStoredProcedureQuery("PROC_CONFIRM_PAYMENT");
                                query.registerStoredProcedureParameter("p_order_id_vnpay", String.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_billing_address", String.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_payment_method_id", Long.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_customer_id", Long.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_voucher_id", Long.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_promotion_price", Double.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_branch_id", Long.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_order_details_json", String.class, ParameterMode.IN);
                                query.registerStoredProcedureParameter("p_account_id", Long.class, ParameterMode.IN);
                                
                                query.registerStoredProcedureParameter("p_bill_id", Long.class, ParameterMode.OUT);
                                query.registerStoredProcedureParameter("p_bill_code", String.class, ParameterMode.OUT);
                                query.registerStoredProcedureParameter("p_final_amount", Double.class, ParameterMode.OUT);
                                query.registerStoredProcedureParameter("p_error_code", Integer.class, ParameterMode.OUT);
                                query.registerStoredProcedureParameter("p_error_msg", String.class, ParameterMode.OUT);

                                Long accountId = null;
                                if (UserLoginUtil.getCurrentLogin() != null) {
                                    accountId = UserLoginUtil.getCurrentLogin().getId();
                                }

                                query.setParameter("p_order_id_vnpay", paymentResultDto.getTxnRef());
                                query.setParameter("p_billing_address", orderDto.getBillingAddress());
                                query.setParameter("p_payment_method_id", orderDto.getPaymentMethodId());
                                query.setParameter("p_customer_id", customerId);
                                query.setParameter("p_voucher_id", orderDto.getVoucherId());
                                query.setParameter("p_promotion_price", promotionDiscount);
                                query.setParameter("p_branch_id", orderDto.getBranchId());
                                query.setParameter("p_order_details_json", orderDetailsJson);
                                query.setParameter("p_account_id", accountId);

                                query.execute();

                                Integer errorCode = (Integer) query.getOutputParameterValue("p_error_code");
                                if (errorCode != null && errorCode < 0) {
                                    String errorMsg = (String) query.getOutputParameterValue("p_error_msg");
                                    throw new RuntimeException("Lỗi xác nhận thanh toán: " + errorMsg);
                                }

                                System.out.println("✅ Tạo đơn hàng thành công cho OrderId: " + paymentResultDto.getTxnRef());

                                // ✅ BƯỚC 4: Lấy bill thông qua orderId (an toàn, tránh race condition findTopByOrderByIdDesc)
                                Payment updatedPayment = paymentRepository.findByOrderId(paymentResultDto.getTxnRef());
                                if (updatedPayment != null && updatedPayment.getBill() != null) {
                                    System.out.println("✅ Bill ID: " + updatedPayment.getBill().getId()
                                        + " | Payment amount: " + updatedPayment.getAmount());
                                }

                                model.addAttribute("status", "Giao dịch thành công");
                                model.addAttribute("paymentSuccess", true);
                                model.addAttribute("orderId", paymentResultDto.getTxnRef());

                                // ✅ BƯỚC 5: Xóa dữ liệu tạm từ session
                                session.removeAttribute("orderTemp");

                            } catch (Exception e) {
                                e.printStackTrace();
                                model.addAttribute("status", "Lỗi khi xử lý đơn hàng: " + e.getMessage());
                                model.addAttribute("paymentSuccess", false);
                            }
                        } else {
                            model.addAttribute("status", "Giao dịch không thành công");
                            model.addAttribute("paymentSuccess", false);
                        }
                    } else {
                        model.addAttribute("status", "Đơn hàng đã được thanh toán");
                        model.addAttribute("paymentSuccess", false);
                    }
                } else {
                    model.addAttribute("status", "Số tiền không khớp");
                    model.addAttribute("paymentSuccess", false);
                }
            } else {
                model.addAttribute("status", "Mã giao dịch không tồn tại");
                model.addAttribute("paymentSuccess", false);
            }
        } else {
            model.addAttribute("status", "Invalid checksum");
            model.addAttribute("paymentSuccess", false);
        }

        return "user/payment-result";
    }
}