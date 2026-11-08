alter table public.ass_servicos_lista
  add column if not exists imagens_anexadas_cliente text[] not null default '{}';

alter table public.solicitacoes
  add column if not exists imagens_anexadas_cliente text[] not null default '{}';

insert into storage.buckets (id, name, public)
values ('Imagens Anexadas Cliente', 'Imagens Anexadas Cliente', true)
on conflict (id) do update set public = true;

create policy "Cliente pode enviar anexos da solicitação"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'Imagens Anexadas Cliente'
  and (storage.foldername(name))[1] = 'solicitacao-temp'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "Anexos do cliente podem ser lidos"
on storage.objects for select to authenticated
using (bucket_id = 'Imagens Anexadas Cliente');
