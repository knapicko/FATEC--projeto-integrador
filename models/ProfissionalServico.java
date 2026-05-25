package com.consertaja.app;

import jakarta.persistence.*;

@Entity
@Table(name = "profissional_servico")
public class ProfissionalServico {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_profissional;

    @ManyToOne
    @JoinColumn(name = "fk_solicitado")
    private ServicoSolicitado servicoSolicitado;

    @ManyToOne
    @JoinColumn(name = "fk_empregado")
    private Empregado empregado;

    public int getId_profissional() {
        return id_profissional;
    }

    public void setId_profissional(int id_profissional) {
        this.id_profissional = id_profissional;
    }

    public ServicoSolicitado getServicoSolicitado() {
        return servicoSolicitado;
    }

    public void setServicoSolicitado(ServicoSolicitado servicoSolicitado) {
        this.servicoSolicitado = servicoSolicitado;
    }

    public Empregado getEmpregado() {
        return empregado;
    }

    public void setEmpregado(Empregado empregado) {
        this.empregado = empregado;
    }

    
}