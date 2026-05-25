package com.consertaja.app;

import jakarta.persistence.*;

@Entity
@Table(name = "arquivos_chat")
public class ArquivosChat {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_arquivo;
    private String tipo; // ENUM 'Imagem', 'Audio', 'Documento'
    
    @Column(columnDefinition = "MEDIUMBLOB")
    private byte[] arquivo;

    public int getId_arquivo() {
        return id_arquivo;
    }

    public void setId_arquivo(int id_arquivo) {
        this.id_arquivo = id_arquivo;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public byte[] getArquivo() {
        return arquivo;
    }

    public void setArquivo(byte[] arquivo) {
        this.arquivo = arquivo;
    }

    
}