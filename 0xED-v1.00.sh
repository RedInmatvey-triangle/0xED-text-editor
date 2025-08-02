#!/bin/bash

clear

# Цвета (красный)
RED='\033[0;31m'
NC='\033[0m' # без цвета

echo -e "${RED}=== 0xED - простой текстовый редактор ==>
echo -e "${RED}Введите текст. Для сохранения введите ':>
echo -e "${RED}Для выхода без сохранения введите ':q' и>

buffer=()
while true; do
    # Выводим приглашение ">" красным цветом
    # окак
    echo -ne "${RED}> ${NC}"
    read line
    if [[ "$line" == ":w" ]]; then
        echo -ne "${RED}Введите имя файла для сохранени>
        read filename
        printf "%s\n" "${buffer[@]}" > "$filename"
        echo -e "${RED}Файл сохранён в '$filename'.${NC>
        break
    elif [[ "$line" == ":q" ]]; then
        echo -e "${RED}Выход без сохранения.${NC}"
        break
    else
        buffer+=("$line")
    fi
done
