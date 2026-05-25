package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Parcelas {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_parcela;
    private int numero_parcela;
    private double valor;
    private Date data_vencimento;
    private Date data_pagamento;

    @ManyToOne
    @JoinColumn(name = "fk_pagamento")
    private PagamentoServico pagamento;

    @ManyToOne
    @JoinColumn(name = "fk_status")
    private Status status;

    public int getId_parcela() {
        return id_parcela;
    }

    public void setId_parcela(int id_parcela) {
        this.id_parcela = id_parcela;
    }

    public int getNumero_parcela() {
        return numero_parcela;
    }

    public void setNumero_parcela(int numero_parcela) {
        this.numero_parcela = numero_parcela;
    }

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public Date getData_vencimento() {
        return data_vencimento;
    }

    public void setData_vencimento(Date data_vencimento) {
        this.data_vencimento = data_vencimento;
    }

    public Date getData_pagamento() {
        return data_pagamento;
    }

    public void setData_pagamento(Date data_pagamento) {
        this.data_pagamento = data_pagamento;
    }

    public PagamentoServico getPagamento() {
        return pagamento;
    }

    public void setPagamento(PagamentoServico pagamento) {
        this.pagamento = pagamento;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    
}