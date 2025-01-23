{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nixosTests,
}:
let
  pname = "open-webui";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "open-webui";
    repo = "open-webui";
    rev = "refs/tags/v${version}";
    hash = "sha256-9HRUFG8knKJx5Fr0uxLPMwhhbNnQ7CSywla8LGZu8l4=";
  };

  frontend = buildNpmPackage {
    inherit pname version src;

    npmDepsHash = "sha256-copQjrFgVJ6gZ8BwPiIsHEKSZDEiuVU3qygmPFv5Y1A=";

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
python3.pkgs.buildPythonApplication rec {
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

  dependencies = with python3.pkgs; [
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
    # gcp_storage_emulator
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

    (buildPythonPackage rec {
      pname = "gcp-storage-emulator";
      version = "2024.8.3";
      format = "setuptools";

      src = fetchPypi {
        inherit version;
        pname = "gcp_storage_emulator";
        hash = lib.fakeHash;
      };

      propagatedBuildInputs = [
        fs
        google-crc32c
      ];

      doCheck = false;
    })
  ];

  build-system = with python3.pkgs; [ hatchling ];

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
