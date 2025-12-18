3. MVP v1 do Gara

3.1. Objetivo do MVP
Entregar uma ferramenta que permita ao usuário:

• Registrar suas fontes de renda
• Registrar suas despesas fixas e uma estimativa das variáveis
• Registrar suas dívidas (em diferentes bancos/tipos)
• Ver em uma tela:
    · quanto entra por mês
    · quanto sai (fixas + dívidas + estimativa de variáveis)
    · se está sobrando ou faltando dinheiro
    · o valor total das dívidas
• Ter um primeiro “plano simples” mensal:
    · quanto deveria ir para dívidas
    · quanto fica livre (se sobrar)
Sem metas complexas, sem integrações, sem gráficos avançados no começo.

==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
3.2. Funcionalidades mínimas
checklist ☑☐:

• Conta de usuário ☐
    · Cadastro de usuário (email, senha, nome)
    · Login/logout
    · Edição simples do perfil (nome, renda inicial básica)
• Receitas ☐
    · Cadastro de fontes de renda (nome, valor, tipo: fixo/variável, frequência)
    · Cálculo automático de renda mensal total
• Despesas fixas e variáveis (estimadas) ☐
    · Cadastro de despesas fixas (nome, valor mensal, categoria)
    · Cadastro de estimativa de despesas variáveis (por categoria, ex.: “mercado R$600/mês”, “transporte R$200/mês”, “lazer R$150/mês”)
    · Cálculo do total de despesas mensais (fixas + variáveis estimadas)
• Dívidas ☐
    · Cadastro de dívidas:
        · Nome
        · Credor
        · Valor total
        · Valor da parcela mensal (se tiver)
        · Dia de vencimento
    • Cálculo:
        · Total de dívidas (soma geral)
        · Soma das parcelas mensais de todas as dívidas
• Resumo financeiro mensal ☐
    • Tela “Visão Geral” com:
        · Renda mensal total
        · Total despesas (fixas+variáveis estimadas)
        · Total mensal destinado a dívidas (parcelas)
        · Resultado:
            · Se sobra: quanto
            · Se falta: quanto
        · Total de dívidas
        Exemplo:
            · Renda: R$ 2.000
            · Despesas (não dívidas): R$ 1.200
            · Dívidas (parcelas): R$ 600
            · Resultado: Sobra R$200 (ou Falta R$ 200 ou Falta R$ X)
            · Total de dívidas: R$ 8.000
• Armazenar tudo por usuário ☐
    · Todos os dados vinculados ao usuario_id, para futuras múltiplas contas
 
==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==
3.3. O que NÃO entra no MVP (mas você quer ter no futuro)
Você pode colocar numa seção “Fora de escopo do MVP (mas planejado)”:

 Controle de gastos diário por transação (cada café/lanchinho, etc.)
 Sistema avançado de metas (por ano, por objetivo grande)
 Lembretes por WhatsApp/SMS
 Integração com bancos
 Integração com gov.br
 Vários perfis (várias famílias, multi-usuário em uma família, etc.)
 App mobile nativo
Isso te protege de se perder tentando fazer “tudo”.