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
echo "Excluding 187 packages (sbcl dependencies + manual exclusions)"
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
            -P python3Packages.ax-platform \
            -P python3Packages.beets \
            -P python3Packages.beetcamp \
            -P python3Packages.bumps \
            -P python3Packages.chart-studio \
            -P python3Packages.compressai \
            -P python3Packages.dash \
            -P python3Packages.dash-bootstrap-templates \
            -P python3Packages.dash-bootstrap-components \
            -P python3Packages.energyflow \
            -P python3Packages.explorerscript \
            -P python3Packages.experiment-utilities \
            -P python3Packages.fastai \
            -P python3Packages.holistic-trace-analysis \
            -P python3Packages.igraph \
            -P python3Packages.hvplot \
            -P python3Packages.intake \
            -P python3Packages.iplotx \
            -P python3Packages.itables \
            -P python3Packages.kmapper \
            -P python3Packages.leidenalg \
            -P python3Packages.librosa \
            -P python3Packages.llama-cloud-services \
            -P python3Packages.llama-index-cli \
            -P python3Packages.llama-index-core \
            -P python3Packages.llama-index-embeddings-gemini \
            -P python3Packages.llama-index \
            -P python3Packages.llama-index-embeddings-google \
            -P python3Packages.llama-index-embeddings-ollama \
            -P python3Packages.llama-index-embeddings-openai \
            -P python3Packages.llama-index-embeddings-huggingface \
            -P python3Packages.llama-index-graph-stores-neo4j \
            -P python3Packages.llama-index-graph-stores-nebula \
            -P python3Packages.llama-index-graph-stores-neptune \
            -P python3Packages.llama-index-indices-managed-llama-cloud \
            -P python3Packages.llama-index-legacy \
            -P python3Packages.llama-index-llms-ollama \
            -P python3Packages.llama-index-llms-openai \
            -P python3Packages.llama-index-llms-openai-like \
            -P python3Packages.llama-index-multi-modal-llms-openai \
            -P python3Packages.llama-index-readers-database \
            -P python3Packages.llama-index-node-parser-docling \
            -P python3Packages.llama-index-readers-file \
            -P python3Packages.llama-index-readers-json \
            -P python3Packages.llama-index-readers-txtai \
            -P python3Packages.llama-index-readers-twitter \
            -P python3Packages.llama-index-readers-s3 \
            -P python3Packages.llama-index-readers-llama-parse \
            -P python3Packages.llama-index-vector-stores-chroma \
            -P python3Packages.llama-index-readers-weather \
            -P python3Packages.llama-index-vector-stores-google \
            -P python3Packages.llama-index-vector-stores-milvus \
            -P python3Packages.mlcroissant \
            -P python3Packages.neurokit2 \
            -P python3Packages.niaarm \
            -P python3Packages.llama-index-vector-stores-qdrant \
            -P python3Packages.llama-parse \
            -P python3Packages.optuna \
            -P python3Packages.optuna-dashboard \
            -P python3Packages.piano-transcription-inference \
            -P python3Packages.plotly \
            -P python3Packages.pyannote-pipeline \
            -P python3Packages.pyannote-audio \
            -P python3Packages.pymatgen \
            -P python3Packages.reflex-chakra \
            -P python3Packages.reflex \
            -P python3Packages.resampy \
            -P python3Packages.sasmodels \
            -P python3Packages.skrl \
            -P python3Packages.spacy \
            -P python3Packages.sumo \
            -P python3Packages.synergy \
            -P python3Packages.spacy-curated-transformers \
            -P python3Packages.spacy-loggers \
            -P python3Packages.spacy-lookups-data \
            -P python3Packages.spacy-transformers \
            -P python3Packages.torch-audiomentations \
            -P python3Packages.torchcrepe \
            -P python3Packages.torchlibrosa \
            -P python3Packages.whisperx \
            -P python3Packages.textnets \
            -P python3Packages.textacy \
            -P python3Packages.wandb \
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
