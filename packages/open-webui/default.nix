{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nixosTests,
  rustPlatform,
  fetchurl,
}:
let
  python = python3.override {
    packageOverrides = self: super: {
      # gcp-storage-emulator = super.buildPythonPackage rec {
      #   pname = "gcp-storage-emulator";
      #   version = "2024.8.3";
      #   format = "setuptools";
      #
      #   src = super.fetchPypi {
      #     inherit version;
      #     pname = "gcp_storage_emulator";
      #     hash = "sha256-5dReXCOgNEwcTES4+MNvfol1yh/MUTTKtgi5bdzNkiU=";
      #   };
      #
      #   propagatedBuildInputs = [
      #     super.fs
      #     super.google-crc32c
      #   ];
      #
      #   doCheck = false;
      # };
      #
      # milvus-lite = super.buildPythonPackage {
      #   pname = "milvus-lite";
      #   version = "2.4.11";
      #   format = "wheel";
      #   platform = "manylinux2014_x86_64";
      #
      #   src = fetchurl {
      #     url = "https://files.pythonhosted.org/packages/8d/c2/b294a7699ef097d7b0ab89f95f34fb0710726f12d7da912734e18c2558eb/milvus_lite-2.4.11-py3-none-manylinux2014_x86_64.whl";
      #     hash = "sha256-VR9WtJ/PuzMLZYtKPFbtKbqbaS7CAe3R8tref145lX0=";
      #   };
      #   doCheck = false;
      # };
      #
      # pymilvus = super.pymilvus.overridePythonAttrs (old: {
      #   version = "2.5.4";
      #   doCheck = false;
      #   propagatedBuildInputs = old.propagatedBuildInputs ++ [
      #     self.milvus-lite
      #   ];
      # });
      #
      # primp = super.primp.overridePythonAttrs (old: rec {
      #   version = "0.12.0";
      #
      #   src = fetchFromGitHub {
      #     owner = "deedy5";
      #     repo = "primp";
      #     tag = "v${version}";
      #     hash = "sha256-yzcrUER+NiDfSjJ3my45IS+2GmeusvJgyX5nFSaqFUk=";
      #   };
      #
      #   cargoDeps = rustPlatform.fetchCargoVendor {
      #     inherit src;
      #     name = "${old.pname}-${version}";
      #     hash = "sha256-gCNnP0B0D6AJ1L/E6sQKASx8BbSJU5jTNia+tL2USvU=";
      #   };
      # });

      duckduckgo-search = super.duckduckgo-search.overridePythonAttrs (old: rec {
        version = "7.3.2";
        src = super.fetchPypi {
          inherit version;
          pname = "duckduckgo_search";
          hash = "sha256-v6/62NpHbe6vEOEBZpHqpyTevqgLYZjWPId/LyNvgBg=";
        };
        dependencies = [
          super.click
          super.lxml
          self.primp
        ];
      });
    };
  };

  pname = "open-webui";
  version = "0.5.10";

  src = fetchFromGitHub {
    owner = "open-webui";
    repo = "open-webui";
    rev = "refs/tags/v${version}";
    hash = "sha256-zwVrDdCMapuHKmtlEUnCwxXCBU93C5uT9eqDk5Of2BE=";
  };

  frontend = buildNpmPackage {
    inherit pname version src;

    npmDepsHash = "sha256-G08r+2eelxV3ottsNEZ6xysu13AbzPNTwkwZdY1qadg=";

    # Disabling `pyodide:fetch` as it downloads packages during `buildPhase`
    # Until this is solved, running python packages from the browser will not work.
    postPatch = ''
      substituteInPlace package.json \
        --replace-fail "npm run pyodide:fetch && vite build" "vite build"
    '';

    env.CYPRESS_INSTALL_BINARY = "0"; # disallow cypress from downloading binaries in sandbox
    env.ONNXRUNTIME_NODE_INSTALL_CUDA = "skip";
    env.NODE_OPTIONS = "--max-old-space-size=8192";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share
      cp -a build $out/share/open-webui

      runHook postInstall
    '';
  };
in
python.pkgs.buildPythonApplication rec {
  inherit pname version src;
  pyproject = true;

  # Not force-including the frontend build directory as frontend is managed by the `frontend` derivation above.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail ', build = "open_webui/frontend"' ""
  '';

  env.HATCH_BUILD_NO_HOOKS = true;

  pythonRelaxDeps = true;

  pythonRemoveDeps = [
    "docker"
    "pytest"
    "pytest-docker"
  ];

  dependencies = with python.pkgs; [
    aiocache
    aiofiles
    aiohttp
    alembic
    anthropic
    apscheduler
    argon2-cffi
    async-timeout
    authlib
    bcrypt
    beautifulsoup4
    black
    boto3
    chromadb
    colbert-ai
    docx2txt
    duckduckgo-search
    einops
    extract-msg
    fake-useragent
    fastapi
    faster-whisper
    flask
    flask-cors
    fpdf2
    ftfy
    gcp-storage-emulator
    google-cloud-storage
    google-generativeai
    googleapis-common-protos
    langchain
    langchain-chroma
    langchain-community
    langfuse
    ldap3
    markdown
    moto
    nltk
    openai
    opencv-python-headless
    openpyxl
    opensearch-py
    pandas
    passlib
    peewee
    peewee-migrate
    pgvector
    psutil
    psycopg2-binary
    pydub
    pyjwt
    pymdown-extensions
    pymilvus
    pymongo
    pymysql
    pypandoc
    pypdf
    python-dotenv
    python-jose
    python-multipart
    python-pptx
    python-socketio
    pytube
    pyxlsb
    qdrant-client
    rank-bm25
    rapidocr-onnxruntime
    redis
    requests
    sentence-transformers
    soundfile
    tiktoken
    unstructured
    uvicorn
    validators
    xlrd
    youtube-transcript-api
  ];

  build-system = with python.pkgs; [ hatchling ];

  pythonImportsCheck = [ "open_webui" ];

  makeWrapperArgs = [ "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui" ];

  passthru.tests = {
    inherit (nixosTests) open-webui;
  };

  meta = {
    changelog = "https://github.com/open-webui/open-webui/blob/${src.rev}/CHANGELOG.md";
    description = "Comprehensive suite for LLMs with a user-friendly WebUI";
    homepage = "https://github.com/open-webui/open-webui";
    license = lib.licenses.mit;
    mainProgram = "open-webui";
  };
}
