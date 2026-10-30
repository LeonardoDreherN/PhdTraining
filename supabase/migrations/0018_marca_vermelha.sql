-- ════════════════════════════════════════════════════════════
--  0018 — Cor padrão da marca: vermelho
--
--  A marca do PHD é vermelha; o app passou a usar #DC2626 como cor
--  principal (o azul do 0013 era provisório). `marca_cor` é a faixa do
--  cabeçalho e o fio de prumo dos PDFs de avaliação e de plano.
--
--  Só troca quem está num padrão antigo (volt do 0001 ou azul do 0013):
--  ninguém escolhe esses valores de propósito, porque o app não oferece
--  essa escolha — a linha neles é a que nunca foi personalizada.
--
--  Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.profiles alter column marca_cor set default '#DC2626';

update public.profiles
   set marca_cor = '#DC2626'
 where upper(marca_cor) in ('#2F6BFF', '#D7FF3E');

notify pgrst, 'reload schema';

-- Conferência: ninguém pode sobrar num padrão antigo, e o padrão da
-- coluna tem de ser o vermelho.
select (select count(*) from public.profiles
         where upper(marca_cor) in ('#2F6BFF', '#D7FF3E'))  as em_padrao_antigo,
       (select count(*) from public.profiles
         where upper(marca_cor) = '#DC2626')                as no_vermelho,
       (select column_default from information_schema.columns
         where table_schema = 'public' and table_name = 'profiles'
           and column_name = 'marca_cor')                   as padrao_da_coluna;
