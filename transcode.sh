#!/bin/bash
# ====================================================
#
#   Author        : SMY
#   File Name     : transcode.sh
#
# ====================================================

function set_config(){
    # 选择原始文件目录
    read -p "输入原始文件目录（不要以/结尾）：" origin_dir
    [ -z "$origin_dir" ] && { echo "原始文件目录不能为空"; exit 1; }
    
    read -p "输入目标文件目录（不要以/结尾）：" dest_dir
    [ -z "$dest_dir" ] && { echo "原始文件目录不能为空"; exit 1; }


    # 选择转码格式
    echo " 选择转码输出格式："
    echo " 1. h264"
    echo " 2. hevc（默认）"

    read -p "请输入选项：" ans
    ans=${ans:-2}

    case "$ans" in
        1)
            ffmpeg_code="h264"
        ;;
        2)
            ffmpeg_code="hevc"
        ;;
    esac

    # 选择解码器
    echo " 选择解码器 编码器："
    echo " 1. 软件解码 + RockChip MPP硬件编码"
    echo " 2. RockChip MPP硬件编解码（默认）"
    echo " 3. 软件编解码"

    read -p "请输入选项：" ans
    ans=${ans:-2}

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
    esac

    # 选择视频大小：
    echo " 选择视频大小："
    echo " 1. 4K"
    echo " 2. 1080P"
    echo " 3. 720P（默认）"
    echo " 4. 480P"
    echo " 5. 360P"
    read -p "请输入选项：" ans
    ans=${ans:-3}
    case "$ans" in
        1)
            if [ $ffmpeg_decode = "CPU" ] ; then
                ffmpeg_videosize_cmd=(-vf scale=-2:"'min(2160,ih)'":flags=fast_bilinear,format=yuv420p)
            elif [ $ffmpeg_decode = "MPP" ]  ; then
                ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(2160,ih)'":format=nv12:afbc=1)
            fi
        ;;
        2)
            if [ $ffmpeg_decode = "CPU" ] ; then
                ffmpeg_videosize_cmd=(-vf scale=-2:"'min(1080,ih)'":flags=fast_bilinear,format=yuv420p)
            elif [ $ffmpeg_decode = "MPP" ]  ; then
                ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(1080,ih)'":format=nv12:afbc=1)
            fi
        ;;
        3)
            if [ $ffmpeg_decode = "CPU" ] ; then
                ffmpeg_videosize_cmd=(-vf scale=-2:"'min(720,ih)'":flags=fast_bilinear,format=yuv420p)
            elif [ $ffmpeg_decode = "MPP" ]  ; then
                ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(720,ih)'":format=nv12:afbc=1)
            fi
        ;;
        4)
            if [ $ffmpeg_decode = "CPU" ] ; then
                ffmpeg_videosize_cmd=(-vf scale=-2:"'min(480,ih)'":flags=fast_bilinear,format=yuv420p)
            elif [ $ffmpeg_decode = "MPP" ]  ; then
                ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(480,ih)'":format=nv12:afbc=1)
            fi
        ;;
        5)
            if [ $ffmpeg_decode = "CPU" ] ; then
                ffmpeg_videosize_cmd=(-vf scale=-2:"'min(360,ih)'":flags=fast_bilinear,format=yuv420p)
            elif [ $ffmpeg_decode = "MPP" ]  ; then
                ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(360,ih)'":format=nv12:afbc=1)
            fi
        ;;
    esac

    # 选择视频码率：
    read -p "请输入视频码率（单位 K）（默认：2000）：" ans
    ans=${ans:-2000}
    ans="$ans""k"
    ffmpeg_rc_cmd=(-rc_mode VBR -b:v $ans -maxrate $ans -bufsize $ans)

}


# 遍历目录并将文件路径添加到列表
function lm_traverse_dir(){
    
    local base_path="$1"

    if [ ! -d "$base_path" ]; then
        echo "错误: $base_path 不是一个目录."
        return 1
    fi

    # 使用find命令递归查找视频文件并将其路径添加到数组
    while IFS= read -r -d '' file; do

        file_paths+=("$file")
    
    done < <(find "$base_path" -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" \) -print0)

}


function transcode(){
   
   # 检查传入的参数是否为有效的文件
    if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "Error: No valid file provided."
        return 1
    fi

    # 使用参数扩展进行安全的路径处理
    local relative_path="${1#$origin_dir}"
    local new_file_path="${dest_dir}${relative_path}"

    # 确保文件路径中只进行必要的后缀名替换
    new_file_path="${new_file_path%.*}.mp4"
    
    # 创建文件夹
    if [ ! -d "${new_file_path%/*}" ]; then
        mkdir -p "${new_file_path%/*}"
    fi

    # 使用ffmpeg进行转码，输出成功或失败的提示
    ffmpeg -hide_banner "${ffmpeg_decode_cmd[@]}" -i "$1" -strict -2 "${ffmpeg_videosize_cmd[@]}" "${ffmpeg_rc_cmd[@]}" "${ffmpeg_encode_cmd[@]}" "${ffmpeg_audio_cmd[@]}" -y "$new_file_path"
    if [ $? -eq 0 ]; then
        echo "Transcode Success：$1"
    else
        echo "Transcode Error：$1"
        return 1
    fi

    # 修复权限，确保成功
    chmod 777 "$new_file_path" || {
        echo "Error in file '$1': Failed to set permissions on the output file."
        return 1
    }
}


IFS=$'\t\n'
file_paths=()

videotype_list=".mp4 .mkv .mov .wmv .avi .flv"
ffmpeg_videosize_cmd=(-vf scale_rkrga=w=-2:h="'min(720,ih)'":format=nv12:afbc=1)
ffmpeg_rc_cmd=(-rc_mode VBR -b:v 2M -maxrate 2M -bufsize 2M)
ffmpeg_decode_cmd=(-hwaccel rkmpp -hwaccel_output_format drm_prime -afbc rga)
ffmpeg_audio_cmd=(-c:a copy)
ffmpeg_encode_cmd=(-c:v hevc_rkmpp)


if [ ! -n "$1" ] || [ ! -n "$2" ];then
    set_config

else

    origin_dir=$1
    dest_dir=$2

fi
dest_dir=$(printf "%s/" "${dest_dir}")

# 执行命令
if [ -f "$origin_dir" ]; then
    echo "当前输入路径为单个文件"
    file_paths=("$origin_dir")

else
    echo "当前输入路径为目录"
    origin_dir=$(printf "%s/" "${origin_dir}")

    lm_traverse_dir "$origin_dir"

fi
# 输出file_paths数组的元素数量
if [ ${#file_paths[@]} -eq 0 ]; then
    echo "文件路径数组为空！"
    exit 1
fi

# 遍历file_paths数组并调用transcode函数
transcodeTotal=0
for file_path in "${file_paths[@]}"; do
    
    let transcodeTotal=transcodeTotal+1
    echo -e "\033[43;35m开始转码第 $transcodeTotal 个文件，共计 ${#file_paths[@]} 个文件\033[0m \n"
    transcode "$file_path"
   
done
