package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Avaliacao {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_avaliacao;
    private String estrelas;
    private String descricao;
    private Date data_avaliacao;

    @ManyToOne
    @JoinColumn(name = "fk_solicitado")
    private ServicoSolicitado servicoSolicitado;

    @ManyToOne
    @JoinColumn(name = "fk_usuario")
    private Usuario usuario;

    public int getId_avaliacao() {
        return id_avaliacao;
    }

    public void setId_avaliacao(int id_avaliacao) {
        this.id_avaliacao = id_avaliacao;
    }

    public String getEstrelas() {
        return estrelas;
    }

    public void setEstrelas(String estrelas) {
        this.estrelas = estrelas;
    }

    public String getDescricao() {
        return descricao;
    }

    public void setDescricao(String descricao) {
        this.descricao = descricao;
    }

    public Date getData_avaliacao() {
        return data_avaliacao;
    }

    public void setData_avaliacao(Date data_avaliacao) {
        this.data_avaliacao = data_avaliacao;
    }

    public ServicoSolicitado getServicoSolicitado() {
        return servicoSolicitado;
    }

    public void setServicoSolicitado(ServicoSolicitado servicoSolicitado) {
        this.servicoSolicitado = servicoSolicitado;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public void setUsuario(Usuario usuario) {
        this.usuario = usuario;
    }

    
}