package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Usuario {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_usuario;
    private String nome;
    private Date data_nascimneto;
    private String cpf_cnpj;
    private String tipo_usuario;

    @ManyToOne
    @JoinColumn(name = "fk_imagem")
    private Imagens imagem;

    @ManyToOne
    @JoinColumn(name = "fk_senha")
    private Senha senha;

    @ManyToOne
    @JoinColumn(name = "fk_telefone")
    private Telefone telefone;

    @ManyToOne
    @JoinColumn(name = "fk_email")
    private Email email;

    public int getId_usuario() { return id_usuario; }
    public void setId_usuario(int id_usuario) { this.id_usuario = id_usuario; }
    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }
    public Date getData_nascimneto() { return data_nascimneto; }
    public void setData_nascimneto(Date data_nascimneto) { this.data_nascimneto = data_nascimneto; }
    public String getCpf_cnpj() { return cpf_cnpj; }
    public void setCpf_cnpj(String cpf_cnpj) { this.cpf_cnpj = cpf_cnpj; }
    public String getTipo_usuario() { return tipo_usuario; }
    public void setTipo_usuario(String tipo_usuario) { this.tipo_usuario = tipo_usuario; }
    public Imagens getImagem() { return imagem; }
    public void setImagem(Imagens imagem) { this.imagem = imagem; }
    public Senha getSenha() { return senha; }
    public void setSenha(Senha senha) { this.senha = senha; }
    public Telefone getTelefone() { return telefone; }
    public void setTelefone(Telefone telefone) { this.telefone = telefone; }
    public Email getEmail() { return email; }
    public void setEmail(Email email) { this.email = email; }
}