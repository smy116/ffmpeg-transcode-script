#!/bin/bash
# ====================================================
#
#   Author        : SMY
#   File Name     : transcode.sh
#   Description   : A script to transcode videos using ffmpeg with user-selected configurations including
#                   source directory, destination directory, video codec, decoder, video size, and video bitrate.
#
# ====================================================


# 初始化变量
IFS=$'\t\n'
SCRIPT_DIR=$(dirname "$0")
video_file_paths=()
other_file_paths=()
silent_mode=0
origin_dir=""
dest_dir=""
ffmpeg_decode=""
ffmpeg_videosize_cmd=()
ffmpeg_rc_cmd=()
ffmpeg_decode_cmd=()
ffmpeg_audio_cmd=()
ffmpeg_encode_cmd=()
video_format=("mp4" "mkv" "avi" "wmv" "flv" "mov" "m4v" "rm" "rmvb" "3gp" "vob") 

# 根据用户选择设置输出格式
function set_format() {
    local ans
    echo "选择转码输出格式："
    
    if [ $silent_mode -eq 1 ]; then
        ans="abc"
    else
        echo "1. h264"
        echo "2. hevc（默认）"
        read -p "请输入选项：" ans
    fi

    case "$ans" in
        1)
            ffmpeg_code="h264"
        ;;
        2)
            ffmpeg_code="hevc"
        ;;
        *)
            echo "无效选择，将使用默认选项：hevc"
            ffmpeg_code="hevc"
        ;;
    esac
}
# 根据用户选择设置遍解码器
function set_coder() {
    local ans
    echo "选择编码器 解码器："
    
    if [ $silent_mode -eq 1 ]; then
        ans="abc"
    else
        echo "1. 软件解码 + RockChip MPP硬件编码"
        echo "2. RockChip MPP硬件编解码（默认）"
        echo "3. 软件编解码"
        read -p "请输入选项：" ans
    fi

    case "$ans" in
        1)
            ffmpeg_decode="CPU"
            ffmpeg_decode_cmd=()
            
            if [ $ffmpeg_code = "h264" ] ; then
                ffmpeg_encode_cmd=(-c:v h264_rkmpp)
            elif [ $ffmpeg_code = "hevc" ]  ; then
                ffmpeg_encode_cmd=(-c:v hevc_rkmpp)
            fi

        ;;
        2)
            ffmpeg_decode="MPP"
            ffmpeg_decode_cmd=(-hwaccel rkmpp -hwaccel_output_format drm_prime -afbc rga)

            if [ $ffmpeg_code = "h264" ] ; then
                ffmpeg_encode_cmd=(-c:v h264_rkmpp)
            elif [ $ffmpeg_code = "hevc" ]  ; then
                ffmpeg_encode_cmd=(-c:v hevc_rkmpp)
            fi
        ;;
        3)
            ffmpeg_decode="CPU"
            ffmpeg_decode_cmd=()

            if [ $ffmpeg_code = "h264" ] ; then
                ffmpeg_encode_cmd=(-c:v libx264)
            elif [ $ffmpeg_code = "hevc" ]  ; then
                ffmpeg_encode_cmd=(-c:v libx265)
            fi
        ;;
        *)
            echo "无效选择，将使用默认选项：RockChip MPP硬件编解码"
            ffmpeg_decode="MPP"
            ffmpeg_decode_cmd=(-hwaccel rkmpp -hwaccel_output_format drm_prime -afbc rga)
            
            if [ $ffmpeg_code = "h264" ] ; then
                ffmpeg_encode_cmd=(-c:v h264_rkmpp)
            elif [ $ffmpeg_code = "hevc" ]  ; then
                ffmpeg_encode_cmd=(-c:v hevc_rkmpp)
            fi
        ;;
    esac
}

