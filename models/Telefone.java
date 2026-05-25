package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Telefone {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_telefone;
    private int ddd;
    private int numero;
    private int autenticado;
    private Date data_alteracao;
    private String tipo_conta;
    
    public int getId_telefone() {
        return id_telefone;
    }
    public void setId_telefone(int id_telefone) {
        this.id_telefone = id_telefone;
    }
    public int getDdd() {
        return ddd;
    }
    public void setDdd(int ddd) {
        this.ddd = ddd;
    }
    public int getNumero() {
        return numero;
    }
    public void setNumero(int numero) {
        this.numero = numero;
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