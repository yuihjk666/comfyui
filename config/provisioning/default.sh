#!/bin/bash
# nai움짤 / 딸깍 NSFW WAN2.2 I2V — Vast.ai (ai-dock/ComfyUI) 프로비저닝
# 출처 워크플로: arca 163422937 + 로컬 dalkkak_nsfw_wan_local
#
# Vast 템플릿 환경변수:
#   CIVITAI_TOKEN  = Civitai API 토큰 (Fused_Triple LoRA용, 권장)
#   HF_TOKEN       = HuggingFace 토큰 (선택)
#   INSTALL_OLLAMA = true 이면 Ollama + 비전 모델까지 설치 (디스크 +6GB, 기본 false)
#
# 디스크 권장: 80GB+ (Wan High/Low ~29GB + UMT5 ~7GB + LoRA/VAE/업스케일 + 여유)

#DEFAULT_WORKFLOW="https://..."

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

# SD 체크포인트는 안 씀 (WAN I2V만)
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

# ai-dock 기본 변수명 (ESRGAN). 일부 포크는 UPSCALE_MODELS — 둘 다 채워둠
ESRGAN_MODELS=(
    "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_RCAN.safetensors"
    "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    "https://huggingface.co/MonsterMMORPG/BestImageUpscalers/resolve/main/2xLiveActionV1_SPAN_490000.pth"
)
UPSCALE_MODELS=(
    "${ESRGAN_MODELS[@]}"
)

CONTROLNET_MODELS=(
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

DISK_GB_REQUIRED=80

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    # ai-dock 스토리지 레이아웃 (심볼릭으로 ComfyUI/models 에 연결됨)
    local sd="${WORKSPACE}/storage/stable_diffusion/models"
    mkdir -p \
        "${sd}/unet/Wan2.1" \
        "${sd}/diffusion_models/Wan2.1" \
        "${sd}/lora" \
        "${sd}/vae" \
        "${sd}/clip" \
        "${sd}/text_encoders" \
        "${sd}/clip_vision" \
        "${sd}/esrgan" \
        "${sd}/upscale_models"

    # UNET / diffusion_models (워크플로 경로: Wan2.1\파일명)
    provisioning_get_models "${sd}/unet/Wan2.1" "${UNET_MODELS[@]}"
    provisioning_get_models "${sd}/diffusion_models/Wan2.1" "${UNET_MODELS[@]}"

    provisioning_get_models "${sd}/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${sd}/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${sd}/text_encoders" "${TEXT_ENCODER_MODELS[@]}"
    # CLIPLoader 가 clip/ 도 찾는 경우 대비
    provisioning_get_models "${sd}/clip" "${TEXT_ENCODER_MODELS[@]}"
    provisioning_get_models "${sd}/clip_vision" "${CLIP_VISION_MODELS[@]}"
    provisioning_get_models "${sd}/esrgan" "${ESRGAN_MODELS[@]}"
    provisioning_get_models "${sd}/upscale_models" "${UPSCALE_MODELS[@]}"

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
    # 백그라운드 serve
    export OLLAMA_NUM_GPU="${OLLAMA_NUM_GPU:-0}"
    nohup ollama serve >/var/log/ollama.log 2>&1 &
    sleep 3
    ollama pull huihui_ai/qwen3-vl-abliterated:8b-instruct || true
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
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
    if [[ -n $DISK_GB_ALLOCATED && -n $DISK_GB_REQUIRED ]]; then
        if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
            printf "WARNING: disk %sGB < recommended %sGB\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
        fi
    fi
    if [[ -z "$CIVITAI_TOKEN" ]]; then
        printf "NOTE: CIVITAI_TOKEN 없음 — Fused_Triple LoRA 다운로드가 실패할 수 있음 (NSFW-22는 HF로 받음)\n"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete.\n"
    printf "Upload workflow: dalkkak_nsfw_wan_local.png\n"
    printf "Ollama (if installed): http://127.0.0.1:11434 model huihui_ai/qwen3-vl-abliterated:8b-instruct\n\n"
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

provisioning_start
