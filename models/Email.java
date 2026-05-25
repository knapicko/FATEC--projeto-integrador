package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Email {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_email;
    private String endereco_email;
    private int verificarAutenticacao;
    private Date data_alteracao;
    private String tipo_conta;
    
    public int getId_email() {
        return id_email;
    }
    public void setId_email(int id_email) {
        this.id_email = id_email;
    }
    public String getEndereco_email() {
        return endereco_email;
    }
    public void setEndereco_email(String endereco_email) {
        this.endereco_email = endereco_email;
    }
    public int getVerificarAutenticacao() {
        return verificarAutenticacao;
    }
    public void setVerificarAutenticacao(int verificarAutenticacao) {
        this.verificarAutenticacao = verificarAutenticacao;
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