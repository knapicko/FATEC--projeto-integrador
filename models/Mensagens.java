package com.consertaja.app;

import jakarta.persistence.*;
import java.util.Date;

@Entity
public class Mensagens {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private int id_mensagem;
    private String tipo;
    private String conteudo_texto;
    private Date data_envio;

    @ManyToOne
    @JoinColumn(name = "fk_arquivo")
    private ArquivosChat arquivo;

    @ManyToOne
    @JoinColumn(name = "fk_chat")
    private Chat chat;

    @ManyToOne
    @JoinColumn(name = "fk_remetente")
    private Remetente remetente;

    public int getId_mensagem() {
        return id_mensagem;
    }

    public void setId_mensagem(int id_mensagem) {
        this.id_mensagem = id_mensagem;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public String getConteudo_texto() {
        return conteudo_texto;
    }

    public void setConteudo_texto(String conteudo_texto) {
        this.conteudo_texto = conteudo_texto;
    }

    public Date getData_envio() {
        return data_envio;
    }

    public void setData_envio(Date data_envio) {
        this.data_envio = data_envio;
    }

    public ArquivosChat getArquivo() {
        return arquivo;
    }

    public void setArquivo(ArquivosChat arquivo) {
        this.arquivo = arquivo;
    }

    public Chat getChat() {
        return chat;
    }

    public void setChat(Chat chat) {
        this.chat = chat;
    }

    public Remetente getRemetente() {
        return remetente;
    }

    public void setRemetente(Remetente remetente) {
        this.remetente = remetente;
    }

    
}