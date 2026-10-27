#!/bin/bash
# ЛР4: работаем с файловой системой преподавателя из ЛР3 (каталог вида labfiles-3-26)
#
# Запуск: ./lab4.sh <режим> <путь_к_данным> [параметры режима]
# Что умеет и как звать - ./lab4.sh help
#
# Коды выхода:
#   0 - все ок
#   1 - что-то не так с аргументами
#   2 - не найдены данные или группа
#   3 - режим еще не дописан

# предметы из данных ЛР3 (у каждого внутри tests/TEST-1..4 и файлы посещаемости)
SUBJECTS=("Цирковое_Дело" "Пересдачеведение")

if [ $# -lt 1 ]; then
    echo "Ошибка: не указан режим. Подсказка: ./lab4.sh help" >&2
    exit 1
fi

MODE=$1

if [ "$MODE" = "help" ] || [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ]; then
    echo "ЛР4: обработка файловой системы преподавателя из ЛР3"
    echo ""
    echo "Запуск: ./lab4.sh <режим> <путь_к_данным> [параметры режима]"
    echo ""
    echo "Режимы:"
    echo "  top     <группа>              лидеры по количеству 5, 4 и 3 по тестам"
    echo "  tries   <группа>              список группы по количеству попыток"
    echo "  dossier <фамилия>             досье по фамилии"
    echo "  best    <группа>              лучшие результаты за каждый год"
    echo "  attend  <группа> <нач> <кон>  средняя посещаемость за интервал"
    echo "  help                          эта справка"
    exit 0
fi

if [ $# -lt 2 ]; then
    echo "Ошибка: не указан путь к данным. Подсказка: ./lab4.sh help" >&2
    exit 1
fi

DATA=$2

# путь к данным передаем параметром, чтобы скрипт не был привязан к одному компьютеру
if [ ! -d "$DATA" ]; then
    echo "Ошибка: каталог данных не найден: $DATA" >&2
    exit 2
fi

# проверяем, что на месте каталоги предметов
for subj in "${SUBJECTS[@]}"; do
    if [ ! -d "$DATA/$subj" ]; then
        echo "Ошибка: в '$DATA' нет каталога предмета: $subj" >&2
        exit 2
    fi
done

# параметры режима идут с $3: $1 - режим, $2 - путь

# этим трем нужна только группа
if [ "$MODE" = "top" ] || [ "$MODE" = "tries" ] || [ "$MODE" = "best" ]; then
    if [ $# -lt 3 ]; then
        echo "Ошибка: для режима '$MODE' нужен номер группы. Подсказка: ./lab4.sh help" >&2
        exit 1
    fi
    GROUP=$3
    # список студентов группы лежит в файле students/groups/<группа>
    if [ ! -f "$DATA/students/groups/$GROUP" ]; then
        echo "Ошибка: группа не найдена: $GROUP" >&2
        exit 2
    fi
fi

# ---- режим top: лидеры группы по количеству 5, 4 и 3 за тесты ----
# Трактовка требования: отдельные лидеры по каждой из оценок (5, 4, 3).
# Трактовка ожидает подтверждения преподавателем через менеджера.
# При одинаковом максимуме выводим всех лидеров, по алфавиту.
if [ "$MODE" = "top" ]; then
    # параллельные массивы: студент и количество его 5, 4 и 3
    FIOS=()
    CNT5=()
    CNT4=()
    CNT3=()

    # собираем все попытки группы из всех тестов всех предметов за все годы
    for subj in "${SUBJECTS[@]}"; do
        for tfile in "$DATA/$subj"/tests/TEST-*; do
            if [ ! -f "$tfile" ]; then
                continue
            fi
            # строка попытки: группа;фио;дата;количество правильных;оценка
            while read -r line || [ -n "$line" ]; do
                if [ -z "$line" ]; then
                    continue
                fi
                grp=$(echo "$line" | sed 's/;.*//')
                if [ "$grp" != "$GROUP" ]; then
                    continue
                fi
                fio=$(echo "$line" | sed 's/^[^;]*;//' | sed 's/;.*//')
                # оценка может быть записана с модификатором (например 5+),
                # поэтому берем только первый символ
                grade=$(echo "$line" | sed 's/^[^;]*;[^;]*;[^;]*;[^;]*;//' | sed 's/;.*//')
                grade=${grade:0:1}

                # ищем студента в массиве
                idx=-1
                i=0
                while [ $i -lt ${#FIOS[@]} ]; do
                    if [ "${FIOS[$i]}" = "$fio" ]; then
                        idx=$i
                    fi
                    i=$((i+1))
                done
                if [ $idx -lt 0 ]; then
                    idx=${#FIOS[@]}
                    FIOS[$idx]=$fio
                    CNT5[$idx]=0
                    CNT4[$idx]=0
                    CNT3[$idx]=0
                fi

                if [ "$grade" = "5" ]; then
                    CNT5[$idx]=$(( ${CNT5[$idx]} + 1 ))
                elif [ "$grade" = "4" ]; then
                    CNT4[$idx]=$(( ${CNT4[$idx]} + 1 ))
                elif [ "$grade" = "3" ]; then
                    CNT3[$idx]=$(( ${CNT3[$idx]} + 1 ))
                fi
            done < "$tfile"
        done
    done

    if [ ${#FIOS[@]} -eq 0 ]; then
        echo "По группе $GROUP в тестах нет записей"
        exit 0
    fi

    # максимум по каждой из оценок
    MAX5=0
    MAX4=0
    MAX3=0
    i=0
    while [ $i -lt ${#FIOS[@]} ]; do
        if [ ${CNT5[$i]} -gt $MAX5 ]; then MAX5=${CNT5[$i]}; fi
        if [ ${CNT4[$i]} -gt $MAX4 ]; then MAX4=${CNT4[$i]}; fi
        if [ ${CNT3[$i]} -gt $MAX3 ]; then MAX3=${CNT3[$i]}; fi
        i=$((i+1))
    done

    # списки лидеров (по одному в строке), ниже печатаем через sort
    LIST5=""
    LIST4=""
    LIST3=""
    i=0
    while [ $i -lt ${#FIOS[@]} ]; do
        if [ $MAX5 -gt 0 ] && [ ${CNT5[$i]} -eq $MAX5 ]; then
            if [ -z "$LIST5" ]; then
                LIST5="${FIOS[$i]}"
            else
                LIST5="$LIST5
${FIOS[$i]}"
            fi
        fi
        if [ $MAX4 -gt 0 ] && [ ${CNT4[$i]} -eq $MAX4 ]; then
            if [ -z "$LIST4" ]; then
                LIST4="${FIOS[$i]}"
            else
                LIST4="$LIST4
${FIOS[$i]}"
            fi
        fi
        if [ $MAX3 -gt 0 ] && [ ${CNT3[$i]} -eq $MAX3 ]; then
            if [ -z "$LIST3" ]; then
                LIST3="${FIOS[$i]}"
            else
                LIST3="$LIST3
${FIOS[$i]}"
            fi
        fi
        i=$((i+1))
    done

    echo "Группа $GROUP: лидеры по количеству оценок за тесты (все предметы)"
    if [ $MAX5 -gt 0 ]; then
        echo "Пятёрки (максимум $MAX5):"
        echo "$LIST5" | sort | while read -r name; do
            echo "  $name"
        done
    else
        echo "Пятёрки: в группе нет ни одной"
    fi
    if [ $MAX4 -gt 0 ]; then
        echo "Четвёрки (максимум $MAX4):"
        echo "$LIST4" | sort | while read -r name; do
            echo "  $name"
        done
    else
        echo "Четвёрки: в группе нет ни одной"
    fi
    if [ $MAX3 -gt 0 ]; then
        echo "Тройки (максимум $MAX3):"
        echo "$LIST3" | sort | while read -r name; do
            echo "  $name"
        done
    else
        echo "Тройки: в группе нет ни одной"
    fi
    exit 0
fi

# tries и best пока не дописаны
if [ "$MODE" = "tries" ] || [ "$MODE" = "best" ]; then
    echo "Режим '$MODE' (группа $GROUP) пока не реализован" >&2
    exit 3
fi

# dossier ищет по фамилии
if [ "$MODE" = "dossier" ]; then
    if [ $# -lt 3 ]; then
        echo "Ошибка: для режима 'dossier' нужна фамилия. Подсказка: ./lab4.sh help" >&2
        exit 1
    fi
    SURNAME=$3
    echo "Режим 'dossier' (фамилия $SURNAME) пока не реализован" >&2
    exit 3
fi

# attend - группа и интервал
if [ "$MODE" = "attend" ]; then
    if [ $# -lt 5 ]; then
        echo "Ошибка: для режима 'attend' нужны: <группа> <начало> <конец>. Подсказка: ./lab4.sh help" >&2
        exit 1
    fi
    GROUP=$3
    START=$4
    END=$5
    if [ ! -f "$DATA/students/groups/$GROUP" ]; then
        echo "Ошибка: группа не найдена: $GROUP" >&2
        exit 2
    fi
    echo "Режим 'attend' (группа $GROUP, интервал $START-$END) пока не реализован" >&2
    exit 3
fi

echo "Ошибка: неизвестный режим: $MODE. Подсказка: ./lab4.sh help" >&2
exit 1