# 根据用户选择设置视频大小
function set_video_size() {
    local ans video_high
    # 根据用户选择设置视频大小
    echo "选择视频大小："

    if [ $silent_mode -eq 1 ]; then
        ans="abc"
    else
        echo "1. 4K"
        echo "2. 1080P"
        echo "3. 720P（默认）"
        echo "4. 480P"
        echo "5. 360P"
        read -p "请输入选项：" ans
    fi

    case "$ans" in
        1)
            video_high=2160
        ;;
        2)
            video_high=1080
        ;;
        3)
            video_high=720
        ;;
        4)
            video_high=480
        ;;
        5)
            video_high=360
        ;;
        *)
            echo "无效选择，将使用默认选项：720P"
            video_high=720
        ;;
    esac

    case "$ffmpeg_decode" in
        "CPU")
            ffmpeg_videosize_cmd=(-vf scale=-2:"'min($video_high,ih)'":flags=fast_bilinear,format=yuv420p)
        ;;
        "MPP")
            ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min($video_high,ih)'":format=nv12:afbc=1)
        ;;
    esac
    
}


function set_video_size() {
    local ans video_high
    # 根据用户选择设置视频大小
    echo "选择视频大小："

    if [ $silent_mode -eq 1 ]; then
        ans="abc"
    else
        echo "1. 4K"
        echo "2. 1080P"
        echo "3. 720P（默认）"
        echo "4. 480P"
        echo "5. 360P"
        read -p "请输入选项：" ans
    fi

    case "$ans" in
        1)
            video_high=2160
        ;;
        2)
            video_high=1080
        ;;
        3)
            video_high=720
        ;;
        4)
            video_high=480
        ;;
        5)
            video_high=360
        ;;
        *)
            echo "无效选择，将使用默认选项：720P"
            video_high=720
        ;;
    esac

    case "$ffmpeg_decode" in
        "CPU")
            ffmpeg_videosize_cmd=(-vf scale=-2:"'min($video_high,ih)'":flags=fast_bilinear,format=yuv420p)
        ;;
        "MPP")
            ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min($video_high,ih)'":format=nv12:afbc=1)
        ;;
    esac
    
}


# 设置视频码率
function set_video_bitrate() {
    local ans video_bitrate
    # 根据用户选择设置视频码率
    echo "选择视频码率或直接输入码率："
    if [ $silent_mode -eq 1 ]; then
        ans="abc"
    else
        echo "1. 1000k"
        echo "2. 2000k（默认）"
        echo "3. 3000k"
        echo "4. 4000k"
        echo "5. 5000k"
        read -p "请输入选项：" ans
    fi

    case "$ans" in
        1)
            video_bitrate=1000
        ;;
        2)
            video_bitrate=2000
        ;;
        3)
            video_bitrate=3000
        ;;
        4)
            video_bitrate=4000
        ;;
        5)
            video_bitrate=5000
        ;;
        *)
            # 验证输入值是否在100-100000之间
            if ! [[ $ans =~ ^[1-9][0-9]{1,4}$ ]]; then
                echo "无效选择，将使用默认选项：2000k"
                video_bitrate=2000
            else
                video_bitrate=$ans

            fi
        ;;
    esac
    video_bitrate="$video_bitrate""k"
    ffmpeg_rc_cmd=(-rc_mode VBR -b:v $video_bitrate -maxrate $video_bitrate -bufsize $video_bitrate)

}

# 检查文件是否符合给定的视频格式列表
is_video_format() {
    local file="$1"
    for format in "${video_format[@]}"; do
        if [[ "$file" == *."$format" ]]; then
            return 0
        fi
    done
    return 1
}

# 日志写入
function _write_log() {
    local message="$1"
    echo "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "${SCRIPT_DIR}/transcode.log"
}


