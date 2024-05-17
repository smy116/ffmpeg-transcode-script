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
    if [ -z "$origin_dir" ]; then
        echo "原始文件目录不能为空"
        exit 0
    fi
    
    read -p "输入目标文件目录（不要以/结尾）：" dest_dir
    if [ -z "$dest_dir" ]; then
        echo "目标文件目录不能为空"
        exit 0
    fi


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


# 遍历原始目录
function lm_traverse_dir(){

    for file in `ls "$1"`
    do
        if [ -d "$1""/""$file" ]  	#"-d" 判断是否为目录
        then
            lm_traverse_dir "$1""/""$file"	#遍历子目录
        else  
              
            absolute_path="$1""/""$file"

            if [[ "$videotype_list[@]" =~ ".${absolute_path##*.}" ]];then 	#判断是否为视频
                
                transcode "$absolute_path"

            fi

        fi
    done
}   

function transcode(){
    relative_path=$(echo "$1" | sed "s?$origin_dir??g")
    new_file="$dest_dir""$relative_path"
    
    # 修改文件后缀名为mp4
    new_file=$(echo "$new_file" | sed "s?.${new_file##*.}?.mp4?g")
    
    # 创建文件夹
    if [ ! -d "${new_file%/*}" ]; then
        mkdir -p "${new_file%/*}"
    fi

    ffmpeg -hide_banner "${ffmpeg_decode_cmd[@]}" -i "$1" -strict -2 "${ffmpeg_videosize_cmd[@]}" "${ffmpeg_rc_cmd[@]}" "${ffmpeg_encode_cmd[@]}" "${ffmpeg_audio_cmd[@]}" -y "$new_file"
    
    # 修复权限
    chmod 777 "$new_file"
}


IFS=$'\t\n'

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


# 执行命令
if [ -f "$origin_dir" ]; then

    transcode "$origin_dir"

else

    lm_traverse_dir "$origin_dir"

fi
