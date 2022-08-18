#!/bin/bash

if [[ -n "${APPIMGAGE_FOLDER}" ]]; then
    appimage_folder=$APPIMGAGE_FOLDER
else
    appimage_folder="$HOME/.appimage"
fi

if [[ ! -d "${appimage_folder}" ]]; then
    mkdir "$appimage_folder"
    echo "Created folder $appimage_folder"
fi

if [[ ! -d "${appimage_folder}/.metadata" ]]; then
    mkdir "$appimage_folder/.metadata"
fi

copy_image() {
    image_path=$1
    image_name=$2

    cp "$image_path" "$appimage_folder/$image_name"
    chmod +x "$appimage_folder/$image_name"
}

copy_icon() {
    image_path=$1
    icon_name=$2
    app_name=$3

    offset=$("$image_path" "--appimage-offset")

    eval "unsquashfs -f -o $offset -d $appimage_folder/.metadata $image_path $icon_name.png 1> /dev/null"

    # main icon is usualy link so ...
    if [[ -L "$appimage_folder/.metadata/$icon_name.png" ]]; then
        png_path=$(readlink "$appimage_folder"/.metadata/"$icon_name".png)

        eval "unsquashfs -f -o $offset -d $appimage_folder/.metadata $image_path $png_path 1> /dev/null"

        rm "$appimage_folder/.metadata/$icon_name.png"
        cp "$appimage_folder/.metadata/$png_path" "$appimage_folder/.metadata/$icon_name.png"

        rm -r "$appimage_folder/.metadata/$(echo "$png_path" | cut -d"/" -f1)"
    fi

    mv "$appimage_folder/.metadata/$icon_name.png" "$appimage_folder/.metadata/$app_name.png"
}

get_data() {
    image_path=$1
    offset=$("$image_path" "--appimage-offset")

    rm -r "$appimage_folder/.metadata/tmp" 2>/dev/null
    eval "unsquashfs -f -o $offset -d $appimage_folder/.metadata/tmp $image_path *.desktop 1> /dev/null"

    app_name=$(grep Name= <"$appimage_folder"/.metadata/tmp/*.desktop | cut -d"=" -f2)
    app_version=$(grep X-AppImage-Version= <"$appimage_folder"/.metadata/tmp/*.desktop | cut -d"=" -f2)
    app_icon=$(grep Icon= <"$appimage_folder"/.metadata/tmp/*.desktop | cut -d"=" -f2)

    rm -r "$appimage_folder/.metadata/tmp"
}

set_desktop_file() {
    app_name=$1
    app_version=$2

    content="[Desktop Entry]
Version=$app_version
Type=Application
Name=$app_name
Exec=$appimage_folder/$app_name
Icon=$appimage_folder/.metadata/$app_name.png
Terminal=false
"
    echo "$content" >"$HOME/.local/share/applications/$app_name.desktop"
}

install_image() {
    chmod +x "$1"
    if [[ ! $1 == /* ]]; then
        image_path="./$1"
    fi

    image_path="./$1"
    if ! eval "$image_path" "--appimage-version" 2>/dev/null; then
        echo "Error: $image_path is not appimage file"
        return 1
    fi

    chmod +x "$image_path"
    get_data "$image_path"
    copy_image "$image_path" "$app_name"
    copy_icon "$image_path" "$app_icon" "$app_name"
    set_desktop_file "$app_name" "$app_version"

    echo "AppImage: $1 installed."
}

sync_images() {
    files=$(ls "$appimage_folder")
    for file in $files; do
        chmod +x "$appimage_folder/$file"
        if eval "$appimage_folder/$file" "--appimage-version" 2>/dev/null; then
            echo "Installing or reinstalling $file"
            get_data "$appimage_folder/$file"
            copy_icon "$appimage_folder/$file" "$app_icon" "$app_name"
            set_desktop_file "$app_name" "$app_version"
            echo "AppImage: $file installed"
        fi
    done
}

get_appimage_names() {
    available_images=$(ls "$appimage_folder")
    output=""
    for file in $available_images; do
        if eval "$appimage_folder/$file" "--appimage-version" 2>/dev/null; then
            get_data "$appimage_folder/$file"
            output="$output $app_name "
        fi
    done
    echo "$output"
}

delete_desktop_files() {
    files=$(ls "$appimage_folder/.metadata")
    available_images=$(get_appimage_names)
    for file in $files; do
        file_name=$(basename "$file" .png)
        if [[ ! $available_images =~ $file_name ]]; then
            rm "$appimage_folder/.metadata/$file"
            rm "$HOME/.local/share/applications/$file_name.desktop"
        fi
    done
}

help() {
    echo "Usage: appimage-install [FILE]"
    echo "Copy appimgae file to into folder for images and set desktop icon"
    echo "If is called without file sync all images in images folder"
    echo "Default folder for images is ~/.appimage or could be set in APPIMGAGE_FOLDER variable"
    echo ""
    echo "  --help             display this help and exit"
}



if [[ -n "$1" ]]; then
    if [[ $1 == "--help" ]]; then
        help
        return
    fi

    install_image "$1"
else
    sync_images
    delete_desktop_files
fi
