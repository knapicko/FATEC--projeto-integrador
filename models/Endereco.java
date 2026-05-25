package com.consertaja.app;

import jakarta.persistence.*;

@Entity
@Table(name = "Endereço")
public class Endereco {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_endereco;
    private String cep;
    private String logradouro;
    private int numero;
    private String complemento;
    private String bairro;

    @ManyToOne
    @JoinColumn(name = "fk_cidade")
    private Cidade cidade;

    public int getId_endereco() { return id_endereco; }
    public void setId_endereco(int id_endereco) { this.id_endereco = id_endereco; }
    public String getCep() { return cep; }
    public void setCep(String cep) { this.cep = cep; }
    public String getLogradouro() { return logradouro; }
    public void setLogradouro(String logradouro) { this.logradouro = logradouro; }
    public int getNumero() { return numero; }
    public void setNumero(int numero) { this.numero = numero; }
    public String getComplemento() { return complemento; }
    public void setComplemento(String complemento) { this.complemento = complemento; }
    public String getBairro() { return bairro; }
    public void setBairro(String bairro) { this.bairro = bairro; }
    public Cidade getCidade() { return cidade; }
    public void setCidade(Cidade cidade) { this.cidade = cidade; }
}