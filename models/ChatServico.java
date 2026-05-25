package com.consertaja.app;

import jakarta.persistence.*;
import java.io.Serializable;

@Entity
@Table(name = "chat_servico")
public class ChatServico implements Serializable {
    @Id
    @ManyToOne
    @JoinColumn(name = "fk_chat")
    private Chat chat;

    @Id
    @ManyToOne
    @JoinColumn(name = "fk_solicitacao")
    private SolicitacaoServico solicitacao;

    public Chat getChat() {
        return chat;
    }

    public void setChat(Chat chat) {
        this.chat = chat;
    }

    public SolicitacaoServico getSolicitacao() {
        return solicitacao;
    }

    public void setSolicitacao(SolicitacaoServico solicitacao) {
        this.solicitacao = solicitacao;
    }

    
}