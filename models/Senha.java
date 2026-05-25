package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Senha {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_senha;
    private String senha_hash;
    private int autenticado;
    private Date data_alteracao;
    private String tipo_conta;
    
    public int getId_senha() {
        return id_senha;
    }
    public void setId_senha(int id_senha) {
        this.id_senha = id_senha;
    }
    public String getSenha_hash() {
        return senha_hash;
    }
    public void setSenha_hash(String senha_hash) {
        this.senha_hash = senha_hash;
    }
    public int getAutenticado() {
        return autenticado;
    }
    public void setAutenticado(int autenticado) {
        this.autenticado = autenticado;
    }
    public Date getData_alteracao() {
        return data_alteracao;
    }
    public void setData_alteracao(Date data_alteracao) {
        this.data_alteracao = data_alteracao;
    }
    public String getTipo_conta() {
        return tipo_conta;
    }
    public void setTipo_conta(String tipo_conta) {
        this.tipo_conta = tipo_conta;
    }

    
}