package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
@Table(name = "servico_solicitado")
public class ServicoSolicitado {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_solicitado;
    private String descricao;
    private int quantidade;
    private Date prazo_max;
    private String prioridade;

    @ManyToOne
    @JoinColumn(name = "fk_lista_servicos")
    private ListaServicos listaServicos;

    @ManyToOne
    @JoinColumn(name = "fk_solicitacao")
    private SolicitacaoServico solicitacao;

    public int getId_solicitado() {
        return id_solicitado;
    }

    public void setId_solicitado(int id_solicitado) {
        this.id_solicitado = id_solicitado;
    }

    public String getDescricao() {
        return descricao;
    }

    public void setDescricao(String descricao) {
        this.descricao = descricao;
    }

    public int getQuantidade() {
        return quantidade;
    }

    public void setQuantidade(int quantidade) {
        this.quantidade = quantidade;
    }

    public Date getPrazo_max() {
        return prazo_max;
    }

    public void setPrazo_max(Date prazo_max) {
        this.prazo_max = prazo_max;
    }

    public String getPrioridade() {
        return prioridade;
    }

    public void setPrioridade(String prioridade) {
        this.prioridade = prioridade;
    }

    public ListaServicos getListaServicos() {
        return listaServicos;
    }

    public void setListaServicos(ListaServicos listaServicos) {
        this.listaServicos = listaServicos;
    }

    public SolicitacaoServico getSolicitacao() {
        return solicitacao;
    }

    public void setSolicitacao(SolicitacaoServico solicitacao) {
        this.solicitacao = solicitacao;
    }

    
}