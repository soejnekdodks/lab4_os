#!/bin/bash
# Автор: soejnekdodks

if [ ! -f ./lab4.sh ]; then
    echo "Ошибка: запускайте dialog.sh из каталога проекта" >&2
    exit 1
fi

dialog --version >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Ошибка: установите Linux Dialog" >&2
    exit 1
fi

ask() {
    ANSWER=$(dialog --stdout --title "$1" --inputbox "$2" 10 70)
    if [ $? -ne 0 ]; then return 1; fi
    if [ -z "$ANSWER" ]; then
        dialog --title "Ошибка" --msgbox "Поле не должно быть пустым" 7 40
        return 1
    fi
    return 0
}

if [ $# -ge 1 ]; then
    DATA=$1
else
    if ask "Каталог данных" "Введите путь к каталогу данных ЛР3"; then
        DATA=$ANSWER
    else
        exit 0
    fi
fi

if [ ! -d "$DATA" ]; then
    dialog --title "Ошибка" --msgbox "Каталог данных не найден: $DATA" 8 70
    exit 2
fi

while true; do
    mode=$(dialog --stdout --title "ЛР4" --menu "Выберите функцию" 18 74 6 \
        1 "Лидеры по оценкам" \
        2 "Количество попыток" \
        3 "Досье" \
        4 "Лучшие результаты по годам" \
        5 "Посещаемость" \
        0 "Выход")
    if [ $? -ne 0 ] || [ "$mode" == "0" ]; then
        exit 0
    fi

    ready=1
    if [ "$mode" == "1" ] || [ "$mode" == "2" ] || [ "$mode" == "4" ] || [ "$mode" == "5" ]; then
        if ask "Группа" "Введите номер группы"; then
            GROUP=$ANSWER
        else
            ready=0
        fi
    fi

    if [ "$ready" -eq 1 ] && [ "$mode" == "3" ]; then
        if ask "Досье" "Введите начало ФИО"; then
            PREFIX=$ANSWER
        else
            ready=0
        fi
    fi

    if [ "$ready" -eq 1 ]; then
        if [ "$mode" == "2" ] || [ "$mode" == "4" ]; then
            SUBJECT=$(dialog --stdout --title "Предмет" --menu "Выберите предмет" 12 70 2 \
                "Цирковое_Дело" "Цирковое дело" \
                "Пересдачеведение" "Пересдачеведение")
            if [ $? -ne 0 ]; then
                ready=0
            fi
        fi
    fi

    if [ "$ready" -eq 1 ] && [ "$mode" == "2" ]; then
        TEST=$(dialog --stdout --title "Тест" --menu "Выберите тест" 14 40 4 \
            1 "TEST-1" 2 "TEST-2" 3 "TEST-3" 4 "TEST-4")
        if [ $? -ne 0 ]; then ready=0; fi
    fi

    if [ "$ready" -eq 1 ] && [ "$mode" == "5" ]; then
        if ask "Интервал" "Начальная пара (1–18)"; then
            START=$ANSWER
        else
            ready=0
        fi
        if [ "$ready" -eq 1 ]; then
            if ask "Интервал" "Конечная пара (1–18)"; then
                END=$ANSWER
            else
                ready=0
            fi
        fi
    fi

    if [ "$ready" -eq 1 ]; then
        if [ "$mode" == "1" ]; then
            result=$(bash ./lab4.sh top "$DATA" "$GROUP" 2>&1)
        elif [ "$mode" == "2" ]; then
            result=$(bash ./lab4.sh tries "$DATA" "$GROUP" "$SUBJECT" "$TEST" 2>&1)
        elif [ "$mode" == "3" ]; then
            result=$(bash ./lab4.sh dossier "$DATA" "$PREFIX" 2>&1)
        elif [ "$mode" == "4" ]; then
            result=$(bash ./lab4.sh best "$DATA" "$GROUP" "$SUBJECT" 2>&1)
        else
            result=$(bash ./lab4.sh attend "$DATA" "$GROUP" "$START" "$END" 2>&1)
        fi
        dialog --title "Результат" --msgbox "$result" 20 76
    fi
done
