#!/bin/bash

# Цвета (красный)
RED='\033[0;31m'
NC='\033[0m' # без цвета

echo -e "${RED}=== 0xED - простой текстовый редактор ===${NC}"
echo -e "${RED}Введите текст. Для сохранения введите ':w' и нажмите Enter.${NC}"
echo -e "${RED}Для выхода без сохранения введите ':q' и нажмите Enter.${NC}"

buffer=()
while true; do
    # Выводим приглашение "1>" красным цветом
    echo -ne "${RED}1> ${NC}"
    read line
    if [[ "$line" == ":w" ]]; then
        echo -ne "${RED}Введите имя файла для сохранения: ${NC}"
        read filename
        printf "%s\n" "${buffer[@]}" > "$filename"
        echo -e "${RED}Файл сохранён в '$filename'.${NC}"
        break
    elif [[ "$line" == ":q" ]]; then
        echo -e "${RED}Выход без сохранения.${NC}"
        break
    else
        buffer+=("$line")
    fi
done
