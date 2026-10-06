import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension VoltarSeguro on BuildContext {
  /// `pop` que não deixa a tela preta.
  ///
  /// No navegador, quem recarrega a página (ou cola o link) em
  /// `/alunos/adicionar` chega com essa rota sozinha na pilha. Um `pop` ali
  /// remove a única página que existe e sobra o fundo preto. Quando não há
  /// para onde voltar, vai para [senaoPara], que é a tela-mãe da rota.
  void voltar({required String senaoPara}) {
    if (canPop()) {
      pop();
    } else {
      go(senaoPara);
    }
  }
}
