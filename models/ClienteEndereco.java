package com.consertaja.app;

import jakarta.persistence.*;
import java.io.Serializable;

@Entity
@Table(name = "cliente_endereco")
public class ClienteEndereco implements Serializable {
    @Id
    @ManyToOne
    @JoinColumn(name = "fk_usuario")
    private Usuario usuario;

    @Id
    @ManyToOne
    @JoinColumn(name = "fk_endereco")
    private Endereco endereco;

    private String apelido_endereco;

    public Usuario getUsuario() {
        return usuario;
    }

    public void setUsuario(Usuario usuario) {
        this.usuario = usuario;
    }

    public Endereco getEndereco() {
        return endereco;
    }

    public void setEndereco(Endereco endereco) {
        this.endereco = endereco;
    }

    public String getApelido_endereco() {
        return apelido_endereco;
    }

    public void setApelido_endereco(String apelido_endereco) {
        this.apelido_endereco = apelido_endereco;
    }

    
}