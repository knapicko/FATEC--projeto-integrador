package com.consertaja.app;

import jakarta.persistence.*;

@Entity
public class Remetente {
    @Id
    private int id_Remetente;

    @ManyToOne
    @JoinColumn(name = "fk_usuario")
    private Usuario usuario;

    @ManyToOne
    @JoinColumn(name = "fk_empregado")
    private Empregado empregado;

    public int getId_Remetente() {
        return id_Remetente;
    }

    public void setId_Remetente(int id_Remetente) {
        this.id_Remetente = id_Remetente;
    }

    public Usuario getUsuario() {
        return usuario;
    }

    public void setUsuario(Usuario usuario) {
        this.usuario = usuario;
    }

    public Empregado getEmpregado() {
        return empregado;
    }

    public void setEmpregado(Empregado empregado) {
        this.empregado = empregado;
    }

    
}