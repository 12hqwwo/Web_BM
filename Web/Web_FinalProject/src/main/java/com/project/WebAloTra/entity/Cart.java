package com.project.WebAloTra.entity;

import lombok.*;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;
import javax.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;

@Entity
@Table(name = "cart")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Cart implements Serializable {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "cart_seq")
    @SequenceGenerator(name = "cart_seq", sequenceName = "cart_seq", allocationSize = 1)
    private Long id;

    // 🔹 Liên kết đến bảng Account qua cột account_id
    // ✅ [FIX] @NotFound(IGNORE): nếu account bị xóa khỏi DB nhưng cart vẫn còn FK,
    //   Hibernate sẽ trả null thay vì throw EntityNotFoundException
    //   Lưu ý: @NotFound(IGNORE) luôn EAGER fetch (không dùng LAZY được)
    @ManyToOne
    @JoinColumn(name = "account_id", updatable = false)
    @NotFound(action = NotFoundAction.IGNORE)
    private Account account;

    // 🔹 Liên kết đến bảng ProductDetail qua cột product_detail_id
    @ManyToOne
    @JoinColumn(name = "product_detail_id")
    private ProductDetail productDetail;

    private int quantity;

    @Column(name = "create_date")
    private LocalDateTime createDate;

    @Column(name = "update_date")
    private LocalDateTime updateDate;
}
