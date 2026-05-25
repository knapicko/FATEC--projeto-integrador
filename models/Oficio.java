package com.consertaja.app;

import jakarta.persistence.*;

@Entity
@Table(name = "oficio")
public class Oficio {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_oficio;
    private String nome_oficio;
    private String categoria;

    public int getId_oficio() {
        return id_oficio;
    }
    public void setId_oficio(int id_oficio) {
        this.id_oficio = id_oficio;
    }
    public String getNome_oficio() {
        return nome_oficio;
    }
    public void setNome_oficio(String nome_oficio) {
        this.nome_oficio = nome_oficio;
    }
    public String getCategoria() {
        return categoria;
    }
    public void setCategoria(String categoria) {
        this.categoria = categoria;
    }

}