package com.consertaja.app;

import jakarta.persistence.*;

@Entity
public class Imagens {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_imagem;

    @Column(columnDefinition = "MEDIUMBLOB", nullable = false)
    private byte[] anexo;

    public int getId_imagem() { return id_imagem; }
    public void setId_imagem(int id_imagem) { this.id_imagem = id_imagem; }
    public byte[] getAnexo() { return anexo; }
    public void setAnexo(byte[] anexo) { this.anexo = anexo; }

    
}