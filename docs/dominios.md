2. Domínios do sistema – Gara

2.1. Domínio: Usuário & Contexto Familiar
•Entidades principais:
    · Usuário
    · Família (pode ser só “contexto da casa” no começo)
    · Membro (filha, pais, namorada etc. – pode ficar para depois)
•O que esse domínio cuida:
    · Conta do usuário (login, dados pessoais básicos)
    · Situação familiar básica (quantas pessoas a renda precisa sustentar)
    · Eventualmente, vínculos de gastos/dívidas a pessoas específicas (futuro)


==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
2.2. Domínio: Receitas (Dinheiro que entra)
• Entidades:
    · FonteDeRenda (salário, bicos, pensão, ajuda dos pais, etc.)
    · Receita (registro de entrada de dinheiro: salário do mês, extra, etc.)
• Objetivo:
    · Permitir saber quanto entra de dinheiro:
        · por mês
        · por semana
        · por ano (calculado)
• Exemplos práticos:
    · Salário CLT fixo
    · Bico de fim de semana
    · Dinheiro que entra às vezes (tipo venda de algo)

==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
2.3. Domínio: Despesas Fixas & Variáveis
• Entidades:
    · CategoriaDeDespesa (moradia, alimentação, transporte, lazer, filha, etc.)
    · DespesaFixa (internet, aluguel, prestações, escola da filha…)
    · DespesaVariavelAproximada (mercado, transporte, lanches, etc., com valor “médio estimado”)
    · Futuro: DespesaReal (registro dia a dia, se você quiser isso depois)
• Objetivo:
    · Mesmo sem anotar cada café, ter uma estimativa sólida de quanto se gasta:
        · com coisas fixas (contas/prestações)
        · com coisas variáveis (mercado, transporte, lanches…)
• Visão do sistema:
    · Cria uma “foto” de quanto você precisa pra viver por mês:
        · Total fixo + total variável médio = estimativa mensal


==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
2.4. Domínio: Dívidas & Compromissos Financeiros
Esse é o coração do seu problema.
• Entidades:
    · Divida (cada contrato/carnê/cartão)
    · Parcela (se a dívida é parcelada)
    · Credor (banco X, loja Y, pessoa Z)
    · StatusDaDivida (em dia, atrasada, negociada, quitada)
• Campos importantes em Divida:
    · Nome (Ex.: “Cartão Banco X”, “Empréstimo Banco Y”)
    · Tipo (cartão, empréstimo, carnê, cheque especial, etc.)
    · Valor total da dívida
    · Valor da parcela mensal (se tiver)
    · Data de vencimento (dia do mês)
    · Taxa de juros (se souber, futuro)
    · Prioridade (alta, média, baixa)
• Objetivo:
    · Ter em um só lugar o total que você deve e:
        · quanto vai de grana por mês para pagar tudo
        · o que está atrasado
        · o que é mais urgente atacar


==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
2.5. Domínio: Planejamento & Metas
• Entidades:
    · MetaFinanceira (ex.: “quitar todas as dívidas em 2 anos”, “juntar R$ 1.000 para emergência”, “mudar de casa”)
    · PlanoMensal (resultado de um cálculo: quanto precisa guardar/pagar por mês)
    · Futuro: PlanoSemanal
• Objetivo:
    · Traduzir objetivos vagos em números concretos:
        · quanto por mês para:
            · pagar dívidas
            · sobreviver
            · aproximar-se dos objetivos
• Exemplo:
    · Meta: “quitar todas as dívidas em 24 meses”
    · Sistema calcula:
        · total de dívidas
        · quanto precisaria pagar por mês
        · quanto isso representa (%) da sua renda


==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
2.6. Domínio: Tarefas & Lembretes (Financeiros e Burocráticos)
• Entidades:
    · Tarefa
    · TipoDeTarefa (pagar conta X, renegociar dívida Y, atualizar dados, etc.)
    · Vinculo (ligação da tarefa com Divida, DespesaFixa, Meta)
• Objetivo:
    · Ajudar você a não esquecer o que precisa ser feito, sem depender só da cabeça.