# 遍历目录并将文件路径添加到列表
function lm_traverse_dir(){
    
    local base_path="$1"
    local all_files=()
    local file=""
    
    # 检查是否为目录
    if [ ! -d "$base_path" ]; then
        echo "错误: $base_path 不是一个目录."
        return 1
    fi

    # 使用find命令递归查找所有文件并添加到数组
    while IFS= read -r -d '' file; do
        all_files+=("$file")
    done < <(find "$base_path" -type f -print0)
    
    # 筛选符合video_format要求的文件并输出结果
    for file in "${all_files[@]}"; do
        if is_video_format "$file"; then
            video_file_paths+=("$file")
        else
            other_file_paths+=("$file")
        fi
    done

}

function transcode_video(){
   
    # 检查输入参数是否为有效文件
    if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "Error: No valid file provided."
        return 1
    fi

    # 安全路径处理
    local relative_path="${1#$origin_dir}"
    local new_file_path="${dest_dir}${relative_path}"

    # 确保只进行必要的后缀替换
    new_file_path="${new_file_path%.*}.mp4"
    
    # 创建文件夹
    if [ ! -d "${new_file_path%/*}" ]; then
        mkdir -p "${new_file_path%/*}"
    fi

    # 使用ffmpeg进行转码
    ffmpeg -hide_banner "${ffmpeg_decode_cmd[@]}" -i "$1" -strict -2 "${ffmpeg_videosize_cmd[@]}" "${ffmpeg_rc_cmd[@]}" "${ffmpeg_encode_cmd[@]}" "${ffmpeg_audio_cmd[@]}" -y "$new_file_path"
    if [ $? -eq 0 ]; then
        _write_log "转码成功：$1"
    else
        _write_log "转码失败：$1"
        return 1
    fi

    # 修复权限
    chmod 777 "$new_file_path" || {
        echo "Error in file '$1': Failed to set permissions on the output file."
        return 1
    }
}

# 将其他文件类型复制到新目录
function copy_other_files(){ 
    
    local copyTotal=0
    local file_path=""
    for file_path in "${other_file_paths[@]}"; do
        
        let copyTotal=copyTotal+1
        _write_log "开始复制第 $copyTotal 个文件，共计 ${#other_file_paths[@]} 个文件"
        cp "$file_path" "${dest_dir}${file_path#$origin_dir}"
    
    done

}

function main(){

    # 如未提供目录参数，则进行配置设置
    if [ ! -n "$1" ];then
        
        # 读取并验证原始文件目录和目标文件目录
        read -p "输入原始文件目录：" origin_dir
        [ -z "$origin_dir" ] && { echo "原始文件目录不能为空"; exit 1; }
        
        read -p "输入目标文件目录：" dest_dir
        [ -z "$dest_dir" ] && { echo "目标文件目录不能为空"; exit 1; }

    else

        silent_mode=1
        origin_dir="$1"
        dest_dir="$2"

    fi

    dest_dir=$(printf "%s/" "${dest_dir}")

    # 选择转码输出格式
    set_format

    # 设置解码器和编码器
    set_coder

    # 设置视频大小
    set_video_size    

    # 设置视频码率
    set_video_bitrate
    
    # 检查输入是否为目录还是文件
    if [ -d "$origin_dir" ]; then
        echo "当前输入路径为目录"
        origin_dir=$(printf "%s/" "${origin_dir}")

        lm_traverse_dir "$origin_dir"

    else
        echo "当前输入路径为单个文件"

        # 判断是否为视频文件
        if ! is_video_format "$origin_dir"; then
            echo "Error: $origin_dir 不是视频文件"
            exit 1
        fi
        video_file_paths=("$origin_dir")
    fi

    # 输出视频文件路径数组数量
    if [ ${#video_file_paths[@]} -eq 0 ]; then
        echo "文件路径数组为空！"
        exit 1
    fi

    # 遍历视频文件路径数组并转码
    transcodeTotal=0
    for file_path in "${video_file_paths[@]}"; do
        
        let transcodeTotal=transcodeTotal+1
        _write_log "开始转码第 $transcodeTotal 个文件，共计 ${#video_file_paths[@]} 个文件"
        transcode_video "$file_path"
    
    done


}

main "$@"
