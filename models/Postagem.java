package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Postagem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_postagem;
    private String descricao;
    private Date data;

    @ManyToOne
    @JoinColumn(name = "fk_perfil")
    private Perfil perfil;

    @ManyToOne
    @JoinColumn(name = "fk_imagem")
    private Imagens imagem;

    public int getId_postagem() {
        return id_postagem;
    }

    public void setId_postagem(int id_postagem) {
        this.id_postagem = id_postagem;
    }

    public String getDescricao() {
        return descricao;
    }

    public void setDescricao(String descricao) {
        this.descricao = descricao;
    }

    public Date getData() {
        return data;
    }

    public void setData(Date data) {
        this.data = data;
    }

    public Perfil getPerfil() {
        return perfil;
    }

    public void setPerfil(Perfil perfil) {
        this.perfil = perfil;
    }

    public Imagens getImagem() {
        return imagem;
    }

    public void setImagem(Imagens imagem) {
        this.imagem = imagem;
    }

 
}