package com.project.WebAloTra.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.project.WebAloTra.entity.Cart;
import com.project.WebAloTra.entity.Product;
import com.project.WebAloTra.entity.ProductDetail;

import java.util.List;

@Repository
public interface CartRepository extends JpaRepository<Cart, Long> {

    // Đã dùng VPD (Virtual Private Database), tự lọc ở tầng DB
    boolean existsByProductDetail_Id(Long productDetailId);
    Cart findByProductDetail_Id(Long productDetailId);
    Cart findByProductDetail(ProductDetail productDetail);

    // ✅ [FIX] Xóa cart theo account_id cụ thể, tránh xóa cart của user khác
    void deleteByAccount_Id(Long accountId);

    // ✅ [FIX] Native query đảm bảo đúng tên cột trong Oracle, tránh bị VPD lọc sai
    @org.springframework.data.jpa.repository.Query(
        value = "SELECT * FROM cart WHERE account_id = :accountId",
        nativeQuery = true
    )
    List<Cart> findAllByAccount_Id(@org.springframework.data.repository.query.Param("accountId") Long accountId);
}
