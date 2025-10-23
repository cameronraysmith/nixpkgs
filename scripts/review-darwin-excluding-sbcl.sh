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

# Build exclusion list - one per line for nixpkgs-review to read
EXCLUSIONS_FILE=$(mktemp)
trap 'rm -f "$EXCLUSIONS_FILE"' EXIT

# Manual exclusions (not from find-transitive-deps.sh)
cat > "$EXCLUSIONS_FILE" << 'EOF'
calibre
unbook
python3Packages.wacz
py-wacz
python3Packages.svgdigitizer
skytemple
deeptools
das
flattenReferencesGraph
cve-bin-tool
beets
checkov
apkleaks
jadx
multiqc
aider-chat-with-browser
pianotrans
piper-tts
aider-chat-with-help
aider-chat-full
prowler
tts
unstructured-api
python312Packages.scikit-tda
python312Packages.k-diffusion
python313Packages.scikit-tda
python313Packages.k-diffusion
python312Packages.ax-platform
python312Packages.beets
python312Packages.beetcamp
python312Packages.bumps
python312Packages.chart-studio
python312Packages.compressai
python312Packages.dash
python312Packages.dash-bootstrap-templates
python312Packages.dash-bootstrap-components
python312Packages.energyflow
python312Packages.explorerscript
python312Packages.experiment-utilities
python312Packages.fastai
python312Packages.holistic-trace-analysis
python312Packages.igraph
python312Packages.hvplot
python312Packages.intake
python312Packages.iplotx
python312Packages.itables
python312Packages.kmapper
python312Packages.leidenalg
python312Packages.librosa
python312Packages.llama-cloud-services
python312Packages.llama-index-cli
python312Packages.llama-index-core
python312Packages.llama-index-embeddings-gemini
python312Packages.llama-index
python312Packages.llama-index-embeddings-google
python312Packages.llama-index-embeddings-ollama
python312Packages.llama-index-embeddings-openai
python312Packages.llama-index-embeddings-huggingface
python312Packages.llama-index-graph-stores-neo4j
python312Packages.llama-index-graph-stores-nebula
python312Packages.llama-index-graph-stores-neptune
python312Packages.llama-index-indices-managed-llama-cloud
python312Packages.llama-index-legacy
python312Packages.llama-index-llms-ollama
python312Packages.llama-index-llms-openai
python312Packages.llama-index-multi-modal-llms-openai
python312Packages.llama-index-llms-openai-like
python312Packages.llama-index-readers-database
python312Packages.llama-index-node-parser-docling
python312Packages.llama-index-readers-file
python312Packages.llama-index-readers-json
python312Packages.llama-index-readers-llama-parse
python312Packages.llama-index-readers-s3
python312Packages.llama-index-readers-txtai
python312Packages.llama-index-readers-twitter
python312Packages.llama-index-vector-stores-chroma
python312Packages.llama-index-vector-stores-milvus
python312Packages.llama-index-readers-weather
python312Packages.llama-index-vector-stores-google
python312Packages.mlcroissant
python312Packages.llama-index-vector-stores-qdrant
python312Packages.neurokit2
python312Packages.niaarm
python312Packages.llama-parse
python312Packages.optuna
python312Packages.optuna-dashboard
python312Packages.piano-transcription-inference
python312Packages.plotly
python312Packages.pyannote-pipeline
python312Packages.pyannote-audio
python312Packages.pymatgen
python312Packages.reflex-chakra
python312Packages.reflex
python312Packages.resampy
python312Packages.sasmodels
python312Packages.skrl
python312Packages.spacy
python312Packages.sumo
python312Packages.synergy
python312Packages.spacy-curated-transformers
python312Packages.spacy-loggers
python312Packages.spacy-lookups-data
python312Packages.spacy-transformers
python312Packages.torch-audiomentations
python312Packages.torchcrepe
python312Packages.torchlibrosa
python312Packages.whisperx
python312Packages.textnets
python312Packages.textacy
python312Packages.wandb
python313Packages.ax-platform
python313Packages.beetcamp
python313Packages.bumps
python313Packages.chart-studio
python313Packages.compressai
python313Packages.dash-bootstrap-templates
python313Packages.dash
python313Packages.dash-bootstrap-components
python313Packages.energyflow
python313Packages.experiment-utilities
python313Packages.explorerscript
python313Packages.fastai
python313Packages.hvplot
python313Packages.igraph
python313Packages.holistic-trace-analysis
python313Packages.intake
python313Packages.iplotx
python313Packages.itables
python313Packages.kmapper
python313Packages.leidenalg
python313Packages.librosa
python313Packages.k-diffusion
python313Packages.llama-cloud-services
python313Packages.llama-index-cli
python313Packages.llama-index
python313Packages.llama-index-core
python313Packages.llama-index-embeddings-gemini
python313Packages.llama-index-embeddings-google
python313Packages.llama-index-graph-stores-neo4j
python313Packages.llama-index-embeddings-ollama
python313Packages.llama-index-embeddings-huggingface
python313Packages.llama-index-graph-stores-neptune
python313Packages.llama-index-embeddings-openai
python313Packages.llama-index-indices-managed-llama-cloud
python313Packages.llama-index-legacy
python313Packages.llama-index-llms-ollama
python313Packages.llama-index-llms-openai
python313Packages.llama-index-llms-openai-like
python313Packages.llama-index-multi-modal-llms-openai
python313Packages.llama-index-node-parser-docling
python313Packages.llama-index-readers-file
python313Packages.llama-index-readers-database
python313Packages.llama-index-readers-json
python313Packages.llama-index-readers-weather
python313Packages.llama-index-readers-s3
python313Packages.llama-index-readers-llama-parse
python313Packages.llama-index-readers-twitter
python313Packages.llama-index-readers-txtai
python313Packages.llama-index-vector-stores-chroma
python313Packages.llama-index-vector-stores-google
python313Packages.llama-index-vector-stores-milvus
python313Packages.mlcroissant
python313Packages.neurokit2
python313Packages.niaarm
python313Packages.optuna
python313Packages.optuna-dashboard
python313Packages.llama-index-vector-stores-qdrant
python313Packages.llama-parse
python313Packages.plotly
python313Packages.piano-transcription-inference
python313Packages.pyannote-pipeline
python313Packages.pyannote-audio
python313Packages.sasmodels
python313Packages.reflex
python313Packages.resampy
python313Packages.reflex-chakra
python313Packages.skrl
python313Packages.spacy-curated-transformers
python313Packages.synergy
python313Packages.spacy
python313Packages.spacy-loggers
python313Packages.spacy-lookups-data
python313Packages.spacy-transformers
python313Packages.torchlibrosa
python313Packages.torch-audiomentations
python313Packages.torchcrepe
python313Packages.textacy
python313Packages.wandb
python313Packages.whisperx
sbclPackages.duckdb
theharvester
quark-engine
whisperx
wyoming-piper
whisper-ctranslate2
EOF

