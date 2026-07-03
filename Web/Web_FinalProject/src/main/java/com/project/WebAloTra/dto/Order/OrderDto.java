package com.project.WebAloTra.dto.Order;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

import com.project.WebAloTra.dto.CustomerDto.CustomerDto;
import com.project.WebAloTra.entity.enumClass.BillStatus;
import com.project.WebAloTra.entity.enumClass.InvoiceType;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class OrderDto {
    private String billId;
    private CustomerDto customer;
    private InvoiceType invoiceType;
    private BillStatus billStatus;
    private Long paymentMethodId;
    private String billingAddress;
    private double promotionPrice;
    private Long voucherId;
    private Long accountId;
    private String orderId;
    private Long branchId;

    private List<OrderDetailDto> orderDetailDtos;
}
