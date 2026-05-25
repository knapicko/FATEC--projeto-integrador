package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
@Table(name = "Pagamento_Serviço")
public class PagamentoServico {
    @Id
    private int id_pagamento;
    private double valor_total;
    private String metodo; 
    private Date data_pagamento;
    private Date data_vencimento;

    @Column(columnDefinition = "MEDIUMBLOB")
    private byte[] anexo_nf;

    @ManyToOne
    @JoinColumn(name = "fk_solicitacao")
    private SolicitacaoServico solicitacao;

    @ManyToOne
    @JoinColumn(name = "fk_status")
    private Status status;

    public int getId_pagamento() { return id_pagamento; }
    public void setId_pagamento(int id_pagamento) { this.id_pagamento = id_pagamento; }
    public double getValor_total() { return valor_total; }
    public void setValor_total(double valor_total) { this.valor_total = valor_total; }
    public String getMetodo() { return metodo; }
    public void setMetodo(String metodo) { this.metodo = metodo; }
    public Date getData_pagamento() { return data_pagamento; }
    public void setData_pagamento(Date data_pagamento) { this.data_pagamento = data_pagamento; }
    public Date getData_vencimento() { return data_vencimento; }
    public void setData_vencimento(Date data_vencimento) { this.data_vencimento = data_vencimento; }
    public byte[] getAnexo_nf() { return anexo_nf; }
    public void setAnexo_nf(byte[] anexo_nf) { this.anexo_nf = anexo_nf; }
    public SolicitacaoServico getSolicitacao() { return solicitacao; }
    public void setSolicitacao(SolicitacaoServico solicitacao) { this.solicitacao = solicitacao; }
    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
}