package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Empregado {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_empregado;
    private String nome;
    private Date data_nascimneto;
    private String cpf_cnpj;
    private String função;
    private Date data_admissao;

    @ManyToOne
    @JoinColumn(name = "fk_perfil")
    private Perfil perfil;

    @ManyToOne
    @JoinColumn(name = "fk_senha")
    private Senha senha;

    @ManyToOne
    @JoinColumn(name = "fk_email")
    private Email email;

    @ManyToOne
    @JoinColumn(name = "fk_telefone")
    private Telefone telefone;

    public int getId_empregado() {
        return id_empregado;
    }

    public void setId_empregado(int id_empregado) {
        this.id_empregado = id_empregado;
    }

    public String getNome() {
        return nome;
    }

    public void setNome(String nome) {
        this.nome = nome;
    }

    public Date getData_nascimneto() {
        return data_nascimneto;
    }

    public void setData_nascimneto(Date data_nascimneto) {
        this.data_nascimneto = data_nascimneto;
    }

    public String getCpf_cnpj() {
        return cpf_cnpj;
    }

    public void setCpf_cnpj(String cpf_cnpj) {
        this.cpf_cnpj = cpf_cnpj;
    }

    public String getFunção() {
        return função;
    }

    public void setFunção(String função) {
        this.função = função;
    }

    public Date getData_admissao() {
        return data_admissao;
    }

    public void setData_admissao(Date data_admissao) {
        this.data_admissao = data_admissao;
    }

    public Perfil getPerfil() {
        return perfil;
    }

    public void setPerfil(Perfil perfil) {
        this.perfil = perfil;
    }

    public Senha getSenha() {
        return senha;
    }

    public void setSenha(Senha senha) {
        this.senha = senha;
    }

    public Email getEmail() {
        return email;
    }

    public void setEmail(Email email) {
        this.email = email;
    }

    public Telefone getTelefone() {
        return telefone;
    }

    public void setTelefone(Telefone telefone) {
        this.telefone = telefone;
    }

    
}