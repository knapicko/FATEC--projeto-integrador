import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

Deno.serve(async (request) => {
  console.log('Requisicao recebida:', request.method);

  if (request.method === 'OPTIONS') {
    console.log('Respondendo ao preflight CORS.');
    return new Response('ok', { status: 200, headers: corsHeaders });
  }

  const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY');
  const anonKey = Deno.env.get('ANON_KEY');
  console.log('SERVICE_ROLE_KEY configurada:', Boolean(serviceRoleKey));

  if (!serviceRoleKey) {
    console.error('Secret SERVICE_ROLE_KEY nao configurada.');
    return json(
      { error: 'Configuracao interna ausente: SERVICE_ROLE_KEY.' },
      500,
    );
  }

  if (!anonKey) {
    console.error('Secret ANON_KEY nao configurada.');
    return json(
      { error: 'Configuracao interna ausente: ANON_KEY.' },
      500,
    );
  }

  const service = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
  );

  const authorization = request.headers.get('Authorization');
  console.log(
    'Authorization recebido:',
    Boolean(authorization),
    'formato Bearer:',
    authorization?.startsWith('Bearer ') ?? false,
  );

  if (!authorization?.startsWith('Bearer ')) {
    console.error('Authorization ausente ou invalido.');
    return json({ error: 'Nao autenticado.' }, 401);
  }

  const token = authorization.substring('Bearer '.length).trim();
  const authClient = createClient(Deno.env.get('SUPABASE_URL')!, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: authData, error: authError } =
    await authClient.auth.getUser(token);

  console.log('Usuario autenticado:', authData.user?.id ?? null);
  console.log('Erro de autenticacao:', authError?.message ?? null);

  if (authError || !authData.user) {
    return json({ error: 'Sessao invalida.' }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (error) {
    console.error('JSON invalido:', error);
    return json({ error: 'Corpo da requisicao invalido.' }, 400);
  }

  const cpf = String(body.cpf ?? '').replace(/\D/g, '');
  const senha = String(body.senha ?? '');
  const grupoId = Number(body.id_grupo_empresa);

  console.log('Dados recebidos:', {
    cpfInformado: Boolean(cpf),
    tamanhoCpf: cpf.length,
    grupoId,
    senhaInformada: Boolean(senha),
  });

  if (cpf.length !== 11 || !grupoId || senha.length < 8) {
    return json({ error: 'Dados invalidos para criacao da conta.' }, 400);
  }

  const { data: dono, error: donoError } = await service
    .from('usuarios')
    .select('id_usuario')
    .eq('auth_id', authData.user.id)
    .maybeSingle();

  console.log('Proprietario encontrado:', Boolean(dono));
  console.log('Erro ao buscar proprietario:', donoError?.message ?? null);

  if (donoError) {
    return json(
      { error: `Erro ao buscar proprietario: ${donoError.message}` },
      500,
    );
  }
  if (!dono) {
    return json({ error: 'Usuario proprietario nao encontrado.' }, 403);
  }

  const { data: donoProf, error: donoProfError } = await service
    .from('dados_profissionais')
    .select('id_profissional, fk_grupo_empresa')
    .eq('fk_usuario', dono.id_usuario)
    .maybeSingle();

  console.log('Profissional proprietario encontrado:', Boolean(donoProf));
  console.log('Grupo do proprietario:', donoProf?.fk_grupo_empresa ?? null);
  console.log(
    'Erro ao buscar profissional proprietario:',
    donoProfError?.message ?? null,
  );

  if (donoProfError) {
    return json(
      {
        error: `Erro ao buscar profissional proprietario: ${donoProfError.message}`,
      },
      500,
    );
  }
  if (!donoProf || donoProf.fk_grupo_empresa !== grupoId) {
    return json(
      { error: 'Apenas o proprietario da empresa pode criar membros.' },
      403,
    );
  }

  const { data: pessoaExistente, error: pessoaExistenteError } = await service
    .from('pessoa_fisica')
    .select('id_pessoa_fisica')
    .eq('cpf', cpf)
    .maybeSingle();

  console.log('CPF ja cadastrado:', Boolean(pessoaExistente));
  console.log('Erro ao verificar CPF:', pessoaExistenteError?.message ?? null);

  if (pessoaExistenteError) {
    return json(
      { error: `Erro ao verificar CPF: ${pessoaExistenteError.message}` },
      500,
    );
  }
  if (pessoaExistente) {
    return json({ error: 'Este CPF ja esta cadastrado.' }, 409);
  }

  const syntheticEmail = `cpf.${cpf}@conta.consertaja.local`;
  console.log('Criando usuario no Supabase Auth.');

  const { data: novoAuth, error: createAuthError } =
    await service.auth.admin.createUser({
      email: syntheticEmail,
      password: senha,
      email_confirm: true,
      user_metadata: {
        tipo_conta: 'Profissional',
        conta_criada_pela_empresa: true,
      },
    });

  console.log('Usuario Auth criado:', Boolean(novoAuth.user));
  console.log('Erro ao criar usuario Auth:', createAuthError?.message ?? null);

  if (createAuthError || !novoAuth.user) {
    return json(
      {
        error: createAuthError?.message ?? 'Falha ao criar autenticacao.',
      },
      400,
    );
  }

  try {
    console.log('Criando registro em emails.');
    const emailRow = await service
      .from('emails')
      .insert({ endereco_email: syntheticEmail, fk_status: 1 })
      .select('id_email')
      .single();
    if (emailRow.error) throw emailRow.error;

    console.log('Criando registro em pessoa_fisica.');
    const pessoa = await service
      .from('pessoa_fisica')
      .insert({ cpf })
      .select('id_pessoa_fisica')
      .single();
    if (pessoa.error) throw pessoa.error;

    console.log('Criando registro em ass_tipo_pessoa.');
    const tipoPessoa = await service
      .from('ass_tipo_pessoa')
      .insert({
        tipo: 'Fisica',
        fk_pessoa_fisica: pessoa.data.id_pessoa_fisica,
        fk_pessoa_juridica: null,
      })
      .select('id_tipo_pessoa')
      .single();
    if (tipoPessoa.error) throw tipoPessoa.error;

    console.log('Criando registro em usuarios.');
    const usuario = await service
      .from('usuarios')
      .insert({
        nome: `Profissional ${cpf.slice(-4)}`,
        data_criacao: new Date().toISOString(),
        tipo_conta: 'Profissional',
        fk_email: emailRow.data.id_email,
        fk_tipo_pessoa: tipoPessoa.data.id_tipo_pessoa,
        auth_id: novoAuth.user.id,
      })
      .select('id_usuario')
      .single();
    if (usuario.error) throw usuario.error;

    console.log('Criando registro em dados_profissionais.');
    const profissional = await service.from('dados_profissionais').insert({
      fk_usuario: usuario.data.id_usuario,
      fk_grupo_empresa: grupoId,
      rosto_validado: false,
      data_admissao: new Date().toISOString().split('T')[0],
    });
    if (profissional.error) throw profissional.error;

    console.log('Conta profissional criada com sucesso.');
    return json({ success: true });
  } catch (error) {
    console.error('Erro ao criar perfil relacional:', error);
    await service.auth.admin.deleteUser(novoAuth.user.id);
    return json(
      {
        error:
          error instanceof Error ? error.message : 'Falha ao criar perfil.',
      },
      400,
    );
  }
});