EXCLUSION_COUNT=$(wc -l < "$EXCLUSIONS_FILE" | tr -d ' ')
echo "Excluding $EXCLUSION_COUNT packages (sbcl dependencies + manual exclusions)"
echo ""

# Build skip args from file
SKIP_ARGS=""
while IFS= read -r pkg; do
    SKIP_ARGS="$SKIP_ARGS -P $pkg"
done < "$EXCLUSIONS_FILE"

# Debug: show what we built
echo "DEBUG: SKIP_ARGS has $(echo "$SKIP_ARGS" | wc -w | tr -d ' ') words"
echo "DEBUG: First 10 flags: $(echo "$SKIP_ARGS" | cut -d' ' -f1-20)"
echo ""

# Run nixpkgs-review with cachix watch-exec to push artifacts as they're built
# Note: $SKIP_ARGS is expanded by outer shell before passing to sops
# shellcheck disable=SC2086
cd ~/projects/nix-workspace/nix-config && \
sops exec-env secrets/shared.yaml "
    cd ~/projects/nixpkgs && \
    cachix watch-exec \$CACHIX_CACHE_NAME --jobs 12 -- \
        nixpkgs-review rev $BRANCH \
            --branch $BASE_BRANCH \
            --systems aarch64-darwin \
            --num-parallel-evals 12 \
            --build-args '--max-jobs 12 --cores 12 --keep-going' \
            $SKIP_ARGS \
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
