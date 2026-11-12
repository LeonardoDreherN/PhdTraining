import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/pagamento_conta.dart';
import '../../../core/services/pagamento_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/widgets/widgets.dart';

/// Cadastro do personal no gateway, para receber pelo app.
///
/// Quatro passos: dados, endereço, documentos e aprovação. Os dois
/// primeiros são formulário; o terceiro depende do gateway; o quarto é
/// análise deles e leva dias.
///
/// A tela mostra o progresso real em vez de prometer que é rápido. Dizer
/// "pronto!" e o personal descobrir três dias depois que não pode sacar é
/// pior do que avisar antes.
class AtivarRecebimentosScreen extends StatefulWidget {
  const AtivarRecebimentosScreen({super.key});

  @override
  State<AtivarRecebimentosScreen> createState() =>
      _AtivarRecebimentosScreenState();
}

class _AtivarRecebimentosScreenState extends State<AtivarRecebimentosScreen> {
  final _cpfCnpj = TextEditingController();
  final _nome = TextEditingController();
  final _renda = TextEditingController();
  final _email = TextEditingController();
  final _celular = TextEditingController();
  final _nascimento = TextEditingController();
  final _razaoSocial = TextEditingController();

  final _cep = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _complemento = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _uf = TextEditingController();

  String _tipoEmpresa = 'INDIVIDUAL';

