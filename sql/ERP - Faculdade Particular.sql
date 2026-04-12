-- ================================================================
-- FacGESC — Sistema de Gestão de Faculdade Particular
-- Script DDL Completo — Versão 2.0
-- Banco de Dados: MySQL 8.0+
-- Padrão: snake_case | prefixos pk_, fk_, tb_
-- Normalização: 3FN
-- Chaves compostas aplicadas onde o negócio garante unicidade
-- ================================================================

CREATE DATABASE IF NOT EXISTS facgesc
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE facgesc;

-- ================================================================
-- ENUMS (simulados com ENUM no MySQL)
-- ================================================================
SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- DROP
-- =====================================================
DROP TABLE IF EXISTS tb_pagamento_despesa;
DROP TABLE IF EXISTS tb_despesa_operacional;
DROP TABLE IF EXISTS tb_fornecedor_servico;
DROP TABLE IF EXISTS tb_controle_inadimplencia;
DROP TABLE IF EXISTS tb_recebimento;
DROP TABLE IF EXISTS tb_parcela_mensalidade;
DROP TABLE IF EXISTS tb_contrato_academico;
DROP TABLE IF EXISTS tb_bolsa_desconto;
DROP TABLE IF EXISTS tb_tabela_mensalidade;
DROP TABLE IF EXISTS tb_folha_pagamento;
DROP TABLE IF EXISTS tb_periodo_ferias;
DROP TABLE IF EXISTS tb_registro_ponto;
DROP TABLE IF EXISTS tb_alocacao_setor;
DROP TABLE IF EXISTS tb_docente;
DROP TABLE IF EXISTS tb_colaborador;
DROP TABLE IF EXISTS tb_setor_institucional;
DROP TABLE IF EXISTS tb_cargo_funcional;
DROP TABLE IF EXISTS tb_ocorrencia_disciplinar;
DROP TABLE IF EXISTS tb_frequencia_aula;
DROP TABLE IF EXISTS tb_aula_registrada;
DROP TABLE IF EXISTS tb_nota_avaliacao;
DROP TABLE IF EXISTS tb_avaliacao_programada;
DROP TABLE IF EXISTS tb_matricula_estudante;
DROP TABLE IF EXISTS tb_oferta_disciplina;
DROP TABLE IF EXISTS tb_estudante_responsavel;
DROP TABLE IF EXISTS tb_responsavel_financeiro;
DROP TABLE IF EXISTS tb_historico_situacao_estudante;
DROP TABLE IF EXISTS tb_estudante;
DROP TABLE IF EXISTS tb_periodo_letivo;
DROP TABLE IF EXISTS tb_grade_curricular;
DROP TABLE IF EXISTS tb_disciplina_catalogo;
DROP TABLE IF EXISTS tb_curso_graduacao;
DROP TABLE IF EXISTS tb_endereco_pessoa;
DROP TABLE IF EXISTS tb_contato_telefone;
DROP TABLE IF EXISTS tb_cadastro_pessoa;

SET FOREIGN_KEY_CHECKS = 1;

-- ================================================================
-- BASE COMPARTILHADA
-- Ordem: sem FK primeiro
-- ================================================================
-- ------------------------------------------------------------
-- Cadastro central de qualquer pessoa vinculada à faculdade
-- (aluno, professor, funcionário, responsável financeiro)
-- ------------------------------------------------------------

CREATE TABLE tb_cadastro_pessoa (
  pk_cpf            CHAR(11)      NOT NULL PRIMARY KEY,
  primeiro_nome     VARCHAR(100)  NOT NULL,
  sobrenome         VARCHAR(150)  NOT NULL,
  nome_social       VARCHAR(150),
  data_nascimento   DATE          NOT NULL,
  sexo              ENUM('masculino','feminino','nao_informado'),
  email_pessoal     VARCHAR(255)  NOT NULL UNIQUE,
  nacionalidade     VARCHAR(100)  DEFAULT 'Brasileira',
  naturalidade      VARCHAR(100),
  data_cadastro     DATETIME      NOT NULL,
  data_atualizacao  DATETIME
);

-- ------------------------------------------------------------
-- Telefones de qualquer pessoa
-- PK composta: uma pessoa não pode ter o mesmo número duas vezes
-- ------------------------------------------------------------

