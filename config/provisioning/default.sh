#!/bin/bash
# nai움짤 / Dully WAN2.2 — Vast.ai (vastai/comfy) 프로비저닝
# 워크플로:
#   1) WAN22_Universal_Dully (통합: T2V/I2V/FLF2V/VACE/SVI/PUSA)
#      https://arca.live/b/aiart/167528900
#   2) WAN_I2I_StayConsistent_Dully (일관성 통일 I2I)
#      https://arca.live/b/aiart/160425811
#
# Vast Env:
#   HF_TOKEN       = HuggingFace 토큰 (선택, rate limit 완화)
#   CIVITAI_TOKEN  = (선택) DaSiWa를 Civitai에서 받을 때만
#   ASSETS_BASE_URL = nodes_dully/워크플로 Raw base (선택, 없으면 Google Drive)
#
# 디스크 권장: 120GB+ (I2V+T2V+VACE+LoRA+encoder ≈ 75–90GB + 여유)

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
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/JPS-GER/ComfyUI_JPS-Nodes"
    "https://github.com/kk8bit/KayTool"
)

# Google Drive (아카 공유 폴더에서 확인된 파일 ID)
GDRIVE_NODES_DULLY="1FDc-8Id7ZFYhx6ohYuOXbx64-vC-rBEq"
GDRIVE_WF_UNIVERSAL="1L9GAmLSrozTx3jANuy4vTVh5r-PZRRSy"
GDRIVE_WF_CONSIST="14rdCTEMIwR_TLXSo0HCaXEpxZPD6fB36"

DISK_GB_REQUIRED=120

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

    if [[ -f /venv/main/bin/activate ]]; then
        # shellcheck disable=SC1091
        source /venv/main/bin/activate
        PYTHON_PIP="pip"
    elif [[ -f /venv/comfyui/bin/activate ]]; then
        # shellcheck disable=SC1091
        source /venv/comfyui/bin/activate
        PYTHON_PIP="pip"
    elif [[ -x /opt/ai-dock/bin/venv-set.sh ]]; then
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

function pip_install() {
    "${PYTHON_PIP}" install --no-cache-dir "$@"
}

