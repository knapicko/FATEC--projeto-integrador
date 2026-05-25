package com.consertaja.app;

import jakarta.persistence.*;

@Entity
public class Perfil {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_perfil;
    private String descricao;

    @ManyToOne
    @JoinColumn(name = "fk_imagem")
    private Imagens imagem;

    public int getId_perfil() {
        return id_perfil;
    }

    public void setId_perfil(int id_perfil) {
        this.id_perfil = id_perfil;
    }

    public String getDescricao() {
        return descricao;
    }

    public void setDescricao(String descricao) {
        this.descricao = descricao;
    }

    public Imagens getImagem() {
        return imagem;
    }

    public void setImagem(Imagens imagem) {
        this.imagem = imagem;
    }

    
}