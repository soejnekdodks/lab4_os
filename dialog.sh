#!/bin/bash
# Автор: soejnekdodks

# Оба файла используются относительно каталога запуска.
if [ ! -f ./lab4.sh ] || [ ! -r ./dialog.rc ]; then
    echo "Ошибка: запускайте dialog.sh из каталога проекта" >&2
    exit 1
fi
if ! dialog --version >/dev/null 2>&1; then
    echo "Ошибка: установите Linux Dialog" >&2
    exit 1
fi

# Dialog передаёт выбранное значение через stdout, а нажатую кнопку через код.
export DIALOGRC=./dialog.rc
export DIALOG_ERROR=254
window() {
    local status reply
    reply=$(dialog --stdout --last-key --output-separator "|" "$@")
    status=$?
    # Dialog добавляет к ответу код клавиши, например /data|10| для Enter.
    # Код 4 означает Ctrl+D, включая ввод после уже набранного пути.
    if echo "|$reply" | grep '|4|$' >/dev/null; then exit 0; fi
    ANSWER=$(echo "$reply" | sed 's/[0-9][0-9]*|$//;s/|$//')
    if [ "$status" -eq 254 ]; then
        echo "Ошибка: Dialog не смог открыть окно" >&2
        exit 1
    fi
    return "$status"
}

# Esc и Cancel прерывают текущий запрос. Пустое поле получает пояснение.
ask() {
    window --title "$1" --inputbox "$2" 10 70 || return 1
    if [ -z "$ANSWER" ]; then
        window --title "Ошибка" --msgbox "Поле не должно быть пустым" 7 50
        return 1
    fi
    return 0
}

# Окна собирают параметры. Фильтрация и расчёты выполняются в lab4.sh.
request() {
    local mode=$1 group subject test start end result title group_file found
    if [ "$mode" == "3" ]; then
        ask "Досье" "Введите начало ФИО" || return
        result=$(bash ./lab4.sh dossier "$DATA" "$ANSWER" 2>&1)
    else
        ask "Группа" "Введите номер группы" || return
        group=$ANSWER
        # Среди файлов группы ищем точное имя до перехода к следующему окну.
        found=0
        for group_file in "$DATA/students/groups/"*; do
            if [ "$group_file" == "$DATA/students/groups/$group" ] && [ -f "$group_file" ]; then
                found=1
            fi
        done
        if [ "$found" -eq 0 ]; then
            window --title "Ошибка" --msgbox "Группа не найдена: $group" 8 70
            return
        fi
        if [ "$mode" == "2" ] || [ "$mode" == "4" ]; then
            # Имя каталога остаётся значением пункта. На экране видно только описание.
            window --no-tags --title "Предмет" --menu "Выберите предмет" 12 70 2 \
                "Цирковое_Дело" "Цирковое дело" "Пересдачеведение" "Пересдачеведение" || return
            subject=$ANSWER
        fi
        if [ "$mode" == "1" ]; then
            result=$(bash ./lab4.sh top "$DATA" "$group" 2>&1)
        elif [ "$mode" == "2" ]; then
            window --title "Тест" --menu "Выберите тест" 14 50 4 \
                1 "TEST-1" 2 "TEST-2" 3 "TEST-3" 4 "TEST-4" || return
            test=$ANSWER
            result=$(bash ./lab4.sh tries "$DATA" "$group" "$subject" "$test" 2>&1)
        elif [ "$mode" == "4" ]; then
            result=$(bash ./lab4.sh best "$DATA" "$group" "$subject" 2>&1)
        else
            ask "Интервал" "Начальная пара (1–18)" || return
            start=$ANSWER
            ask "Интервал" "Конечная пара (1–18)" || return
            end=$ANSWER
            result=$(bash ./lab4.sh attend "$DATA" "$group" "$start" "$end" 2>&1)
        fi
    fi
    # Код последнего вызова определяет заголовок окна.
    if [ $? -eq 0 ]; then title="Результат"; else title="Ошибка"; fi
    window --title "$title" --msgbox "$result" 20 76
}

# Путь вводится один раз на весь сеанс.
if [ $# -gt 1 ]; then
    echo "Запуск: bash dialog.sh [каталог_данных]" >&2
    exit 1
elif [ $# -eq 1 ]; then
    DATA=$1
else
    ask "Каталог данных" "Введите путь к каталогу данных ЛР3" || exit 0
    DATA=$ANSWER
fi
if [ ! -d "$DATA" ]; then
    window --title "Ошибка" --msgbox "Каталог данных не найден: $DATA" 8 70
    exit 2
fi

# После результата или отмены отдельного запроса снова показываем функции.
while true; do
    window --title "ЛР4" --menu "Выберите функцию" 18 74 6 \
        1 "Лидеры по оценкам" 2 "Количество попыток" 3 "Досье" \
        4 "Лучшие результаты по годам" 5 "Посещаемость" 0 "Выход" || exit 0
    if [ "$ANSWER" == "0" ]; then exit 0; fi
    request "$ANSWER"
done