function provisioning_download_to() {
    # usage: provisioning_download_to URL DEST_PATH
    local url="$1"
    local dest="$2"
    local auth_token=""
    mkdir -p "$(dirname "${dest}")"
    if [[ -f "${dest}" ]]; then
        printf "Exists, skip: %s\n" "${dest}"
        return 0
    fi
    if [[ -n ${HF_TOKEN:-} && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n ${CIVITAI_TOKEN:-} && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    printf "Downloading -> %s\n" "${dest}"
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer ${auth_token}" -q --show-progress -e dotbytes=4M -O "${dest}" "${url}" \
            || curl -L --header "Authorization: Bearer ${auth_token}" -o "${dest}" "${url}"
    else
        wget -q --show-progress -e dotbytes=4M -O "${dest}" "${url}" \
            || curl -L -o "${dest}" "${url}"
    fi
}

function provisioning_gdrive_to() {
    # usage: provisioning_gdrive_to FILE_ID DEST_PATH
    local fid="$1"
    local dest="$2"
    mkdir -p "$(dirname "${dest}")"
    if [[ -f "${dest}" ]]; then
        printf "Exists, skip: %s\n" "${dest}"
        return 0
    fi
    printf "gdown %s -> %s\n" "${fid}" "${dest}"
    pip_install gdown >/dev/null 2>&1 || true
    gdown --id "${fid}" -O "${dest}" || {
        printf "WARN: gdown failed for %s\n" "${fid}"
        return 1
    }
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

function provisioning_install_sageattention() {
    printf "Installing SageAttention (일관성 워크플로 권장)...\n"
    # 휠이 없으면 소스빌드가 길 수 있음 — 실패해도 계속
    pip_install sageattention || pip_install "sageattention==1.0.6" || {
        printf "WARN: sageattention install failed — consistency workflow may be slower/broken\n"
    }
}

function provisioning_install_nodes_dully() {
    local dest="${COMFYUI_DIR}/custom_nodes/nodes_dully.py"
    if [[ -n ${ASSETS_BASE_URL:-} ]]; then
        provisioning_download_to "${ASSETS_BASE_URL%/}/nodes_dully.py" "${dest}" || true
    fi
    if [[ ! -f "${dest}" ]]; then
        provisioning_gdrive_to "${GDRIVE_NODES_DULLY}" "${dest}" || true
    fi
    if [[ -f "${dest}" ]]; then
        printf "nodes_dully.py OK (%s bytes)\n" "$(wc -c < "${dest}")"
    else
        printf "ERROR: nodes_dully.py missing — Universal workflow will show UNKNOWN nodes\n"
    fi
}

function provisioning_fetch_workflows() {
    local wdir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${wdir}" "${COMFYUI_DIR}/workflows"
    local u="${wdir}/WAN22_Universal_Dully_vast.png"
    local c="${wdir}/WAN_I2I_StayConsistent_Dully_vast.png"

    if [[ -n ${ASSETS_BASE_URL:-} ]]; then
        provisioning_download_to "${ASSETS_BASE_URL%/}/workflows/WAN22_Universal_Dully_vast.png" "${u}" || true
        provisioning_download_to "${ASSETS_BASE_URL%/}/workflows/WAN_I2I_StayConsistent_Dully_vast.png" "${c}" || true
    fi
    # Drive 원본(미패치) 폴백 — Vast에서는 로컬에서 올린 *_vast.png 사용 권장
    if [[ ! -f "${u}" ]]; then
        provisioning_gdrive_to "${GDRIVE_WF_UNIVERSAL}" "${u}" || true
    fi
    if [[ ! -f "${c}" ]]; then
        provisioning_gdrive_to "${GDRIVE_WF_CONSIST}" "${c}" || true
    fi
    # 편의 복사
    [[ -f "${u}" ]] && cp -n "${u}" "${COMFYUI_DIR}/workflows/" 2>/dev/null || true
    [[ -f "${c}" ]] && cp -n "${c}" "${COMFYUI_DIR}/workflows/" 2>/dev/null || true
}

function provisioning_get_models() {
    local md="${COMFYUI_DIR}/models"
    mkdir -p \
        "${md}/diffusion_models/WAN22/I2V/High" \
        "${md}/diffusion_models/WAN22/I2V/Low" \
        "${md}/diffusion_models/WAN22/T2V/High" \
        "${md}/diffusion_models/WAN22/T2V/Low" \
        "${md}/diffusion_models" \
        "${md}/loras/WAN22/High" \
        "${md}/loras/WAN22/Low" \
        "${md}/vae" \
        "${md}/text_encoders" \
        "${md}/clip_vision"

    # --- I2V (DaSiWa Lightspeed MidnightFlirt) — 일관성/통합 공유 ---
    provisioning_download_to \
        "https://huggingface.co/HGKI/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors/resolve/main/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors" \
        "${md}/diffusion_models/WAN22/I2V/High/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors"
    provisioning_download_to \
        "https://huggingface.co/HGKI/DasiwaWAN22I2V14BLightspeed_midnightflirtHighV7.safetensors/resolve/main/DasiwaWAN22I2V14BLightspeed_midnightflirtLowV7.safetensors" \
        "${md}/diffusion_models/WAN22/I2V/Low/DasiwaWAN22I2V14BLightspeed_midnightflirtLowV7.safetensors"

    # --- T2V (Kijai fp8) ---
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/T2V/Wan2_2-T2V-A14B_HIGH_fp8_e4m3fn_scaled_KJ.safetensors" \
        "${md}/diffusion_models/WAN22/T2V/High/Wan2_2-T2V-A14B_HIGH_fp8_e4m3fn_scaled_KJ.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/T2V/Wan2_2-T2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors" \
        "${md}/diffusion_models/WAN22/T2V/Low/Wan2_2-T2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors"

    # --- VACE modules (diffusion_models 루트 — 글 기준) ---
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/VACE/Wan2_2_Fun_VACE_module_A14B_HIGH_fp8_e4m3fn_scaled_KJ.safetensors" \
        "${md}/diffusion_models/Wan2_2_Fun_VACE_module_A14B_HIGH_fp8_e4m3fn_scaled_KJ.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/VACE/Wan2_2_Fun_VACE_module_A14B_LOW_fp8_e4m3fn_scaled_KJ.safetensors" \
        "${md}/diffusion_models/Wan2_2_Fun_VACE_module_A14B_LOW_fp8_e4m3fn_scaled_KJ.safetensors"

    # --- PUSA / SVI LoRA ---
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan22_PusaV1_lora_HIGH_resized_dynamic_avg_rank_98_bf16.safetensors" \
        "${md}/loras/WAN22/High/Wan22_PusaV1_lora_HIGH_resized_dynamic_avg_rank_98_bf16.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan22_PusaV1_lora_LOW_resized_dynamic_avg_rank_98_bf16.safetensors" \
        "${md}/loras/WAN22/Low/Wan22_PusaV1_lora_LOW_resized_dynamic_avg_rank_98_bf16.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors" \
        "${md}/loras/WAN22/High/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors"

    # --- text / vae / clip_vision ---
    provisioning_download_to \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        "${md}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
        "${md}/vae/wan_2.1_vae.safetensors"
    provisioning_download_to \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
        "${md}/clip_vision/clip_vision_h.safetensors"

    # RIFE (Universal 보간)
    local rife="${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
    mkdir -p "${rife}"
    provisioning_download_to \
        "https://huggingface.co/marduk191/rife/resolve/main/rife49.pth" \
        "${rife}/rife49.pth"
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "# nai움짤 Dully WAN2.2 Vast provisioning    #\n"
    printf "##############################################\n\n"
    if [[ -n ${DISK_GB_ALLOCATED:-} && -n ${DISK_GB_REQUIRED:-} ]]; then
        if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
            printf "WARNING: disk %sGB < recommended %sGB\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
        fi
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete.\n"
    printf "Workflows (upload if missing):\n"
    printf "  - WAN22_Universal_Dully_vast.png\n"
    printf "  - WAN_I2I_StayConsistent_Dully_vast.png\n"
    printf "Models under: models/diffusion_models/WAN22/{I2V,T2V}/{High,Low}\n"
    printf "LoRAs under: models/loras/WAN22/{High,Low}\n"
    printf "SageAttention required for consistency workflow.\n\n"
}

function provisioning_start() {
    provisioning_resolve_paths
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_install_nodes_dully
    provisioning_install_sageattention
    provisioning_get_pip_packages
    provisioning_get_models
    provisioning_fetch_workflows
    provisioning_print_end
}

provisioning_start