CREATE TABLE tb_contato_telefone (
  fk_cpf           CHAR(11)    NOT NULL,
  ddi              CHAR(3)     NOT NULL DEFAULT '055',
  ddd              CHAR(2)     NOT NULL,
  numero_telefone  VARCHAR(15) NOT NULL,
  tipo_contato     ENUM('celular','residencial','comercial','emergencia') NOT NULL,
  ativo            BOOLEAN     NOT NULL DEFAULT TRUE,
  PRIMARY KEY (fk_cpf, ddd, numero_telefone),
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);

-- ------------------------------------------------------------
-- Endereços de qualquer pessoa (pode ter mais de um)
-- Surrogate mantido: endereço não tem chave natural simples
-- ------------------------------------------------------------

CREATE TABLE tb_endereco_pessoa (
  pk_endereco    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf         CHAR(11)     NOT NULL,
  cep            VARCHAR(9)   NOT NULL,
  logradouro     VARCHAR(200) NOT NULL,
  numero_imovel  VARCHAR(15),
  complemento    VARCHAR(100),
  bairro         VARCHAR(100) NOT NULL,
  municipio      VARCHAR(100) NOT NULL,
  uf             CHAR(2)      NOT NULL,
  principal      BOOLEAN      NOT NULL DEFAULT FALSE,
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);
-- ================================================================
-- MÓDULO RH
-- ================================================================
-- ================================================================
-- Criado antes do Acadêmico porque tb_curso_graduacao
-- referencia tb_docente (coordenador do curso)
-- ================================================================
-- ------------------------------------------------------------
-- Cargos disponíveis na faculdade com faixa salarial
-- ------------------------------------------------------------

CREATE TABLE tb_cargo_funcional (
  pk_cargo           INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_cargo         VARCHAR(80)   NOT NULL UNIQUE,
  descricao_cargo    VARCHAR(255),
  nivel_hierarquico  INT,
  salario_piso       DECIMAL(10,2) NOT NULL,
  salario_teto       DECIMAL(10,2),
  situacao_cargo     ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  CHECK (salario_teto IS NULL OR salario_teto >= salario_piso)
);

-- ------------------------------------------------------------
-- Setores/departamentos da faculdade com hierarquia
-- Auto-referência: fk_setor_superior aponta para o setor pai
-- ------------------------------------------------------------

CREATE TABLE tb_setor_institucional (
  pk_setor          INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_setor        VARCHAR(100) NOT NULL UNIQUE,
  sigla_setor       CHAR(10),
  descricao         VARCHAR(255),
  fk_setor_superior INT,
  situacao_setor    ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  FOREIGN KEY (fk_setor_superior) REFERENCES tb_setor_institucional(pk_setor)
);

-- ------------------------------------------------------------
-- Qualquer pessoa que trabalha na faculdade
-- ------------------------------------------------------------

CREATE TABLE tb_colaborador (
  pk_rf                INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf               CHAR(11)     NOT NULL,
  fk_cargo             INT          NOT NULL,
  email_corporativo    VARCHAR(255) NOT NULL,
  situacao_colaborador ENUM('ativo','afastado','desligado','ferias') NOT NULL DEFAULT 'ativo',
  data_admissao        DATE         NOT NULL,
  data_desligamento    DATE,
  motivo_desligamento  VARCHAR(255),
  data_cadastro        DATETIME     NOT NULL,
  data_atualizacao     DATETIME,
  UNIQUE (fk_cpf),
  UNIQUE (email_corporativo),
  FOREIGN KEY (fk_cpf)    REFERENCES tb_cadastro_pessoa(pk_cpf),
  FOREIGN KEY (fk_cargo)  REFERENCES tb_cargo_funcional(pk_cargo)
);

-- ------------------------------------------------------------
-- Especialização de colaborador que é professor
-- Relação 1:1 com tb_colaborador (fk_rf é a própria PK)
-- ------------------------------------------------------------

