package com.project.WebAloTra.service.serviceImpl;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import javax.persistence.EntityManager;
import javax.persistence.ParameterMode;
import javax.persistence.StoredProcedureQuery;
import org.springframework.beans.factory.annotation.Autowired;
import com.fasterxml.jackson.databind.ObjectMapper;


import com.project.WebAloTra.dto.Cart.CartDto;
import com.project.WebAloTra.dto.Cart.ProductCart;
import com.project.WebAloTra.dto.Order.OrderDetailDto;
import com.project.WebAloTra.dto.Order.OrderDto;
import com.project.WebAloTra.dto.Order.ToppingOrderDto;
import com.project.WebAloTra.dto.Product.ProductDetailDto;
import com.project.WebAloTra.entity.*;
import com.project.WebAloTra.entity.enumClass.BillStatus;
import com.project.WebAloTra.entity.enumClass.InvoiceType;
import com.project.WebAloTra.entity.enumClass.PaymentMethodName;
import com.project.WebAloTra.exception.NotFoundException;
import com.project.WebAloTra.exception.ShopApiException;
import com.project.WebAloTra.repository.*;
import com.project.WebAloTra.service.CartService;
import com.project.WebAloTra.utils.RandomUtils;
import com.project.WebAloTra.utils.UserLoginUtil;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class CartServiceImpl implements CartService {

    private final CartRepository cartRepository;
    private final ProductDiscountRepository productDiscountRepository;
    private final CustomerRepository customerRepository;
    private final AccountRepository accountRepository;
    private final ProductRepository productRepository;
    private final ProductDetailRepository productDetailRepository;
    private final BillRepository billRepository;
    private final BillDetailRepository billDetailRepository;
    private final DiscountCodeRepository discountCodeRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentMethodRepository paymentMethodRepository;
    private final BillDetailToppingRepository billDetailToppingRepository;
    private final BranchRepository branchRepository;
    private final BranchInventoryRepository branchInventoryRepository;

    private final AtomicLong invoiceCounter = new AtomicLong(1);

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private ObjectMapper objectMapper;


    public CartServiceImpl(
            CartRepository cartRepository,
            ProductDiscountRepository productDiscountRepository,
            CustomerRepository customerRepository,
            AccountRepository accountRepository,
            ProductRepository productRepository,
            ProductDetailRepository productDetailRepository,
            BillRepository billRepository,
            BillDetailRepository billDetailRepository,
            DiscountCodeRepository discountCodeRepository,
            PaymentRepository paymentRepository,
            PaymentMethodRepository paymentMethodRepository,
            BillDetailToppingRepository billDetailToppingRepository,
            BranchRepository branchRepository,
            BranchInventoryRepository branchInventoryRepository
    ) {
        this.cartRepository = cartRepository;
        this.productDiscountRepository = productDiscountRepository;
        this.customerRepository = customerRepository;
        this.accountRepository = accountRepository;
        this.productRepository = productRepository;
        this.productDetailRepository = productDetailRepository;
        this.billRepository = billRepository;
        this.billDetailRepository = billDetailRepository;
        this.discountCodeRepository = discountCodeRepository;
        this.paymentRepository = paymentRepository;
        this.paymentMethodRepository = paymentMethodRepository;
        this.billDetailToppingRepository = billDetailToppingRepository;
        this.branchRepository = branchRepository;
        this.branchInventoryRepository = branchInventoryRepository;
    }

    @Override
    public List<CartDto> getAllCart() {
        List<Cart> carts = cartRepository.findAll();
        List<CartDto> cartDtos = new ArrayList<>();
        carts.forEach(cart -> {
            CartDto cartDto = new CartDto();
            cartDto.setId(cart.getId());
            cartDto.setQuantity(cart.getQuantity());
            cartDto.setCreateDate(cart.getCreateDate());
        });
        return cartDtos;
    }

    @Override
    public List<CartDto> getAllCartByAccountId() {
        Account account = UserLoginUtil.getCurrentLogin();
        if (account == null) {
            System.out.println("🛠️ [Cart] Account = null, trả rỗng");
            return new ArrayList<>();
        }

        System.out.println("🛠️ [Cart] Đang lấy cart cho account.id = " + account.getId());

        // ✅ [FIX] Lấy cart theo account_id cụ thể — Native query tránh VPD lọc sai
        List<Cart> cartList = cartRepository.findAllByAccount_Id(account.getId());
        System.out.println("🛠️ [Cart] Số lượng cart tìm được trong DB: " + cartList.size());

        List<CartDto> cartDtos = new ArrayList<>();

        cartList.forEach(cart -> {
            if (cart.getProductDetail() == null || cart.getProductDetail().getProduct() == null) {
                System.out.println("⚠️ [Cart] Cart id=" + cart.getId() + " bị bỏ qua: ProductDetail hoặc Product null");
                return; // ✅ [FIX] bỏ qua cart bị mất sản phẩm, tránh NPE
            }

            Product product = productRepository.findById(cart.getProductDetail().getProduct().getId())
                    .orElse(null);
            if (product == null) {
                System.out.println("⚠️ [Cart] Cart id=" + cart.getId() + " bị bỏ qua: Product không tịn tại");
                return; // ✅ [FIX] bỏ qua thay vì orElseThrow() gây crash
            }

            ProductCart productCart = new ProductCart();
            productCart.setProductId(product.getId());
            productCart.setName(product.getName());
            productCart.setCode(product.getCode());
            productCart.setDescribe(product.getDescribe());
            productCart.setImageUrl(product.getFirstImageUrl());

            ProductDetailDto productDetailDto = new ProductDetailDto();
            productDetailDto.setId(cart.getProductDetail().getId());
            productDetailDto.setProductId(product.getId());
            productDetailDto.setPrice(cart.getProductDetail().getPrice());
            productDetailDto.setSize(cart.getProductDetail().getSize());
            productDetailDto.setQuantity(cart.getProductDetail().getQuantity());
            productDetailDto.setColor(cart.getProductDetail().getColor());

            ProductDiscount productDiscount =
                    productDiscountRepository.findValidDiscountByProductDetailId(cart.getProductDetail().getId());
            if (productDiscount != null) {
                productDetailDto.setDiscountedPrice(productDiscount.getDiscountedAmount());
            }

            CartDto cartDto = new CartDto();
            cartDto.setId(cart.getId());
            cartDto.setQuantity(cart.getQuantity());
            cartDto.setCreateDate(cart.getCreateDate());
            cartDto.setAccountId(account.getId());
            cartDto.setProduct(productCart);
            cartDto.setDetail(productDetailDto);
            cartDtos.add(cartDto);
        });

        System.out.println("🛠️ [Cart] Số cart sau khi map thành DTO: " + cartDtos.size());
        return cartDtos;
    }

    @Override
    @Transactional(rollbackOn = Exception.class)
    public void addToCart(CartDto cartDto) throws NotFoundException {
        Account account = UserLoginUtil.getCurrentLogin();
        // ✅ [FIX] Guard: nếu chưa đăng nhập thì không lưu cart vào DB
        if (account == null) {
            throw new ShopApiException(HttpStatus.UNAUTHORIZED, "Bạn cần đăng nhập để thêm vào giỏ hàng");
        }

        ProductDetail productDetail = productDetailRepository.findById(cartDto.getDetail().getId())
                .orElseThrow(() -> new NotFoundException("Product not found"));

        int quantityAdding = cartDto.getQuantity();
        int quantityRemaining = productDetail.getQuantity();

        // ✅ [FIX] Tìm cart theo cả productDetailId và accountId — tránh lấy nhầm cart của user khác
        Cart existsCart = cartRepository.findAllByAccount_Id(account.getId())
                .stream()
                .filter(c -> c.getProductDetail() != null &&
                             c.getProductDetail().getId().equals(productDetail.getId()))
                .findFirst()
                .orElse(null);

        if (existsCart != null) {
            int currentQuantity = existsCart.getQuantity();
            int quantityNeedToAdd = currentQuantity + quantityAdding;

            if (quantityRemaining == 0) {
                throw new ShopApiException(HttpStatus.BAD_REQUEST, "Sản phẩm có thuộc tính này đã hết hàng");
            }
            if (quantityRemaining < quantityNeedToAdd) {
                throw new ShopApiException(HttpStatus.BAD_REQUEST, "Số lượng thêm vào giỏ hàng lớn hơn số lượng tồn");
            }

            existsCart.setQuantity(quantityNeedToAdd);
            existsCart.setUpdateDate(LocalDateTime.now());
            cartRepository.save(existsCart);
        } else {
            if (quantityRemaining < quantityAdding) {
                throw new ShopApiException(HttpStatus.BAD_REQUEST, "Số lượng thêm vào giỏ hàng lớn hơn số lượng tồn");
            }

            Cart cart = new Cart();
            cart.setAccount(account);
            cart.setProductDetail(productDetail);
            cart.setQuantity(quantityAdding);
            cart.setCreateDate(LocalDateTime.now());
            cart.setUpdateDate(LocalDateTime.now());
            cartRepository.save(cart);
        }
    }

    @Override
    public void updateCart(CartDto cartDto) throws NotFoundException {
        Cart cart = cartRepository.findById(cartDto.getId())
                .orElseThrow(() -> new NotFoundException("Cart not found"));
        int quantityAdding = cartDto.getQuantity();
        int quantityRemaining = cart.getProductDetail().getQuantity();

        if (quantityAdding > quantityRemaining) {
            throw new ShopApiException(HttpStatus.BAD_REQUEST,
                    "Xin lỗi, số lượng sản phẩm này chỉ còn: " + quantityRemaining);
        }
        cart.setQuantity(cartDto.getQuantity());
        cartRepository.save(cart);
    }

    @Override
    @Transactional(rollbackOn = Exception.class)
    public void orderUser(OrderDto orderDto) {
        /* 
         * [BẢO MẬT CƠ SỞ DỮ LIỆU: ÁP DỤNG STORED PROCEDURE]
         * Toàn bộ logic tạo đơn hàng ONLINE đã được chuyển xuống Oracle DB (PROC_CREATE_ORDER).
         * Thay vì gọi nhiều lệnh JPA save() từ Java (tạo Bill, BillDetail, tính tiền, trừ kho, v.v.),
         * hệ thống gom dữ liệu thành JSON và gọi thủ tục DB 1 lần duy nhất để:
         * 1. Đảm bảo Transaction an toàn (Rollback toàn bộ nếu lỗi).
         * 2. DB tự động trừ tồn kho và tính tổng tiền chính xác.
         */

        try {
            String orderDetailsJson = objectMapper.writeValueAsString(orderDto.getOrderDetailDtos());
            Long customerId = null;
            if (UserLoginUtil.getCurrentLogin() != null && UserLoginUtil.getCurrentLogin().getCustomer() != null) {
                customerId = UserLoginUtil.getCurrentLogin().getCustomer().getId();
            }
            
            Double promotionDiscount = orderDto.getPromotionPrice();
            if (promotionDiscount == null || Double.isNaN(promotionDiscount) || promotionDiscount < 0) {
                promotionDiscount = 0.0;
            }

            StoredProcedureQuery query = entityManager.createStoredProcedureQuery("PROC_CREATE_ORDER");
            query.registerStoredProcedureParameter("p_billing_address", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_invoice_type", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_payment_method_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_customer_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_voucher_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_promotion_price", Double.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_order_id_vnpay", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_branch_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_order_details_json", String.class, ParameterMode.IN);
            
            query.registerStoredProcedureParameter("p_bill_id", Long.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_bill_code", String.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_final_amount", Double.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_error_code", Integer.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_error_msg", String.class, ParameterMode.OUT);

            query.setParameter("p_billing_address", orderDto.getBillingAddress());
            query.setParameter("p_invoice_type", "ONLINE");
            query.setParameter("p_payment_method_id", orderDto.getPaymentMethodId());
            query.setParameter("p_customer_id", customerId);
            query.setParameter("p_voucher_id", orderDto.getVoucherId());
            query.setParameter("p_promotion_price", promotionDiscount);
            query.setParameter("p_order_id_vnpay", orderDto.getOrderId());
            query.setParameter("p_branch_id", orderDto.getBranchId());
            query.setParameter("p_order_details_json", orderDetailsJson);

            query.execute();

            Integer errorCode = (Integer) query.getOutputParameterValue("p_error_code");
            String errorMsg = (String) query.getOutputParameterValue("p_error_msg");

            if (errorCode != null && errorCode < 0) {
                System.err.println("LỖI TẠO ĐƠN HÀNG ORACLE: " + errorMsg + " CODE: " + errorCode);
                throw new ShopApiException(HttpStatus.BAD_REQUEST, errorMsg);
            }

            if (UserLoginUtil.getCurrentLogin() != null) {
                // ✅ [FIX] Xóa đúcng giỏ hàng của user hiện tại, không xóa của người khác
                cartRepository.deleteByAccount_Id(UserLoginUtil.getCurrentLogin().getId());
            }

        } catch (Exception e) {
            if (e instanceof ShopApiException) throw (ShopApiException) e;
            throw new RuntimeException("Lỗi tạo đơn hàng: " + e.getMessage(), e);
        }
    }





	@Override
	@Transactional(rollbackOn = Exception.class)
	public OrderDto orderAdmin(OrderDto orderDto) {
        // Thay vì xử lý logic Java cũ (trừ kho, tính tiền, tạo bill), giờ gọi Oracle Procedure để DB tự xử lý

        try {
            String orderDetailsJson = objectMapper.writeValueAsString(orderDto.getOrderDetailDtos());
            
            Long customerId = null;
            if (orderDto.getCustomer() != null && orderDto.getCustomer().getId() != null) {
                customerId = orderDto.getCustomer().getId();
            }

            Account cashierAccount = UserLoginUtil.getCurrentLogin();
            if (cashierAccount == null) {
                throw new ShopApiException(HttpStatus.UNAUTHORIZED, "Không xác định được tài khoản thanh toán");
            }

            Long effectiveBranchId = orderDto.getBranchId();
            boolean isVendorOrStaff = cashierAccount.getRole() != null && 
                (cashierAccount.getRole().getName() == com.project.WebAloTra.entity.enumClass.RoleName.ROLE_VENDOR || 
                 cashierAccount.getRole().getName() == com.project.WebAloTra.entity.enumClass.RoleName.ROLE_STAFF);

            if (isVendorOrStaff) {
                if (cashierAccount.getBranch() == null) {
                    throw new ShopApiException(HttpStatus.BAD_REQUEST, "Tài khoản nhân viên/quản lý chưa được gán chi nhánh");
                }
                effectiveBranchId = cashierAccount.getBranch().getId();
            }
            
            Double promotionDiscount = orderDto.getPromotionPrice();
            if (promotionDiscount == null || Double.isNaN(promotionDiscount) || promotionDiscount < 0) {
                promotionDiscount = 0.0;
            }

            StoredProcedureQuery query = entityManager.createStoredProcedureQuery("PROC_CREATE_ORDER");
            query.registerStoredProcedureParameter("p_billing_address", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_invoice_type", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_payment_method_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_customer_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_voucher_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_promotion_price", Double.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_order_id_vnpay", String.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_branch_id", Long.class, ParameterMode.IN);
            query.registerStoredProcedureParameter("p_order_details_json", String.class, ParameterMode.IN);
            
            query.registerStoredProcedureParameter("p_bill_id", Long.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_bill_code", String.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_final_amount", Double.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_error_code", Integer.class, ParameterMode.OUT);
            query.registerStoredProcedureParameter("p_error_msg", String.class, ParameterMode.OUT);

            query.setParameter("p_billing_address", orderDto.getBillingAddress());
            query.setParameter("p_invoice_type", "OFFLINE");
            query.setParameter("p_payment_method_id", orderDto.getPaymentMethodId());
            query.setParameter("p_customer_id", customerId);
            query.setParameter("p_voucher_id", orderDto.getVoucherId());
            query.setParameter("p_promotion_price", promotionDiscount);
            query.setParameter("p_order_id_vnpay", orderDto.getOrderId());
            query.setParameter("p_branch_id", effectiveBranchId);
            query.setParameter("p_order_details_json", orderDetailsJson);

            query.execute();

            Integer errorCode = (Integer) query.getOutputParameterValue("p_error_code");
            String errorMsg = (String) query.getOutputParameterValue("p_error_msg");

            if (errorCode != null && errorCode < 0) {
                throw new ShopApiException(HttpStatus.BAD_REQUEST, errorMsg);
            }

            Long outBillId = (Long) query.getOutputParameterValue("p_bill_id");
            
            OrderDto result = new OrderDto();
            if (outBillId != null) {
                result.setBillId(outBillId.toString());
            }
            result.setCustomer(orderDto.getCustomer());
            result.setInvoiceType(InvoiceType.OFFLINE);
            result.setBillStatus(BillStatus.HOAN_THANH);
            result.setPaymentMethodId(orderDto.getPaymentMethodId());
            result.setBillingAddress(orderDto.getBillingAddress());
            result.setPromotionPrice(promotionDiscount);
            result.setBranchId(effectiveBranchId);
            
            return result;

        } catch (Exception e) {
            if (e instanceof ShopApiException) throw (ShopApiException) e;
            throw new RuntimeException("Lỗi tạo đơn hàng admin: " + e.getMessage(), e);
        }
    }



	@Override
	public void deleteCart(Long id) {
		cartRepository.deleteById(id);
	}


}
