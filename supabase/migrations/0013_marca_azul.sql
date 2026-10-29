-- ════════════════════════════════════════════════════════════
--  0013 — Cor padrão da marca: de volt para azul
--
--  A paleta do app passou a ser azul (marca) e vermelho (energia e
--  alerta). `marca_cor` é a faixa do cabeçalho e o fio de prumo do PDF
--  de avaliação; o padrão acompanha o app.
--
--  Só troca quem ainda está no padrão antigo: ninguém escolhe
--  '#D7FF3E' de propósito sem que o app ofereça essa escolha, então a
--  linha nesse valor é a que nunca foi personalizada.
-- ════════════════════════════════════════════════════════════

alter table public.profiles alter column marca_cor set default '#2F6BFF';

update public.profiles
   set marca_cor = '#2F6BFF'
 where upper(marca_cor) = '#D7FF3E';

notify pgrst, 'reload schema';

-- Conferência: não pode sobrar ninguém no volt, e o padrão tem de ser azul.
select (select count(*) from public.profiles
         where upper(marca_cor) = '#D7FF3E')          as ainda_no_volt,
       (select count(*) from public.profiles
         where upper(marca_cor) = '#2F6BFF')          as no_azul,
       (select column_default from information_schema.columns
         where table_schema = 'public' and table_name = 'profiles'
           and column_name = 'marca_cor')             as padrao_da_coluna;
