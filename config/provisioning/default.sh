#!/bin/bash
# nai움짤 / 딸깍 NSFW WAN2.2 I2V — Vast.ai (vastai/comfy) 프로비저닝
# 출처 워크플로: arca 163422937 + 로컬 dalkkak_nsfw_wan_local
#
# Vast 템플릿 환경변수:
#   CIVITAI_TOKEN  = Civitai API 토큰 (Fused_Triple LoRA용, 권장)
#   HF_TOKEN       = HuggingFace 토큰 (선택)
#   INSTALL_OLLAMA = true 이면 Ollama + 비전 모델까지 설치 (디스크 +6GB, 기본 false)
#
# 디스크 권장: 80GB+ (Wan High/Low ~29GB + UMT5 ~7GB + LoRA/VAE/업스케일 + 여유)

APT_PACKAGES=(
    #"ffmpeg"
)

PIP_PACKAGES=(
    #"package-1"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/stavsap/comfyui-ollama"
    "https://github.com/willmiao/ComfyUI-Lora-Manager"
    "https://github.com/wallish77/wlsh_nodes"
    "https://github.com/JPS-GER/ComfyUI_JPS-Nodes"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/melMass/comfy_mtb"
    "https://github.com/chrisgoringe/cg-use-everywhere"
    "https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/filliptm/ComfyUI_Fill-Nodes"
)

CHECKPOINT_MODELS=(
)

# DaSiWa WAN 2.2 I2V High/Low (HF 미러)
UNET_MODELS=(
    "https://huggingface.co/HGKI/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors/resolve/main/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors"
    "https://huggingface.co/HGKI/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors/resolve/main/DasiwaWAN22I2V14BLightspeed_midnightflirtLowV7.safetensors"
)

LORA_MODELS=(
    "https://huggingface.co/ricecake/NSFW-22-H-e8/resolve/main/NSFW-22-H-e8.safetensors"
    "https://huggingface.co/yeqiu168182/NSFW-22-L-e8/resolve/main/NSFW-22-L-e8.safetensors"
    # 푸쉬드 / Fused_Triple — CIVITAI_TOKEN 필요
    "https://civitai.com/api/download/models/2293529?type=Model&format=SafeTensor"
    "https://civitai.com/api/download/models/2293622?type=Model&format=SafeTensor"
)

VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

TEXT_ENCODER_MODELS=(
    "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
)

CLIP_VISION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_RCAN.safetensors"
    "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    "https://huggingface.co/MonsterMMORPG/BestImageUpscalers/resolve/main/2xLiveActionV1_SPAN_490000.pth"
)

DISK_GB_REQUIRED=80

function provisioning_resolve_paths() {
    WORKSPACE="${WORKSPACE:-/workspace}"

    if [[ -d "${WORKSPACE}/ComfyUI" ]]; then
        COMFYUI_DIR="${WORKSPACE}/ComfyUI"
    elif [[ -d /opt/ComfyUI ]]; then
        COMFYUI_DIR="/opt/ComfyUI"
    else
        COMFYUI_DIR="${WORKSPACE}/ComfyUI"
        mkdir -p "${COMFYUI_DIR}"
    fi

    # vastai/comfy 기본 venv
    if [[ -f /venv/main/bin/activate ]]; then
        # shellcheck disable=SC1091
        source /venv/main/bin/activate
        PYTHON_PIP="pip"
    elif [[ -f /venv/comfyui/bin/activate ]]; then
        # shellcheck disable=SC1091
        source /venv/comfyui/bin/activate
        PYTHON_PIP="pip"
    elif [[ -x /opt/ai-dock/bin/venv-set.sh ]]; then
        # 구 ai-dock 이미지 호환
        # shellcheck disable=SC1091
        source /opt/ai-dock/etc/environment.sh 2>/dev/null || true
        # shellcheck disable=SC1091
        source /opt/ai-dock/bin/venv-set.sh comfyui
        PYTHON_PIP="${COMFYUI_VENV_PIP:-pip}"
    else
        PYTHON_PIP="pip"
    fi

    printf "COMFYUI_DIR=%s\n" "${COMFYUI_DIR}"
    printf "PIP=%s (%s)\n" "${PYTHON_PIP}" "$(command -v "${PYTHON_PIP}" || echo missing)"
}

