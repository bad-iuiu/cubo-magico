# Cubo Mágico (macOS)

App nativo (SwiftUI + SceneKit) que resolve cubos 2x2, 3x3, 4x4 e 5x5 a partir das cores informadas.

## Como compilar
```sh
./scripts/build_app.sh      # gera "build/Cubo Mágico.app"
open "build/Cubo Mágico.app"
```
Requer apenas as Command Line Tools do Xcode (Swift 5.9+), macOS 13+.

## Como funciona
- **2x2**: busca completa (tabela de 3,6 milhões de estados) → solução ótima (≤ 11 movimentos).
- **3x3**: algoritmo de duas fases de Kociemba (~20 movimentos).
- **4x4 / 5x5**: método de redução:
  1. centros (busca gulosa + comutadores que preservam centros),
  2. paridade das arestas corrigida com um giro de camada interna,
  3. cantos (solver de 2x2) ou cantos + arestas centrais (Kociemba, no 5x5),
  4. arestas com 3-ciclos puros (comutadores descobertos automaticamente).

## Testes
```sh
swift build -c release && .build/release/cubetest 2 3 4 5
```
Embaralha 20 cubos de cada tamanho, resolve e confere que ficaram resolvidos.
