package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Reembolso {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_reembolso;
    private double valor;
    private String motivo;
    private Date data_solicitacao;
    private Date data_reembolso;
    private String tipo;

    @ManyToOne
    @JoinColumn(name = "fk_status")
    private Status status;

    @ManyToOne
    @JoinColumn(name = "fk_pagamento")
    private PagamentoServico pagamento;

    public int getId_reembolso() {
        return id_reembolso;
    }

    public void setId_reembolso(int id_reembolso) {
        this.id_reembolso = id_reembolso;
    }

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public String getMotivo() {
        return motivo;
    }

    public void setMotivo(String motivo) {
        this.motivo = motivo;
    }

    public Date getData_solicitacao() {
        return data_solicitacao;
    }

    public void setData_solicitacao(Date data_solicitacao) {
        this.data_solicitacao = data_solicitacao;
    }

    public Date getData_reembolso() {
        return data_reembolso;
    }

    public void setData_reembolso(Date data_reembolso) {
        this.data_reembolso = data_reembolso;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public PagamentoServico getPagamento() {
        return pagamento;
    }

    public void setPagamento(PagamentoServico pagamento) {
        this.pagamento = pagamento;
    }


}