function provisioning_start() {
    provisioning_resolve_paths
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    local md="${COMFYUI_DIR}/models"
    mkdir -p \
        "${md}/diffusion_models/Wan2.1" \
        "${md}/unet/Wan2.1" \
        "${md}/loras" \
        "${md}/vae" \
        "${md}/clip" \
        "${md}/text_encoders" \
        "${md}/clip_vision" \
        "${md}/upscale_models" \
        "${md}/esrgan"

    # UNET / diffusion_models (워크플로 경로: Wan2.1\파일명)
    provisioning_get_models "${md}/diffusion_models/Wan2.1" "${UNET_MODELS[@]}"
    provisioning_get_models "${md}/unet/Wan2.1" "${UNET_MODELS[@]}"

    provisioning_get_models "${md}/loras" "${LORA_MODELS[@]}"
    provisioning_get_models "${md}/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${md}/text_encoders" "${TEXT_ENCODER_MODELS[@]}"
    provisioning_get_models "${md}/clip" "${TEXT_ENCODER_MODELS[@]}"
    provisioning_get_models "${md}/clip_vision" "${CLIP_VISION_MODELS[@]}"
    provisioning_get_models "${md}/upscale_models" "${ESRGAN_MODELS[@]}"
    provisioning_get_models "${md}/esrgan" "${ESRGAN_MODELS[@]}"

    provisioning_maybe_install_ollama
    provisioning_print_end
}

function provisioning_maybe_install_ollama() {
    if [[ "${INSTALL_OLLAMA,,}" != "true" ]]; then
        printf "INSTALL_OLLAMA!=true — Ollama 생략 (ComfyUI에서 수동 프롬프트 사용 가능)\n"
        return 0
    fi
    printf "Installing Ollama (CPU 권장: OLLAMA_NUM_GPU=0)...\n"
    if ! command -v ollama >/dev/null 2>&1; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    export OLLAMA_NUM_GPU="${OLLAMA_NUM_GPU:-0}"
    nohup ollama serve >/var/log/ollama.log 2>&1 &
    sleep 3
    ollama pull huihui_ai/qwen3-vl-abliterated:8b-instruct || true
}

function pip_install() {
    "${PYTHON_PIP}" install --no-cache-dir "$@"
}

function provisioning_get_apt_packages() {
    if [[ -n ${APT_PACKAGES[*]:-} ]]; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n ${PIP_PACKAGES[*]:-} ]]; then
        pip_install "${PIP_PACKAGES[@]}"
    fi
}

function provisioning_get_nodes() {
    mkdir -p "${COMFYUI_DIR}/custom_nodes"
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements" || true
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}" || true
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z ${2:-} ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        [[ -z "$url" || "$url" =~ ^# ]] && continue
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "# nai움짤 dalkkak WAN provisioning           #\n"
    printf "##############################################\n\n"
    if [[ -n ${DISK_GB_ALLOCATED:-} && -n ${DISK_GB_REQUIRED:-} ]]; then
        if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
            printf "WARNING: disk %sGB < recommended %sGB\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
        fi
    fi
    if [[ -z "${CIVITAI_TOKEN:-}" ]]; then
        printf "NOTE: CIVITAI_TOKEN 없음 — Fused_Triple LoRA 다운로드가 실패할 수 있음 (NSFW-22는 HF로 받음)\n"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete.\n"
    printf "Upload workflow: dalkkak_nsfw_wan_local.png\n"
    printf "Ollama (if installed): http://127.0.0.1:11434 model huihui_ai/qwen3-vl-abliterated:8b-instruct\n\n"
}

function provisioning_download() {
    local auth_token=""
    if [[ -n ${HF_TOKEN:-} && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n ${CIVITAI_TOKEN:-} && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

provisioning_start
