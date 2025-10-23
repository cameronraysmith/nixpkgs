#!/usr/bin/env bash
# Run nixpkgs-review for aarch64-darwin excluding sbcl-dependent packages
set -euo pipefail

BRANCH="${1:-update-duckdb-1.4-review}"
BASE_BRANCH="${2:-master}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "nixpkgs-review for aarch64-darwin (excluding sbcl dependencies)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH"
echo "Base: $BASE_BRANCH"
echo ""

# Get cachix cache name from nix-config
# shellcheck disable=SC2016
CACHE_NAME=$(cd ~/projects/nix-workspace/nix-config && \
    sops exec-env secrets/shared.yaml 'echo $CACHIX_CACHE_NAME')
echo "Cache: https://app.cachix.org/cache/$CACHE_NAME"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Starting nixpkgs-review with cachix watch-exec"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Excluding 193 packages (sbcl dependencies + manual exclusions)"
echo ""

cd ~/projects/nix-workspace/nix-config && \
sops exec-env secrets/shared.yaml "
    cd ~/projects/nixpkgs && \
    cachix watch-exec \$CACHIX_CACHE_NAME --jobs 12 -- \
        nixpkgs-review rev $BRANCH \
            --branch $BASE_BRANCH \
            --systems aarch64-darwin \
            --num-parallel-evals 12 \
            --build-args '--max-jobs 12 --cores 12 --keep-going' \
            -P calibre \
            -P unbook \
            -P python3Packages.wacz \
            -P py-wacz \
            -P python3Packages.svgdigitizer \
            -P skytemple \
            -P flattenReferencesGraph \
            -P deeptools \
            -P cve-bin-tool \
            -P das \
            -P apkleaks \
            -P checkov \
            -P beets \
            -P jadx \
            -P multiqc \
            -P aider-chat-with-browser \
            -P aider-chat-with-help \
            -P pianotrans \
            -P aider-chat-full \
            -P piper-tts \
            -P prowler \
            -P coqui-tts \
            -P python312Packages.scikit-tda \
            -P python312Packages.k-diffusion \
            -P python313Packages.scikit-tda \
            -P python313Packages.k-diffusion \
            -P python312Packages.ax-platform \
            -P python312Packages.beets \
            -P python312Packages.beetcamp \
            -P python312Packages.bumps \
            -P python312Packages.chart-studio \
            -P python312Packages.compressai \
            -P python312Packages.dash \
            -P python312Packages.dash-bootstrap-templates \
            -P python312Packages.dash-bootstrap-components \
            -P python312Packages.energyflow \
            -P python312Packages.explorerscript \
            -P python312Packages.experiment-utilities \
            -P python312Packages.fastai \
            -P python312Packages.holistic-trace-analysis \
            -P python312Packages.igraph \
            -P python312Packages.hvplot \
            -P python312Packages.intake \
            -P python312Packages.iplotx \
            -P python312Packages.itables \
            -P python312Packages.kmapper \
            -P python312Packages.leidenalg \
            -P python312Packages.librosa \
            -P python312Packages.llama-cloud-services \
            -P python312Packages.llama-index-cli \
            -P python312Packages.llama-index-core \
            -P python312Packages.llama-index-embeddings-gemini \
            -P python312Packages.llama-index \
            -P python312Packages.llama-index-embeddings-google \
            -P python312Packages.llama-index-embeddings-ollama \
            -P python312Packages.llama-index-embeddings-openai \
            -P python312Packages.llama-index-embeddings-huggingface \
            -P python312Packages.llama-index-graph-stores-neo4j \
            -P python312Packages.llama-index-graph-stores-nebula \
            -P python312Packages.llama-index-graph-stores-neptune \
            -P python312Packages.llama-index-indices-managed-llama-cloud \
            -P python312Packages.llama-index-legacy \
            -P python312Packages.llama-index-llms-ollama \
            -P python312Packages.llama-index-llms-openai \
            -P python312Packages.llama-index-llms-openai-like \
            -P python312Packages.llama-index-multi-modal-llms-openai \
            -P python312Packages.llama-index-readers-database \
            -P python312Packages.llama-index-node-parser-docling \
            -P python312Packages.llama-index-readers-file \
            -P python312Packages.llama-index-readers-json \
            -P python312Packages.llama-index-readers-txtai \
            -P python312Packages.llama-index-readers-twitter \
            -P python312Packages.llama-index-readers-s3 \
            -P python312Packages.llama-index-readers-llama-parse \
            -P python312Packages.llama-index-vector-stores-chroma \
            -P python312Packages.llama-index-readers-weather \
            -P python312Packages.llama-index-vector-stores-google \
            -P python312Packages.llama-index-vector-stores-milvus \
            -P python312Packages.mlcroissant \
            -P python312Packages.neurokit2 \
            -P python312Packages.niaarm \
            -P python312Packages.llama-index-vector-stores-qdrant \
            -P python312Packages.llama-parse \
            -P python312Packages.optuna \
            -P python312Packages.optuna-dashboard \
            -P python312Packages.piano-transcription-inference \
            -P python312Packages.plotly \
            -P python312Packages.pyannote-pipeline \
            -P python312Packages.pyannote-audio \
            -P python312Packages.pymatgen \
            -P python312Packages.reflex-chakra \
            -P python312Packages.reflex \
            -P python312Packages.resampy \
            -P python312Packages.sasmodels \
            -P python312Packages.skrl \
            -P python312Packages.spacy \
            -P python312Packages.sumo \
            -P python312Packages.synergy \
            -P python312Packages.spacy-curated-transformers \
            -P python312Packages.spacy-loggers \
            -P python312Packages.spacy-lookups-data \
            -P python312Packages.spacy-transformers \
            -P python312Packages.torch-audiomentations \
            -P python312Packages.torchcrepe \
            -P python312Packages.torchlibrosa \
            -P python312Packages.whisperx \
            -P python312Packages.textnets \
            -P python312Packages.textacy \
            -P python312Packages.wandb \
            -P python313Packages.ax-platform \
            -P python313Packages.beetcamp \
            -P python313Packages.bumps \
            -P python313Packages.chart-studio \
            -P python313Packages.compressai \
            -P python313Packages.dash-bootstrap-templates \
            -P python313Packages.dash \
            -P python313Packages.dash-bootstrap-components \
            -P python313Packages.energyflow \
            -P python313Packages.experiment-utilities \
            -P python313Packages.explorerscript \
            -P python313Packages.fastai \
            -P python313Packages.hvplot \
            -P python313Packages.igraph \
            -P python313Packages.holistic-trace-analysis \
            -P python313Packages.intake \
            -P python313Packages.iplotx \
            -P python313Packages.itables \
            -P python313Packages.kmapper \
            -P python313Packages.leidenalg \
            -P python313Packages.librosa \
            -P python313Packages.llama-cloud-services \
            -P python313Packages.llama-index-cli \
            -P python313Packages.llama-index \
            -P python313Packages.llama-index-core \
            -P python313Packages.llama-index-embeddings-gemini \
            -P python313Packages.llama-index-embeddings-google \
            -P python313Packages.llama-index-graph-stores-neo4j \
            -P python313Packages.llama-index-embeddings-ollama \
            -P python313Packages.llama-index-embeddings-huggingface \
            -P python313Packages.llama-index-graph-stores-neptune \
            -P python313Packages.llama-index-embeddings-openai \
            -P python313Packages.llama-index-indices-managed-llama-cloud \
            -P python313Packages.llama-index-legacy \
            -P python313Packages.llama-index-llms-ollama \
            -P python313Packages.llama-index-llms-openai \
            -P python313Packages.llama-index-llms-openai-like \
            -P python313Packages.llama-index-multi-modal-llms-openai \
            -P python313Packages.llama-index-node-parser-docling \
            -P python313Packages.llama-index-readers-file \
            -P python313Packages.llama-index-readers-database \
            -P python313Packages.llama-index-readers-json \
            -P python313Packages.llama-index-readers-weather \
            -P python313Packages.llama-index-readers-s3 \
            -P python313Packages.llama-index-readers-llama-parse \
            -P python313Packages.llama-index-readers-twitter \
            -P python313Packages.llama-index-readers-txtai \
            -P python313Packages.llama-index-vector-stores-chroma \
            -P python313Packages.llama-index-vector-stores-google \
            -P python313Packages.llama-index-vector-stores-milvus \
            -P python313Packages.mlcroissant \
            -P python313Packages.neurokit2 \
            -P python313Packages.niaarm \
            -P python313Packages.optuna \
            -P python313Packages.optuna-dashboard \
            -P python313Packages.llama-index-vector-stores-qdrant \
            -P python313Packages.llama-parse \
            -P python313Packages.plotly \
            -P python313Packages.piano-transcription-inference \
            -P python313Packages.pyannote-pipeline \
            -P python313Packages.pyannote-audio \
            -P python313Packages.sasmodels \
            -P python313Packages.reflex \
            -P python313Packages.resampy \
            -P python313Packages.reflex-chakra \
            -P python313Packages.skrl \
            -P python313Packages.spacy-curated-transformers \
            -P python313Packages.synergy \
            -P python313Packages.spacy \
            -P python313Packages.spacy-loggers \
            -P python313Packages.spacy-lookups-data \
            -P python313Packages.spacy-transformers \
            -P python313Packages.torchlibrosa \
            -P python313Packages.torch-audiomentations \
            -P python313Packages.torchcrepe \
            -P python313Packages.textacy \
            -P python313Packages.wandb \
            -P python313Packages.whisperx \
            -P sbclPackages.duckdb \
            -P theharvester \
            -P quark-engine \
            -P whisperx \
            -P wyoming-piper \
            -P whisper-ctranslate2 \
            --no-shell
"

EXIT_CODE=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Review complete! All packages built successfully"
else
    echo "⚠️  Review completed with some failures (exit code: $EXIT_CODE)"
    echo "    Check ~/.cache/nixpkgs-review/ for logs"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Build artifacts pushed to: https://app.cachix.org/cache/$CACHE_NAME"
echo "Review results: ~/.cache/nixpkgs-review/rev-$BRANCH/"
echo ""
