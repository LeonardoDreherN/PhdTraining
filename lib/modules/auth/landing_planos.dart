part of 'landing_screen.dart';

// ── Planos ────────────────────────────────────────────────────

/// Preço.
///
/// O degrau sobe por número de alunos, e a nutrição entra no terceiro —
/// que é onde ela começa a se pagar: quem prescreve dieta cobra mais por
/// aluno, então a ferramenta custar mais ali acompanha o que ele fatura.
///
/// O comparativo com "dois aplicativos" fica à vista de propósito. O
/// personal que já paga um app de treino e um de nutrição é quem decide
/// mais rápido, e quem faz a conta é ele — a página só mostra.
///
/// Arquivo separado por `part` para não engordar a landing, mas dentro da
/// mesma biblioteca: a seção usa as cores e os botões de lá, e duplicar
/// aquilo seria garantir que um dia divergem.
class _Planos extends StatefulWidget {
  const _Planos({required this.desktop});
  final bool desktop;

  @override
  State<_Planos> createState() => _PlanosState();
}

class _PlanosState extends State<_Planos> {
  bool _anual = true;

  static const _planos = <_Plano>[
    _Plano(
      nome: 'Início',
      mensal: 0,
      alunos: '3 alunos',
      resumo: 'Para testar com os primeiros.',
      itens: ['Treino e ficha', 'Avaliação física', 'Chat com o aluno'],
    ),
    _Plano(
      nome: 'Essencial',
      mensal: 59,
      alunos: '25 alunos',
      resumo: 'Para quem vive de treino.',
      itens: [
        'Tudo do Início',
        'Recebimento pelo app',
        'Agenda e periodização',
        'Relatórios de evolução',
      ],
    ),
    _Plano(
      nome: 'Completo',
      mensal: 99,
      alunos: '60 alunos',
      resumo: 'Treino e nutrição no mesmo lugar.',
      destaque: true,
      itens: [
        'Tudo do Essencial',
        'Plano alimentar com tabela TACO',
        'Diário, água, peso e adesão',
        'Convide 1 nutricionista',
      ],
    ),
    _Plano(
      nome: 'Studio',
      mensal: 179,
      alunos: 'Alunos ilimitados',
      resumo: 'Para quem tem equipe.',
      itens: [
        'Tudo do Completo',
        'Equipe ilimitada',
        'Vários profissionais, mesma carteira',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Etiqueta('Planos'),
        const SizedBox(height: 18),
        const _Titulo('Um app no lugar de dois.'),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Quem dá treino e dieta hoje paga dois aplicativos que não '
            'conversam entre si. Aqui é um só — e o dinheiro dos seus alunos '
            'cai na sua conta por ele.',
            style:
                AppText.body(estreito ? 15 : 17, color: _cinza).copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        _seletorCiclo(),
        const SizedBox(height: 28),
        if (widget.desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _planos.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: _CartaoPlano(plano: _planos[i], anual: _anual)),
              ],
            ],
          )
        else
          Column(
            children: [
              for (final p in _planos) ...[
                _CartaoPlano(plano: p, anual: _anual),
                const SizedBox(height: 14),
              ],
            ],
          ),
        const SizedBox(height: 28),
        const _Comparativo(),
      ],
    );
  }

  Widget _seletorCiclo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _linha),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opcaoCiclo('Mensal', !_anual, () => setState(() => _anual = false)),
          _opcaoCiclo(
              'Anual · 2 meses grátis', _anual, () => setState(() => _anual = true)),
        ],
      ),
    );
  }

  Widget _opcaoCiclo(String rotulo, bool ativo, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ativo ? _vermelho : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            rotulo,
            style: AppText.bodyStrong(13.5, color: ativo ? _branco : _cinza),
          ),
        ),
      ),
    );
  }
}

class _Plano {
  const _Plano({
    required this.nome,
    required this.mensal,
    required this.alunos,
    required this.resumo,
    required this.itens,
    this.destaque = false,
  });

  final String nome;
  final int mensal;
  final String alunos;
  final String resumo;
  final List<String> itens;
  final bool destaque;