CREATE TABLE tb_docente (
  fk_rf                 INT          NOT NULL PRIMARY KEY,
  titulacao             VARCHAR(80)  NOT NULL,
  registro_profissional VARCHAR(50),
  vinculo               ENUM('horista','tempo_parcial','tempo_integral','substituto') NOT NULL DEFAULT 'horista',
  area_formacao         VARCHAR(150) NOT NULL,
  lattes_url            VARCHAR(300),
  ativo                 BOOLEAN      NOT NULL DEFAULT TRUE,
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Registro de ponto diário
-- PK composta: um colaborador tem um registro por dia
-- ------------------------------------------------------------

CREATE TABLE tb_registro_ponto (
  fk_rf           INT            NOT NULL,
  data_trabalho   DATE           NOT NULL,
  entrada         TIME,
  saida           TIME,
  horas_extras    DECIMAL(5,2)   DEFAULT 0.00,
  minutos_atraso  INT            DEFAULT 0,
  observacao      VARCHAR(200),
  data_cadastro   DATETIME       NOT NULL,
  PRIMARY KEY (fk_rf, data_trabalho),
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Folha de pagamento mensal
-- PK composta: um colaborador tem uma folha por competência
-- Referenciada por tb_despesa_operacional (integração RH-Financeiro)
-- ------------------------------------------------------------

CREATE TABLE tb_folha_pagamento (
  fk_rf             INT           NOT NULL,
  competencia       DATE          NOT NULL,
  salario_bruto     DECIMAL(10,2) NOT NULL,
  total_descontos   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_beneficios  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  salario_liquido   DECIMAL(10,2) NOT NULL,
  situacao_pagamento ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro     DATETIME      NOT NULL,
  data_atualizacao  DATETIME,
  PRIMARY KEY (fk_rf, competencia),
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Alocação de colaboradores em setores (N:N com histórico)
-- PK composta: mesmo colaborador pode ser realocado no futuro
-- ------------------------------------------------------------

CREATE TABLE tb_alocacao_setor (
  fk_rf              INT     NOT NULL,
  fk_setor           INT     NOT NULL,
  data_inicio        DATE    NOT NULL,
  data_fim           DATE,
  alocacao_principal BOOLEAN NOT NULL DEFAULT TRUE,
  data_cadastro      DATETIME NOT NULL,
  PRIMARY KEY (fk_rf, fk_setor, data_inicio),
  FOREIGN KEY (fk_rf)    REFERENCES tb_colaborador(pk_rf),
  FOREIGN KEY (fk_setor) REFERENCES tb_setor_institucional(pk_setor)
);

-- ------------------------------------------------------------
-- Período de férias de colaboradores
-- Surrogate mantido: um colaborador pode tirar férias várias
-- vezes no mesmo ano (férias fracionadas)
-- ------------------------------------------------------------

CREATE TABLE tb_periodo_ferias (
  pk_ferias       INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_rf           INT     NOT NULL,
  ano_referencia  INT     NOT NULL,
  data_inicio     DATE    NOT NULL,
  data_fim        DATE    NOT NULL,
  aprovado        BOOLEAN NOT NULL DEFAULT FALSE,
  data_cadastro   DATETIME NOT NULL,
  FOREIGN KEY (fk_rf) REFERENCES tb_colaborador(pk_rf),
  CHECK (data_fim > data_inicio)
);

-- ================================================================
-- MÓDULO ACADÊMICO
-- ================================================================
-- ------------------------------------------------------------
-- Cursos de graduação oferecidos pela faculdade
-- Referencia tb_docente (coordenador) — por isso vem depois de RH
-- ------------------------------------------------------------

CREATE TABLE tb_curso_graduacao (
  pk_curso            INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_curso          VARCHAR(150) NOT NULL,
  codigo_mec          VARCHAR(20),
  area_conhecimento   VARCHAR(100) NOT NULL,
  grau_academico      VARCHAR(50)  NOT NULL,
  turno               ENUM('matutino','vespertino','noturno','ead') NOT NULL,
  duracao_semestres   INT          NOT NULL,
  carga_horaria_total INT          NOT NULL,
  coordenador_fk_rf   INT,
  situacao_curso      ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro       DATETIME     NOT NULL,
  data_atualizacao    DATETIME,
  UNIQUE (nome_curso),
  UNIQUE (codigo_mec),
  CHECK (duracao_semestres > 0),
  CHECK (carga_horaria_total > 0),
  FOREIGN KEY (coordenador_fk_rf) REFERENCES tb_docente(fk_rf)
);

-- ------------------------------------------------------------
-- Catálogo global de disciplinas (independe de curso ou semestre)
-- ------------------------------------------------------------

CREATE TABLE tb_disciplina_catalogo (
  pk_disciplina       INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  codigo_disciplina   VARCHAR(20)  NOT NULL UNIQUE,
  nome_disciplina     VARCHAR(150) NOT NULL,
  ementa              TEXT,
  carga_horaria_semanal INT        NOT NULL,
  carga_horaria_total INT          NOT NULL,
  num_creditos        INT          NOT NULL,
  situacao_disciplina ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro       DATETIME     NOT NULL,
  CHECK (carga_horaria_semanal > 0),
  CHECK (num_creditos > 0)
);

-- ------------------------------------------------------------
-- Grade curricular: quais disciplinas pertencem a qual curso
-- PK composta: uma disciplina aparece uma vez por curso
-- Resolve N:N entre cursos e disciplinas
-- ------------------------------------------------------------

CREATE TABLE tb_grade_curricular (
  fk_curso             INT     NOT NULL,
  fk_disciplina        INT     NOT NULL,
  semestre_recomendado INT     NOT NULL,
  obrigatoria          BOOLEAN NOT NULL DEFAULT TRUE,
  fk_pre_requisito     INT,
  PRIMARY KEY (fk_curso, fk_disciplina),
  FOREIGN KEY (fk_curso)         REFERENCES tb_curso_graduacao(pk_curso),
  FOREIGN KEY (fk_disciplina)    REFERENCES tb_disciplina_catalogo(pk_disciplina),
  FOREIGN KEY (fk_pre_requisito) REFERENCES tb_disciplina_catalogo(pk_disciplina),
  CHECK (semestre_recomendado > 0)
);

-- ------------------------------------------------------------
-- Períodos letivos (semestres)
-- PK composta: um semestre só existe uma vez por ano
-- ------------------------------------------------------------

CREATE TABLE tb_periodo_letivo (
  ano_letivo            INT     NOT NULL,
  semestre              INT     NOT NULL,
  data_inicio           DATE    NOT NULL,
  data_fim              DATE    NOT NULL,
  data_inicio_matricula DATE    NOT NULL,
  data_fim_matricula    DATE    NOT NULL,
  ativo                 BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (ano_letivo, semestre),
  CHECK (semestre IN (1, 2)),
  CHECK (data_fim > data_inicio),
  CHECK (data_fim_matricula >= data_inicio_matricula)
);

-- ------------------------------------------------------------
-- Estudantes da faculdade (dados acadêmicos)
-- Dados pessoais ficam em tb_cadastro_pessoa via fk_cpf
-- ------------------------------------------------------------

CREATE TABLE tb_estudante (
  pk_ra                   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_cpf                  CHAR(11)     NOT NULL,
  fk_curso                INT          NOT NULL,
  email_institucional     VARCHAR(255) NOT NULL,
  situacao                ENUM('matriculado','trancado','formado','evadido','jubilado','transferido') NOT NULL DEFAULT 'matriculado',
  semestre_atual          INT          NOT NULL DEFAULT 1,
  coeficiente_rendimento  DECIMAL(4,2),
  data_ingresso           DATE         NOT NULL,
  data_previsao_conclusao DATE,
  data_saida              DATE,
  motivo_saida            VARCHAR(255),
  flag_risco_evasao       BOOLEAN      NOT NULL DEFAULT FALSE,
  data_cadastro           DATETIME     NOT NULL,
  data_atualizacao        DATETIME,
  UNIQUE (fk_cpf),
  UNIQUE (email_institucional),
  CHECK (semestre_atual > 0),
  CHECK (coeficiente_rendimento IS NULL OR coeficiente_rendimento BETWEEN 0.00 AND 10.00),
  FOREIGN KEY (fk_cpf)   REFERENCES tb_cadastro_pessoa(pk_cpf),
  FOREIGN KEY (fk_curso) REFERENCES tb_curso_graduacao(pk_curso)
);

-- ------------------------------------------------------------
-- Histórico de mudanças de situação do estudante
-- Um aluno pode mudar de situação várias vezes
-- ------------------------------------------------------------

CREATE TABLE tb_historico_situacao_estudante (
  pk_historico      INT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra             INT      NOT NULL,
  situacao_anterior ENUM('matriculado','trancado','formado','evadido','jubilado','transferido'),
  situacao_nova     ENUM('matriculado','trancado','formado','evadido','jubilado','transferido') NOT NULL,
  data_alteracao    DATETIME NOT NULL,
  motivo            VARCHAR(255),
  fk_rf_responsavel INT,
  FOREIGN KEY (fk_ra)            REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_rf_responsavel) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Responsáveis financeiros dos estudantes
-- Relação 1:1 com tb_cadastro_pessoa via fk_cpf como PK
-- ------------------------------------------------------------

CREATE TABLE tb_responsavel_financeiro (
  fk_cpf               CHAR(11)      NOT NULL PRIMARY KEY,
  profissao            VARCHAR(100),
  renda_declarada      DECIMAL(10,2),
  situacao_responsavel ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  FOREIGN KEY (fk_cpf) REFERENCES tb_cadastro_pessoa(pk_cpf)
);

-- ------------------------------------------------------------
-- Vínculo entre estudante e responsável financeiro (N:N)
-- PK composta: um estudante não tem o mesmo responsável duas vezes
-- ------------------------------------------------------------

CREATE TABLE tb_estudante_responsavel (
  fk_ra                 INT     NOT NULL,
  fk_responsavel        CHAR(11) NOT NULL,
  grau_parentesco       VARCHAR(50),
  responsavel_principal BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (fk_ra, fk_responsavel),
  FOREIGN KEY (fk_ra)          REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_responsavel) REFERENCES tb_responsavel_financeiro(fk_cpf)
);

-- ------------------------------------------------------------
-- Oferta de disciplina: turma real em um semestre
-- (disciplina + período + professor + código de turma)
-- Referenciada por muitas tabelas filhas
-- ------------------------------------------------------------

CREATE TABLE tb_oferta_disciplina (
  pk_oferta        INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_disciplina    INT     NOT NULL,
  fk_ano_letivo    INT     NOT NULL,
  fk_semestre      INT     NOT NULL,
  fk_rf_docente    INT     NOT NULL,
  codigo_turma     VARCHAR(10) NOT NULL,
  sala             VARCHAR(20),
  capacidade_vagas INT     NOT NULL DEFAULT 40,
  vagas_ocupadas   INT     NOT NULL DEFAULT 0,
  turno            ENUM('matutino','vespertino','noturno','ead') NOT NULL,
  ativo            BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (fk_disciplina, fk_ano_letivo, fk_semestre, codigo_turma),
  CHECK (vagas_ocupadas <= capacidade_vagas),
  FOREIGN KEY (fk_disciplina) REFERENCES tb_disciplina_catalogo(pk_disciplina),
  FOREIGN KEY (fk_ano_letivo, fk_semestre) REFERENCES tb_periodo_letivo(ano_letivo, semestre),
  FOREIGN KEY (fk_rf_docente) REFERENCES tb_docente(fk_rf)
);

-- ------------------------------------------------------------
-- Matrícula do estudante em uma oferta de disciplina
-- PK composta: um aluno se matricula uma vez por oferta
-- ------------------------------------------------------------

CREATE TABLE tb_matricula_estudante (
  fk_ra                INT           NOT NULL,
  fk_oferta            INT           NOT NULL,
  data_matricula       DATE          NOT NULL,
  situacao_matricula   ENUM('cursando','aprovado','reprovado_nota','reprovado_falta','trancado','dispensado') NOT NULL DEFAULT 'cursando',
  nota_final           DECIMAL(5,2),
  total_faltas         INT           NOT NULL DEFAULT 0,
  percentual_frequencia DECIMAL(5,2),
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  PRIMARY KEY (fk_ra, fk_oferta),
  CHECK (nota_final IS NULL OR nota_final BETWEEN 0.00 AND 10.00),
  CHECK (percentual_frequencia IS NULL OR percentual_frequencia BETWEEN 0.00 AND 100.00),
  CHECK (total_faltas >= 0),
  FOREIGN KEY (fk_ra)    REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Avaliações planejadas por oferta (provas, trabalhos, etc.)
-- Referenciada por tb_nota_avaliacao
-- ------------------------------------------------------------

CREATE TABLE tb_avaliacao_programada (
  pk_avaliacao     INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_oferta        INT           NOT NULL,
  tipo_avaliacao   ENUM('prova','trabalho','seminario','projeto','atividade') NOT NULL,
  descricao        VARCHAR(150),
  data_aplicacao   DATE          NOT NULL,
  peso_percentual  DECIMAL(5,2)  NOT NULL,
  nota_maxima      DECIMAL(5,2)  NOT NULL DEFAULT 10.00,
  data_cadastro    DATETIME      NOT NULL,
  CHECK (peso_percentual > 0 AND peso_percentual <= 100),
  CHECK (nota_maxima > 0),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Nota de cada estudante em cada avaliação
-- PK composta: um aluno tem uma nota por avaliação
-- ------------------------------------------------------------

CREATE TABLE tb_nota_avaliacao (
  fk_ra               INT          NOT NULL,
  fk_avaliacao        INT          NOT NULL,
  nota_obtida         DECIMAL(5,2) NOT NULL,
  nota_substitutiva   DECIMAL(5,2),
  data_lancamento     DATETIME     NOT NULL,
  data_atualizacao    DATETIME,
  PRIMARY KEY (fk_ra, fk_avaliacao),
  CHECK (nota_obtida >= 0),
  CHECK (nota_substitutiva IS NULL OR nota_substitutiva >= 0),
  FOREIGN KEY (fk_ra)       REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_avaliacao) REFERENCES tb_avaliacao_programada(pk_avaliacao)
);

-- ------------------------------------------------------------
-- Registro de cada aula ministrada (diário de classe digital)
-- Referenciada por tb_frequencia_aula
-- ------------------------------------------------------------

CREATE TABLE tb_aula_registrada (
  pk_aula              INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_oferta            INT           NOT NULL,
  data_aula            DATE          NOT NULL,
  conteudo_ministrado  VARCHAR(300),
  carga_horaria        DECIMAL(4,2)  NOT NULL DEFAULT 1.50,
  data_cadastro        DATETIME      NOT NULL,
  CHECK (carga_horaria > 0),
  FOREIGN KEY (fk_oferta) REFERENCES tb_oferta_disciplina(pk_oferta)
);

-- ------------------------------------------------------------
-- Frequência: presença ou falta de cada aluno em cada aula
-- PK composta: um aluno tem um registro de presença por aula
-- ------------------------------------------------------------

CREATE TABLE tb_frequencia_aula (
  fk_ra                INT           NOT NULL,
  fk_aula              INT           NOT NULL,
  situacao_presenca    ENUM('presente','ausente','justificado') NOT NULL DEFAULT 'ausente',
  justificativa        VARCHAR(255),
  carga_horaria_falta  DECIMAL(4,2)  NOT NULL DEFAULT 0.00,
  data_registro        DATETIME      NOT NULL,
  PRIMARY KEY (fk_ra, fk_aula),
  CHECK (carga_horaria_falta >= 0),
  FOREIGN KEY (fk_ra)   REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_aula) REFERENCES tb_aula_registrada(pk_aula)
);

-- ------------------------------------------------------------
-- Ocorrências disciplinares dos estudantes
-- Um aluno pode ter várias ocorrências
-- ------------------------------------------------------------

CREATE TABLE tb_ocorrencia_disciplinar (
  pk_ocorrencia   INT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra           INT      NOT NULL,
  fk_oferta       INT,
  tipo_ocorrencia ENUM('advertencia','suspensao','elogio','registro_pedagogico') NOT NULL,
  descricao       VARCHAR(300) NOT NULL,
  data_ocorrencia DATETIME NOT NULL,
  resolvida       BOOLEAN  NOT NULL DEFAULT FALSE,
  data_resolucao  DATETIME,
  fk_rf_registrou INT,
  data_cadastro   DATETIME NOT NULL,
  FOREIGN KEY (fk_ra)          REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_oferta)      REFERENCES tb_oferta_disciplina(pk_oferta),
  FOREIGN KEY (fk_rf_registrou) REFERENCES tb_colaborador(pk_rf)
);

-- ================================================================
-- MÓDULO FINANCEIRO
-- ================================================================
-- ------------------------------------------------------------
-- Tabela de preços: valor da mensalidade por curso e semestre
-- PK composta: um curso tem um valor por semestre letivo
-- Integração Acadêmico-Financeiro
-- ------------------------------------------------------------

CREATE TABLE tb_tabela_mensalidade (
  fk_curso              INT           NOT NULL,
  fk_ano_letivo         INT           NOT NULL,
  fk_semestre           INT           NOT NULL,
  valor_integral        DECIMAL(10,2) NOT NULL,
  valor_com_desconto    DECIMAL(10,2),
  descricao_reajuste    VARCHAR(150),
  data_vigencia_inicio  DATE          NOT NULL,
  data_vigencia_fim     DATE,
  data_cadastro         DATETIME      NOT NULL,
  PRIMARY KEY (fk_curso, fk_ano_letivo, fk_semestre),
  CHECK (valor_integral > 0),
  CHECK (valor_com_desconto IS NULL OR valor_com_desconto <= valor_integral),
  FOREIGN KEY (fk_curso) REFERENCES tb_curso_graduacao(pk_curso),
  FOREIGN KEY (fk_ano_letivo, fk_semestre) REFERENCES tb_periodo_letivo(ano_letivo, semestre)
);

-- ------------------------------------------------------------
-- Bolsas e descontos concedidos a estudantes
-- Um aluno pode ter bolsas em períodos
-- diferentes (ex: bolsa renovada a cada semestre)
-- ------------------------------------------------------------

CREATE TABLE tb_bolsa_desconto (
  pk_bolsa              INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra                 INT           NOT NULL,
  tipo_bolsa            ENUM('prouni','institucional','convenio','desconto_funcionario','monitoria') NOT NULL,
  percentual_desconto   DECIMAL(5,2)  NOT NULL,
  fk_ano_letivo_inicio  INT           NOT NULL,
  fk_semestre_inicio    INT           NOT NULL,
  fk_ano_letivo_fim     INT,
  fk_semestre_fim       INT,
  justificativa         VARCHAR(255),
  aprovado_por_fk_rf    INT,
  ativo                 BOOLEAN       NOT NULL DEFAULT TRUE,
  data_cadastro         DATETIME      NOT NULL,
  data_atualizacao      DATETIME,
  CHECK (percentual_desconto > 0 AND percentual_desconto <= 100),
  FOREIGN KEY (fk_ra) REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_ano_letivo_inicio, fk_semestre_inicio)
    REFERENCES tb_periodo_letivo(ano_letivo, semestre),
  FOREIGN KEY (aprovado_por_fk_rf) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Contrato acadêmico-financeiro entre aluno e faculdade
-- Documento jurídico que ampara a cobrança das parcelas
-- Integração Acadêmico-Financeiro (fk_ra)
-- ------------------------------------------------------------

CREATE TABLE tb_contrato_academico (
  pk_contrato          INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_ra                INT           NOT NULL,
  fk_bolsa             INT,
  numero_contrato      VARCHAR(30)   NOT NULL UNIQUE,
  valor_contratado     DECIMAL(10,2) NOT NULL,
  data_assinatura      DATE          NOT NULL,
  data_vigencia_inicio DATE          NOT NULL,
  data_vigencia_fim    DATE,
  situacao_contrato    ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  CHECK (valor_contratado > 0),
  FOREIGN KEY (fk_ra)     REFERENCES tb_estudante(pk_ra),
  FOREIGN KEY (fk_bolsa)  REFERENCES tb_bolsa_desconto(pk_bolsa)
);

-- ------------------------------------------------------------
-- Parcelas mensais geradas por contrato
-- PK composta: um contrato tem um número de parcela único
-- (contrato 10, parcela 1 / contrato 10, parcela 2 ...)
-- ------------------------------------------------------------

CREATE TABLE tb_parcela_mensalidade (
  fk_contrato      INT           NOT NULL,
  numero_parcela   INT           NOT NULL,
  competencia_mes  INT           NOT NULL,
  competencia_ano  INT           NOT NULL,
  valor_nominal    DECIMAL(10,2) NOT NULL,
  valor_multa      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_juros      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_total      DECIMAL(10,2) NOT NULL,
  data_vencimento  DATE          NOT NULL,
  situacao_parcela ENUM('em_aberto','paga','vencida','renegociada','cancelada','isenta') NOT NULL DEFAULT 'em_aberto',
  data_pagamento   DATE,
  data_cadastro    DATETIME      NOT NULL,
  data_atualizacao DATETIME,
  PRIMARY KEY (fk_contrato, numero_parcela),
  CHECK (numero_parcela > 0),
  CHECK (competencia_mes BETWEEN 1 AND 12),
  CHECK (valor_nominal > 0),
  CHECK (valor_multa >= 0),
  CHECK (valor_juros >= 0),
  FOREIGN KEY (fk_contrato) REFERENCES tb_contrato_academico(pk_contrato)
);

-- ------------------------------------------------------------
-- Recebimento: registro concreto de um pagamento de parcela
-- Uma parcela pode ter múltiplos recebimentos
-- parciais em caso de renegociação
-- ------------------------------------------------------------

CREATE TABLE tb_recebimento (
  pk_recebimento      INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_contrato         INT           NOT NULL,
  fk_numero_parcela   INT           NOT NULL,
  valor_recebido      DECIMAL(10,2) NOT NULL,
  data_recebimento    DATETIME      NOT NULL,
  modalidade_pagamento ENUM('pix','boleto','cartao_debito','cartao_credito','transferencia','cheque') NOT NULL,
  numero_comprovante  VARCHAR(80),
  observacao          VARCHAR(255),
  fk_rf_operador      INT,
  data_cadastro       DATETIME      NOT NULL,
  CHECK (valor_recebido > 0),
  FOREIGN KEY (fk_contrato, fk_numero_parcela)
    REFERENCES tb_parcela_mensalidade(fk_contrato, numero_parcela),
  FOREIGN KEY (fk_rf_operador) REFERENCES tb_colaborador(pk_rf)
);

-- ------------------------------------------------------------
-- Controle de inadimplência por aluno
-- Chave natural: 1:1 com tb_estudante — fk_ra é a própria PK
-- Principal elo de integração Financeiro-Acadêmico
-- flag_bloqueio_academico bloqueia matrícula e histórico (RN-06)
-- ------------------------------------------------------------

CREATE TABLE tb_controle_inadimplencia (
  fk_ra                       INT           NOT NULL PRIMARY KEY,
  total_parcelas_vencidas     INT           NOT NULL DEFAULT 0,
  valor_total_em_aberto       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  data_primeira_inadimplencia DATE,
  flag_bloqueio_academico     BOOLEAN       NOT NULL DEFAULT FALSE,
  data_atualizacao            DATETIME      NOT NULL,
  CHECK (total_parcelas_vencidas >= 0),
  CHECK (valor_total_em_aberto >= 0),
  FOREIGN KEY (fk_ra) REFERENCES tb_estudante(pk_ra)
);

-- ------------------------------------------------------------
-- Fornecedores de serviços para a faculdade
-- Chave natural: CNPJ já é único no Brasil
-- ------------------------------------------------------------

CREATE TABLE tb_fornecedor_servico (
  pk_cnpj              VARCHAR(14)  NOT NULL PRIMARY KEY,
  razao_social         VARCHAR(200) NOT NULL,
  nome_fantasia        VARCHAR(150),
  tipo_fornecedor      ENUM('pessoa_fisica','pessoa_juridica') NOT NULL,
  email_comercial      VARCHAR(255),
  telefone_comercial   VARCHAR(20),
  cidade               VARCHAR(100),
  uf                   CHAR(2),
  situacao_fornecedor  ENUM('ativo','inativo') NOT NULL DEFAULT 'ativo',
  data_cadastro        DATETIME     NOT NULL
);

-- ------------------------------------------------------------
-- Despesas operacionais da faculdade
-- Integração RH-Financeiro via (fk_rf_folha, fk_competencia_folha)
-- Integração setorial via fk_setor
-- ------------------------------------------------------------

CREATE TABLE tb_despesa_operacional (
  pk_despesa           INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_setor             INT           NOT NULL,
  fk_cnpj              VARCHAR(14),
  fk_rf_folha          INT,
  fk_competencia_folha DATE,
  tipo_despesa         ENUM('manutencao','material','servico','tecnologia','infraestrutura','outros') NOT NULL,
  descricao            VARCHAR(255)  NOT NULL,
  valor_previsto       DECIMAL(12,2) NOT NULL,
  valor_realizado      DECIMAL(12,2),
  data_vencimento      DATE          NOT NULL,
  data_competencia     DATE          NOT NULL,
  numero_nota_fiscal   VARCHAR(50),
  paga                 BOOLEAN       NOT NULL DEFAULT FALSE,
  data_cadastro        DATETIME      NOT NULL,
  data_atualizacao     DATETIME,
  CHECK (valor_previsto > 0),
  FOREIGN KEY (fk_setor) REFERENCES tb_setor_institucional(pk_setor),
  FOREIGN KEY (fk_cnpj)  REFERENCES tb_fornecedor_servico(pk_cnpj),
  FOREIGN KEY (fk_rf_folha, fk_competencia_folha)
    REFERENCES tb_folha_pagamento(fk_rf, competencia)
);

-- ------------------------------------------------------------
-- Pagamento de despesas operacionais
-- Uma despesa pode ter múltiplos pagamentos
-- ------------------------------------------------------------

CREATE TABLE tb_pagamento_despesa (
  pk_pgto              INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
  fk_despesa           INT           NOT NULL,
  valor_pago           DECIMAL(12,2) NOT NULL,
  data_pagamento       DATE          NOT NULL,
  modalidade_pagamento ENUM('pix','boleto','cartao_debito','cartao_credito','transferencia','cheque') NOT NULL,
  numero_comprovante   VARCHAR(80),
  observacao           VARCHAR(255),
  data_cadastro        DATETIME      NOT NULL,
  CHECK (valor_pago > 0),
  FOREIGN KEY (fk_despesa) REFERENCES tb_despesa_operacional(pk_despesa)
);

-- ================================================================
-- FIM DO SCRIPT
-- ================================================================