  PagamentoConta? _conta;
  SituacaoGateway? _gw;
  bool _carregando = true;
  bool _salvando = false;
  bool _enviando = false;
  bool _consultando = false;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [
      _cpfCnpj, _nome, _renda, _email, _celular, _nascimento, _razaoSocial,
      _cep, _logradouro, _numero, _complemento, _bairro, _cidade, _uf,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final c = await PagamentoService.minhaConta();
      if (!mounted) return;
      setState(() {
        _conta = c;
        if (c != null) _preencher(c);
      });
      // Conta já no gateway e ainda não aprovada: consulta o que falta ao
      // abrir, para a tela não mostrar uma situação velha.
      if (c != null && c.temContaNoGateway && !c.aprovado && _gw == null) {
        unawaited(_atualizarSituacao());
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencher(PagamentoConta c) {
    _cpfCnpj.text = c.cpfCnpj ?? '';
    _nome.text = c.nomeResponsavel ?? '';
    _renda.text = c.rendaMensalCentavos == null
        ? ''
        : (c.rendaMensalCentavos! / 100).toStringAsFixed(2).replaceAll('.', ',');
    _email.text = c.emailCobranca ?? '';
    _celular.text = c.telefoneCelular ?? '';
    final n = c.dataNascimento;
    _nascimento.text = n == null
        ? ''
        : '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
    _razaoSocial.text = c.razaoSocial ?? '';
    _cep.text = c.cep ?? '';
    _logradouro.text = c.logradouro ?? '';
    _numero.text = c.numero ?? '';
    _complemento.text = c.complemento ?? '';
    _bairro.text = c.bairro ?? '';
    _cidade.text = c.cidade ?? '';
    _uf.text = c.uf ?? '';
    _tipoEmpresa = c.tipoEmpresa ?? 'INDIVIDUAL';
  }

  /// Conta viva: o que está na tela agora, não o que veio do banco. É ela
  /// que move a barra enquanto a pessoa digita.
  PagamentoConta get _atual => PagamentoConta(
        id: _conta?.id,
        cpfCnpj: _cpfCnpj.text,
        nomeResponsavel: _nome.text,
        tipoEmpresa: _tipoEmpresa,
        rendaMensalCentavos: _rendaCentavos,
        emailCobranca: _email.text,
        telefoneCelular: _celular.text,
        cep: _cep.text,
        logradouro: _logradouro.text,
        numero: _numero.text,
        complemento: _complemento.text,
        bairro: _bairro.text,
        cidade: _cidade.text,
        uf: _uf.text,
        kycStatus: _conta?.kycStatus ?? 'pendente',
        kycPendencias: _conta?.kycPendencias ?? const [],
        documentosEnviadosEm: _conta?.documentosEnviadosEm,
        aprovadoEm: _conta?.aprovadoEm,
        recusadoMotivo: _conta?.recusadoMotivo,
        podeReceber: _conta?.podeReceber ?? false,
        podeSacar: _conta?.podeSacar ?? false,
      );

  /// "10/05/1990" → data. `null` se vazio ou inválido.
  DateTime? get _dataNascimento {
    final p = _nascimento.text.trim().split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), a = int.tryParse(p[2]);
    if (d == null || m == null || a == null || a < 1900) return null;
    final data = DateTime(a, m, d);
    // DateTime aceita 31/02 e vira março: confere que não "andou".
    if (data.day != d || data.month != m) return null;
    return data;
  }

  int? get _rendaCentavos {
    final t = _renda.text.trim().replaceAll('.', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Ativar recebimentos', style: AppText.title(16)),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    final atual = _atual;
    final editavel = _conta?.editavel ?? true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
      ),
      children: [
        _barraDePassos(atual),
        const SizedBox(height: AppSpacing.xl),
        if (!editavel) ...[
          _avisoSituacao(_conta!),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (_conta?.recusado == true && _conta?.recusadoMotivo != null) ...[
          PhdAviso(
            texto: 'Recusado: ${_conta!.recusadoMotivo}',
            icone: Icons.error_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        const PhdSectionHeader(label: 'Seus dados'),
        const SizedBox(height: AppSpacing.md),
        _dados(editavel),

        const SizedBox(height: AppSpacing.xl),
        const PhdSectionHeader(label: 'Endereço'),
        const SizedBox(height: AppSpacing.md),
        _endereco(editavel),

        const SizedBox(height: AppSpacing.xl),
        const PhdSectionHeader(label: 'Documentos'),
        const SizedBox(height: AppSpacing.md),
        _documentos(),

        const SizedBox(height: AppSpacing.xl),
        if (editavel)
          PhdButton(
            label: 'Salvar cadastro',
            icon: Icons.check_rounded,
            loading: _salvando,
            onPressed: _salvar,
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Estes dados vão para o gateway de pagamento, que é quem verifica '
          'a identidade antes de liberar saque. Eles não aparecem para seus '
          'alunos.',
          style: AppText.caption(11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ── Progresso ───────────────────────────────────────────────

  Widget _barraDePassos(PagamentoConta c) {
    final feitos = c.passosFeitos;
    const passos = ['Dados', 'Endereço', 'Documentos', 'Aprovação'];

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.situacao, style: AppText.title(16)),
              ),
              Text('$feitos de ${PagamentoConta.totalPassos}',
                  style: AppText.number(13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdSegments(total: PagamentoConta.totalPassos, filled: feitos),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < passos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    i < feitos
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: i < feitos
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    passos[i],
                    style: AppText.caption(
                      12,
                      color: i < feitos
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _avisoSituacao(PagamentoConta c) {
    if (c.aprovado) {
      return PhdAviso(
        texto: c.podeSacar
            ? 'Cadastro aprovado. Você já pode receber e sacar pelo app.'
            : 'Cadastro aprovado. O saque libera em seguida.',
        icone: Icons.verified_rounded,
        cor: AppColors.success,
        corTexto: AppColors.successText,
      );
    }
    return PhdAviso(
      texto: 'Seu cadastro está em análise no gateway. Costuma levar de '
          'algumas horas a alguns dias, e não dá para acelerar. Enquanto '
          'isso você continua cobrando e dando baixa normalmente.',
      icone: Icons.hourglass_bottom_rounded,
      cor: AppColors.warning,
      corTexto: AppColors.warningText,
    );
  }

  // ── Formulários ─────────────────────────────────────────────

  Widget _dados(bool editavel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como você recebe', style: AppText.caption(12.5)),
        const SizedBox(height: 7),
        PhdFilterBar(
          children: [
            for (final t in tiposDeEmpresa)
              PhdFilterChip(
                label: t.rotulo,
                selected: _tipoEmpresa == t.valor,
                onTap: editavel
                    ? () => setState(() => _tipoEmpresa = t.valor)
                    : () {},
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tiposDeEmpresa.firstWhere((t) => t.valor == _tipoEmpresa).ajuda,
          style: AppText.caption(11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        PhdField(
          label: _tipoEmpresa == 'INDIVIDUAL' ? 'CPF' : 'CNPJ',
          controller: _cpfCnpj,
          enabled: editavel,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_tipoEmpresa == 'INDIVIDUAL')
          PhdField(
            label: 'Data de nascimento',
            controller: _nascimento,
            enabled: editavel,
            hint: 'dd/mm/aaaa',
            keyboardType: TextInputType.datetime,
            ajuda: _nascimento.text.trim().isNotEmpty && _dataNascimento == null
                ? 'Data inválida'
                : 'O gateway exige para pessoa física',
            onChanged: (_) => setState(() {}),
          )
        else
          PhdField(
            label: 'Razão social',
            controller: _razaoSocial,
            enabled: editavel,
            hint: 'Como está no CNPJ',
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: AppSpacing.lg),
        PhdField(
          label: _tipoEmpresa == 'INDIVIDUAL'
              ? 'Nome completo'
              : 'Nome do responsável',
          controller: _nome,
          enabled: editavel,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        PhdField(
          label: 'Faturamento por mês',
          controller: _renda,
          enabled: editavel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: '5.000,00',
          ajuda: _rendaCentavos == null
              ? 'O gateway exige este dado'
              : Moeda.formatar(_rendaCentavos!),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: PhdField(
                label: 'E-mail',
                controller: _email,
                enabled: editavel,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PhdField(
                label: 'Celular',
                controller: _celular,
                enabled: editavel,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _endereco(bool editavel) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: PhdField(
                label: 'CEP',
                controller: _cep,
                enabled: editavel,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 3,
              child: PhdField(
                label: 'Bairro',
                controller: _bairro,
                enabled: editavel,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PhdField(
          label: 'Rua',
          controller: _logradouro,
          enabled: editavel,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: PhdField(
                label: 'Número',
                controller: _numero,
                enabled: editavel,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: PhdField(
                label: 'Complemento',
                controller: _complemento,
                enabled: editavel,
                hint: 'opcional',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: PhdField(
                label: 'Cidade',
                controller: _cidade,
                enabled: editavel,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PhdField(
                label: 'UF',
                controller: _uf,
                enabled: editavel,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _enviarParaAnalise() async {
    setState(() => _enviando = true);
    try {
      final s = await PagamentoService.enviarParaAnalise();
      if (!mounted) return;
      setState(() => _gw = s);
      await _carregar();
      // O gateway leva uns segundos para listar os documentos da conta nova.
      Future.delayed(const Duration(seconds: 16), () {
        if (mounted) _atualizarSituacao();
      });
    } catch (e) {
      _avisar('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _atualizarSituacao() async {
    setState(() => _consultando = true);
    try {
      final s = await PagamentoService.situacao();
      final c = await PagamentoService.minhaConta();
      if (!mounted) return;
      setState(() {
        _gw = s;
        _conta = c;
      });
    } catch (e) {
      _avisar('Não consegui consultar o gateway: ${'$e'.replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceHigh,
      content: Text(texto, style: AppText.body(13.5)),
    ));
  }

  Widget _documentos() {
    final c = _conta;

    if (c?.temContaNoGateway == true) return _documentosDoGateway(c!);

    // O envio depende da conta já existir no gateway: é ele que diz quais
    // documentos faltam, e alguns têm de ir por um link próprio em vez da
    // API. Por isso este passo só abre depois dos dois primeiros.
    return PhdCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                // Não promete documento nenhum: quem decide a lista é o
                // gateway, conta a conta (no sandbox, pessoa física pediu só
                // a identificação).
                child: Text('Documentos que o gateway pedir',
                    style: AppText.bodyStrong(13)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            !(_atual.temDados && _atual.temEndereco)
                ? 'Preencha os dados e o endereço primeiro.'
                : !(c?.temDados == true && c?.temEndereco == true)
                    ? 'Salve o cadastro e depois envie para análise.'
                    : 'Envie para análise: o gateway cria sua conta e diz quais '
                        'documentos pede no seu caso. A lista muda conforme você '
                        'recebe como pessoa física, MEI ou empresa.',
            style: AppText.caption(12, color: AppColors.textMuted),
          ),
          if (c?.temDados == true && c?.temEndereco == true) ...[
            const SizedBox(height: AppSpacing.md),
            PhdButton(
              label: 'Enviar para análise',
              icon: Icons.send_rounded,
              size: PhdButtonSize.medium,
              loading: _enviando,
              onPressed: _enviando ? null : _enviarParaAnalise,
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentosDoGateway(PagamentoConta c) {
    final gw = _gw;
    final docs = gw?.documentos ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gw == null || gw.aguardando)
          PhdAviso(
            texto: 'Conta criada no gateway. Ele leva alguns segundos para '
                'dizer quais documentos pede.',
            icone: Icons.hourglass_bottom_rounded,
            cor: AppColors.warning,
            corTexto: AppColors.warningText,
          )
        else if (docs.isEmpty || docs.every((d) => d.status == 'APPROVED'))
          PhdAviso(
            texto: c.aprovado
                ? 'Documentos aprovados.'
                : 'Nenhum documento pendente. O gateway está analisando.',
            icone: Icons.task_alt_rounded,
            cor: AppColors.success,
            corTexto: AppColors.successText,
          )
        else
          for (final d in docs) ...[
            _linhaDocumento(d),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _consultando ? null : _atualizarSituacao,
            icon: _consultando
                ? SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                : Icon(Icons.refresh_rounded, size: 17, color: AppColors.accent),
            label: Text('Atualizar situação', style: AppText.bodyStrong(13, color: AppColors.accent)),
          ),
        ),
      ],
    );
  }

  Widget _linhaDocumento(({String titulo, String? descricao, String status, String? link}) d) {
    final (rotulo, tom) = switch (d.status) {
      'APPROVED' => ('Aprovado', PhdTone.success),
      'PENDING' => ('Em análise', PhdTone.warning),
      'REJECTED' => ('Recusado', PhdTone.danger),
      'IGNORED' => ('Dispensado', PhdTone.neutral),
      _ => ('Falta enviar', PhdTone.accent),
    };
    final enviar = d.link != null && (d.status == 'NOT_SENT' || d.status == 'REJECTED');
    return PhdCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.titulo, style: AppText.bodyStrong(13))),
              PhdStatusChip(label: rotulo, tone: tom),
            ],
          ),
          if (d.descricao != null && enviar) ...[
            const SizedBox(height: 4),
            Text(d.descricao!, style: AppText.caption(12, color: AppColors.textMuted)),
          ],
          if (enviar) ...[
            const SizedBox(height: AppSpacing.md),
            PhdButton(
              label: 'Enviar no site do gateway',
              icon: Icons.open_in_new_rounded,
              size: PhdButtonSize.small,
              expand: false,
              onPressed: () => launchUrl(Uri.parse(d.link!), mode: LaunchMode.externalApplication),
            ),
          ],
        ],
      ),
    );
  }

  // ── Gravação ────────────────────────────────────────────────

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final c = await PagamentoService.salvar({
        'cpf_cnpj': _cpfCnpj.text.trim(),
        'nome_responsavel': _nome.text.trim(),
        'tipo_empresa': _tipoEmpresa,
        'renda_mensal_centavos': _rendaCentavos,
        'email_cobranca': _email.text.trim(),
        'telefone_celular': _celular.text.trim(),
        'data_nascimento': _tipoEmpresa == 'INDIVIDUAL' && _dataNascimento != null
            ? _dataNascimento!.toIso8601String().substring(0, 10)
            : null,
        'razao_social': _tipoEmpresa == 'INDIVIDUAL' ? null : _razaoSocial.text.trim(),
        'cep': _cep.text.trim(),
        'logradouro': _logradouro.text.trim(),
        'numero': _numero.text.trim(),
        'complemento': _complemento.text.trim(),
        'bairro': _bairro.text.trim(),
        'cidade': _cidade.text.trim(),
        'uf': _uf.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      setState(() => _conta = c);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Cadastro salvo.', style: AppText.body(13.5)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}