  /// Anual com dois meses grátis: paga 10, usa 12.
  int get anualTotal => mensal * 10;
  int get anualPorMes => mensal == 0 ? 0 : (anualTotal / 12).round();
}

class _CartaoPlano extends StatefulWidget {
  const _CartaoPlano({required this.plano, required this.anual});
  final _Plano plano;
  final bool anual;

  @override
  State<_CartaoPlano> createState() => _CartaoPlanoState();
}

class _CartaoPlanoState extends State<_CartaoPlano> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plano;
    final gratis = p.mensal == 0;
    final valor = gratis ? 0 : (widget.anual ? p.anualPorMes : p.mensal);

    return MouseRegion(
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _sobre ? -4 : 0, 0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: p.destaque ? _cartao2 : _cartao,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: p.destaque ? _vermelho : (_sobre ? _cinza2 : _linha),
            width: p.destaque ? 1.4 : 1,
          ),
          boxShadow: p.destaque
              ? [
                  BoxShadow(
                    color: _vermelho.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(p.nome, style: AppText.title(18, color: _branco)),
                const Spacer(),
                if (p.destaque)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _vermelho,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('MAIS ESCOLHIDO',
                        style: AppText.label(color: _branco)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.resumo, style: AppText.caption(13, color: _cinza2)),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (gratis)
                  Text('Grátis', style: AppText.display(30, color: _branco))
                else ...[
                  Text(r'R$', style: AppText.body(15, color: _cinza)),
                  const SizedBox(width: 4),
                  Text('$valor', style: AppText.display(38, color: _branco)),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('/mês', style: AppText.caption(13, color: _cinza2)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // O total do ano fica à vista: deixar só o "/mês" sugeriria que
            // o anual é mensalidade sem compromisso, e a cobrança vem de uma
            // vez. Descobrir isso no cartão é o jeito de perder a confiança
            // no primeiro dia.
            Text(
              gratis
                  ? 'Para sempre'
                  : widget.anual
                      ? 'R\$ ${p.anualTotal} cobrados uma vez por ano'
                      : 'Cancele quando quiser',
              style: AppText.caption(12, color: _cinza2),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: _linha),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.people_outline_rounded, size: 16, color: _cinza),
                const SizedBox(width: 7),
                Text(p.alunos, style: AppText.bodyStrong(13.5, color: _branco)),
              ],
            ),
            const SizedBox(height: 14),
            for (final item in p.itens)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded, size: 15, color: _verde),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: AppText.caption(13, color: _cinza)
                            .copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _Botao(
              gratis ? 'Começar grátis' : 'Assinar',
              primario: p.destaque,
              onTap: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A conta que o personal já faz hoje, na frente dele.
///
/// É o argumento mais forte da página, e não é adjetivo: são os preços de
/// tabela de quem ele provavelmente já assina.
class _Comparativo extends StatelessWidget {
  const _Comparativo();

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;

    return Container(
      padding: EdgeInsets.all(estreito ? 20 : 26),
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _linha),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Se você dá treino e dieta',
              style: AppText.title(17, color: _branco)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _coluna('Hoje', 'dois aplicativos', r'R$ 130', riscado: true),
              const Icon(Icons.arrow_forward_rounded, size: 20, color: _cinza2),
              _coluna('Aqui', 'um só, integrado', r'R$ 99'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'E nenhum app de nutrição do mercado recebe o pagamento do seu '
            'aluno por você.',
            style: AppText.caption(13, color: _cinza2).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _coluna(String etiqueta, String apoio, String valor,
      {bool riscado = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta.toUpperCase(), style: AppText.label(color: _cinza2)),
        const SizedBox(height: 6),
        Text(
          valor,
          style: AppText.display(riscado ? 26 : 32,
                  color: riscado ? _cinza2 : _branco)
              .copyWith(
            decoration: riscado ? TextDecoration.lineThrough : null,
            decorationColor: _vermelhoClaro,
          ),
        ),
        const SizedBox(height: 3),
        Text(apoio, style: AppText.caption(12.5, color: _cinza2)),
      ],
    );
  }
}
