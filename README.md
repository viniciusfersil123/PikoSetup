# PikoSetup

Instalador inicial do ambiente de desenvolvimento **PikoPD para Ubuntu**. Ele parte de uma instalação Ubuntu sem as dependências do manual e prepara as ferramentas para compilar patches Pure Data (`.pd`) em firmware UF2 para Raspberry Pi Pico.

## Instalação

Na pasta deste repositório, abra o instalador gráfico:

```bash
./piko-setup
```

A janela tem um botão **Instalar** e mostra a saída do instalador enquanto ele trabalha. Depois de uma instalação bem-sucedida, o botão vira **Run / Flash**: ele compila `patches/heavy.pd` e grava o firmware no Pico. Antes de clicar, conecte a placa em modo BOOTSEL e confirme a gravação na janela. A autenticação administrativa é solicitada pelo diálogo do Ubuntu. Se Tkinter ainda não estiver instalado, o lançador solicita autorização para instalar `python3-tk` antes de abrir a janela.

Em aberturas futuras, se detectar que as dependências e o ambiente PikoPD continuam instalados, o programa abre direto com **Run / Flash**.

Também é possível executar diretamente no terminal:

```bash
./install-ubuntu.sh
```

O instalador solicitará autorização administrativa nas etapas que precisam dela, incluindo os pacotes do Ubuntu e a instalação do `picotool`. Execute como usuário normal, sem `sudo` no comando do instalador. É necessária conexão com a internet.

O `apt-get update` consulta também os repositórios de terceiros já configurados no Ubuntu. Se o único erro for a chave ausente deste repositório específico do VirtualBox (`NO_PUBKEY A2F683C52980AECF`), o instalador avisa e continua usando os índices oficiais do Ubuntu. Ele não instala nem altera o VirtualBox. Outros erros do APT interrompem a instalação.

Por padrão, os arquivos ficam em `~/piko-workspace`. Para escolher outra pasta:

```bash
PIKO_HOME="$HOME/Documentos/PikoPD" ./install-ubuntu.sh
```

## O que é instalado

- Pacotes Ubuntu para compilação, CMake, Ninja, Git, Python 3 e compilador ARM `arm-none-eabi`.
- Interface gráfica do instalador baseada em Python Tk.
- Repositório PikoPD e seus exemplos.
- Raspberry Pi Pico SDK e pico-extras, com submódulos Git inicializados.
- hvcc e Jinja2 dentro de um ambiente virtual Python isolado.
- picotool compilado e instalado no sistema.
- Variável `PICO_SDK_PATH` salva no arquivo de inicialização do shell detectado (Bash, Zsh ou Fish) e um lançador `pikopd` na pasta de instalação.

## Compilar um patch

O instalador mostra o comando `source` apropriado ao final. Execute-o no terminal atual ou abra um novo terminal para carregar `PICO_SDK_PATH`. Depois, compile um patch:

```bash
cd ~/piko-workspace/pikoPD
../pikopd patches/heavy.pd meu_projeto
```

O script do PikoPD gera o projeto e compila o firmware. O arquivo UF2 fica na pasta `project/build` dentro da pasta de projeto criada. Para gravar, conecte o Pico em modo BOOTSEL e acrescente `-f` ao comando, conforme as opções do manual:

```bash
../pikopd patches/heavy.pd meu_projeto -f
```

## Escopo desta versão

O instalador cobre o ambiente de compilação descrito no manual para Ubuntu. Ele não instala Pure Data nem PlugData, não configura hardware ou `board.json`, e não instala a ferramenta web de configuração. A opção de monitor serial `-s` do script upstream usa atualmente caminhos e integração de Terminal específicos do macOS; por isso, não é configurada como recurso Ubuntu por este instalador.

O instalador pode ser executado novamente para atualizar os repositórios e completar a instalação. Em checkouts com alterações locais, ele preserva os arquivos e não tenta atualizar aquele repositório. Se uma pasta de destino existir e não for um checkout Git, o script para sem apagá-la.
