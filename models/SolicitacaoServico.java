package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
@Table(name = "Solicitação_Serviço")
public class SolicitacaoServico {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_solicitacao;
    private Date data_solicitacao;
    private Date data_aceite;
    private Date data_finalizacao;
    private double valor_final;

    @ManyToOne
    @JoinColumn(name = "fk_status")
    private Status status;

    @ManyToOne
    @JoinColumn(name = "fk_usuario")
    private Usuario usuario;

    @ManyToOne
    @JoinColumn(name = "fk_empregado")
    private Empregado empregado;

    public int getId_solicitacao() { return id_solicitacao; }
    public void setId_solicitacao(int id_solicitacao) { this.id_solicitacao = id_solicitacao; }
    public Date getData_solicitacao() { return data_solicitacao; }
    public void setData_solicitacao(Date data_solicitacao) { this.data_solicitacao = data_solicitacao; }
    public Date getData_aceite() { return data_aceite; }
    public void setData_aceite(Date data_aceite) { this.data_aceite = data_aceite; }
    public Date getData_finalizacao() { return data_finalizacao; }
    public void setData_finalizacao(Date data_finalizacao) { this.data_finalizacao = data_finalizacao; }
    public double getValor_final() { return valor_final; }
    public void setValor_final(double valor_final) { this.valor_final = valor_final; }
    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
    public Usuario getUsuario() { return usuario; }
    public void setUsuario(Usuario usuario) { this.usuario = usuario; }
    public Empregado getEmpregado() { return empregado; }
    public void setEmpregado(Empregado empregado) { this.empregado = empregado; }
}