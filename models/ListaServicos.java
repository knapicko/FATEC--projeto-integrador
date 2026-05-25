package com.consertaja.app;

import jakarta.persistence.*;

@Entity
@Table(name = "Lista_Serviços")
public class ListaServicos {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_lista_servicos;
    private String nome_servico;
    private String detalhes_servico;
    private double valor;
    private String tipo_servico;

    @ManyToOne
    @JoinColumn(name = "fk_oficio")
    private Oficio oficio;

    // Getters e Setters
    public int getId_lista_servicos() { return id_lista_servicos; }
    public void setId_lista_servicos(int id_lista_servicos) { this.id_lista_servicos = id_lista_servicos; }
    public String getNome_servico() { return nome_servico; }
    public void setNome_servico(String nome_servico) { this.nome_servico = nome_servico; }
    public String getDetalhes_servico() { return detalhes_servico; }
    public void setDetalhes_servico(String detalhes_servico) { this.detalhes_servico = detalhes_servico; }
    public double getValor() { return valor; }
    public void setValor(double valor) { this.valor = valor; }
    public Oficio getOficio() { return oficio; }
    public void setOficio(Oficio oficio) { this.oficio = oficio; }
    public String getTipo_servico() { return tipo_servico; }
    public void setTipo_servico(String tipo_servico) { this.tipo_servico = tipo_servico; }
}