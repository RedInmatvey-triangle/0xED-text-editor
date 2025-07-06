#!/bin/bash

# Цвета (красный)
RED='\033[0;31m'
NC='\033[0m' # без цвета

print_help() {
    echo -e "${RED}Команды редактора 0xED:${NC}"
    echo -e "${RED}:w${NC} - сохранить текст в файл"
    echo -e "${RED}:q${NC} - выйти без сохранения"
    echo -e "${RED}:h${NC} - показать справку"
    echo
}

echo -e "${RED}=== 0xED - простой текстовый редактор ==>
echo -e "${RED}Введите текст. Для справки введите ':h' >

buffer=()
while true; do
    # Выводим приглашение ">" красным цветом
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
