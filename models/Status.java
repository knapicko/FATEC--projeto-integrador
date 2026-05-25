package com.consertaja.app;

import jakarta.persistence.*;

@Entity
public class Status {
    @Id
    private int id_status;
    private String tipo;
    private String nome;
    
    public int getId_status() {
        return id_status;
    }
    public void setId_status(int id_status) {
        this.id_status = id_status;
    }
    public String getTipo() {
        return tipo;
    }
    public void setTipo(String tipo) {
        this.tipo = tipo;
    }
    public String getNome() {
        return nome;
    }
    public void setNome(String nome) {
        this.nome = nome;
    }

    
}