package com.project.WebAloTra.controller.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import com.project.WebAloTra.dto.AddressShipping.AddressShippingDto;
import com.project.WebAloTra.dto.Cart.CartDto;
import com.project.WebAloTra.dto.Cart.GuestCartDto;
import com.project.WebAloTra.dto.Cart.ProductCart;
import com.project.WebAloTra.dto.DiscountCode.DiscountCodeDto;
import com.project.WebAloTra.entity.Product;
import com.project.WebAloTra.exception.NotFoundException;
import com.project.WebAloTra.repository.ProductRepository;
import com.project.WebAloTra.service.AddressShippingService;
import com.project.WebAloTra.service.BillService;
import com.project.WebAloTra.service.CartService;
import com.project.WebAloTra.service.DiscountCodeService;
import com.project.WebAloTra.service.BranchService;
import com.project.WebAloTra.entity.Branch;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import javax.servlet.http.HttpSession;

@Controller
public class ShoppingCartController {
	private final CartService cartService;
	private final BillService billService;
	private final DiscountCodeService discountCodeService;
	private final AddressShippingService addressShippingService;
	private final ProductRepository productRepository;
	private final BranchService branchService;

	public ShoppingCartController(CartService cartService, BillService billService,
			DiscountCodeService discountCodeService, AddressShippingService addressShippingService,
			ProductRepository productRepository, BranchService branchService) {
		this.cartService = cartService;
		this.billService = billService;
		this.discountCodeService = discountCodeService;
		this.addressShippingService = addressShippingService;
		this.productRepository = productRepository;
		this.branchService = branchService;
	}

	@GetMapping("/shoping-cart")
	public String viewShoppingCart(Model model, HttpSession session) {
		List<CartDto> cartDtoList = new ArrayList<>();

		// ✅ [FIX] Kiểm tra login trước, không dựa vào số lượng cart
		org.springframework.security.core.Authentication auth =
				org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
		boolean isGuest = (auth == null || !auth.isAuthenticated()
				|| "anonymousUser".equals(auth.getPrincipal()));

		if (!isGuest) {
			// ✅ User đăng nhập → lấy giỏ hàng từ DB (kể cả rỗng)
			try {
				List<CartDto> userCart = cartService.getAllCartByAccountId();
				if (userCart != null) {
					cartDtoList = userCart;
				}
			} catch (Exception e) {
				// Log lỗi nhưng vẫn tiếp tục, hiển thị cart rỗng
				System.err.println("❌ Lỗi khi lấy giỏ hàng: " + e.getMessage());
			}
		} else {
			// ✅ Guest → lấy giỏ hàng từ session
			@SuppressWarnings("unchecked")
			List<GuestCartDto> guestCart = (List<GuestCartDto>) session.getAttribute("guestCart");

			if (guestCart != null && !guestCart.isEmpty()) {
				for (GuestCartDto g : guestCart) {
					CartDto c = new CartDto();
					c.setId(g.getProductId());
					c.setQuantity(g.getQuantity());

					ProductCart p = new ProductCart();
					p.setProductId(g.getProductId());
					p.setName(g.getName());
					p.setImageUrl(g.getImageUrl());
					p.setPrice(g.getPrice());
					c.setProduct(p);
					c.setDetail(null);
					cartDtoList.add(c);
				}
			}
		}

		// ✅ Mã giảm giá và địa chỉ (nếu có)
		Page<DiscountCodeDto> discountCodeList = Page.empty();
		try {
			discountCodeList = discountCodeService.getAllAvailableDiscountCode(PageRequest.of(0, 15));
		} catch (Exception ignored) {
		}

		List<AddressShippingDto> addressShippingDtos = new ArrayList<>();
		try {
			addressShippingDtos = addressShippingService.getAddressShippingByAccountId();
		} catch (Exception ignored) {
		}

		List<Branch> activeBranches = new ArrayList<>();
		try {
			activeBranches = branchService.getActiveBranches();
		} catch (Exception ignored) {
		}

		// ✅ Gửi dữ liệu ra view
		model.addAttribute("discountCodes", discountCodeList.getContent());
		model.addAttribute("addressShippings", addressShippingDtos);
		model.addAttribute("carts", cartDtoList);
		model.addAttribute("isGuest", isGuest);
		model.addAttribute("branches", activeBranches);

		return "user/shoping-cart";
	}

	@ResponseBody
	@PostMapping("/api/addToCart")
	public void addToCart(@RequestBody CartDto cartDto) throws NotFoundException {
		cartService.addToCart(cartDto);
	}

	@ResponseBody
	@PostMapping("/api/deleteCart/{id}")
	public void deleteCart(@PathVariable Long id, HttpSession session) {
		// ✅ Kiểm tra xem có phải guest không
		List<GuestCartDto> guestCart = (List<GuestCartDto>) session.getAttribute("guestCart");

		if (guestCart != null && !guestCart.isEmpty()) {
			// ✅ Xóa khỏi session của guest
			guestCart.removeIf(item -> item.getProductId().equals(id));
			session.setAttribute("guestCart", guestCart);
		} else {
			// ✅ Xóa khỏi DB của user đăng nhập
			cartService.deleteCart(id);
		}
	}

	@ResponseBody
	@PostMapping("/api/updateCart")
	public void updateCart(@RequestBody CartDto cartDto, HttpSession session) throws NotFoundException {
		// ✅ Kiểm tra xem có phải guest không
		List<GuestCartDto> guestCart = (List<GuestCartDto>) session.getAttribute("guestCart");

		if (guestCart != null && !guestCart.isEmpty()) {
			// ✅ Cập nhật session của guest
			for (GuestCartDto item : guestCart) {
				if (item.getProductId().equals(cartDto.getId())) {
					item.setQuantity(cartDto.getQuantity());
					break;
				}
			}
			session.setAttribute("guestCart", guestCart);
		} else {
			// ✅ Cập nhật DB của user đăng nhập
			cartService.updateCart(cartDto);
		}
	}
}