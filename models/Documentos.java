package com.consertaja.app;

import jakarta.persistence.*;

@Entity
public class Documentos {
    @Id
    private int id_documento;
    private String nome_documento;
    private String tipo;
    
    @Column(columnDefinition = "MEDIUMBLOB")
    private byte[] anexo;

    @ManyToOne
    @JoinColumn(name = "fk_empregado")
    private Empregado empregado;

    public int getId_documento() {
        return id_documento;
    }

    public void setId_documento(int id_documento) {
        this.id_documento = id_documento;
    }

    public String getNome_documento() {
        return nome_documento;
    }

    public void setNome_documento(String nome_documento) {
        this.nome_documento = nome_documento;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public byte[] getAnexo() {
        return anexo;
    }

    public void setAnexo(byte[] anexo) {
        this.anexo = anexo;
    }

    public Empregado getEmpregado() {
        return empregado;
    }

    public void setEmpregado(Empregado empregado) {
        this.empregado = empregado;
    }

    
}