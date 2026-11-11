#!/bin/bash
# Автор: soejnekdodks

SUBJECTS=("Цирковое_Дело" "Пересдачеведение")

usage() {
    echo "ЛР4: обработка данных преподавателя"
    echo "Запуск: ./lab4.sh <режим> <каталог_данных> [параметры]"
    echo "  top <группа>                       лидеры по оценкам 5, 4 и 3"
    echo "  tries <группа> <предмет> <тест>     количество попыток"
    echo "  dossier <начало_ФИО>               досье по началу ФИО"
    echo "  best <группа> <предмет>            лучший результат по годам"
    echo "  attend <группа> <начало> <конец>   посещаемость по парам 1..18"
    echo "  menu                               интерактивное меню"
}

error() {
    echo "Ошибка: $1" >&2
    exit "$2"
}

check_group() {
    local position=0
    local symbol
    while [ "$position" -lt "${#GROUP}" ]; do
        symbol=${GROUP:position:1}
        if [ "$symbol" == "/" ]; then
            error "неверный номер группы" 1
        fi
        position=$((position+1))
    done
    if [ ! -f "$DATA/students/groups/$GROUP" ]; then
        error "группа не найдена: $GROUP" 2
    fi
}

check_subject() {
    if [ "$SUBJECT" != "Цирковое_Дело" ] && [ "$SUBJECT" != "Пересдачеведение" ]; then
        error "неизвестный предмет: $SUBJECT" 1
    fi
}

load_group() {
    NAMES=()
    NAME_COUNT=0
    while IFS= read -r name || [ -n "$name" ]; do
        if [ -n "$name" ]; then
            NAMES[$NAME_COUNT]=$name
            NAME_COUNT=$((NAME_COUNT+1))
        fi
    done < "$DATA/students/groups/$GROUP"
}

find_name() {
    local lookup_i=0
    INDEX=-1
    while [ "$lookup_i" -lt "$NAME_COUNT" ]; do
        if [ "${NAMES[$lookup_i]}" == "$1" ]; then
            INDEX=$lookup_i
            return
        fi
        lookup_i=$((lookup_i+1))
    done
}

run_top() {
    check_group
    load_group
    C5=()
    C4=()
    C3=()
    D5=()
    D4=()
    D3=()
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        C5[$i]=0
        C4[$i]=0
        C3[$i]=0
        D5[$i]=""
        D4[$i]=""
        D3[$i]=""
        i=$((i+1))
    done
    for subject in ${SUBJECTS[*]}; do
        for test in 1 2 3 4; do
            test_file="$DATA/$subject/tests/TEST-$test"
            if [ -f "$test_file" ]; then
                while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
                    if [ "$row_group" == "$GROUP" ]; then
                        find_name "$row_name"
                        if [ "$INDEX" -ge 0 ]; then
                            grade=${row_grade:0:1}
                            if [ "$grade" == "5" ]; then
                                C5[$INDEX]=$((C5[INDEX]+1))
                                D5[$INDEX]="${D5[$INDEX]} $subject/TEST-$test"
                            elif [ "$grade" == "4" ]; then
                                C4[$INDEX]=$((C4[INDEX]+1))
                                D4[$INDEX]="${D4[$INDEX]} $subject/TEST-$test"
                            elif [ "$grade" == "3" ]; then
                                C3[$INDEX]=$((C3[INDEX]+1))
                                D3[$INDEX]="${D3[$INDEX]} $subject/TEST-$test"
                            fi
                        fi
                    fi
                done < "$test_file"
            fi
        done
    done
    echo "Группа $GROUP: лидеры по всем предметам и тестам"
    for grade in 5 4 3; do
        max=0
        winner=-1
        i=0
        while [ "$i" -lt "$NAME_COUNT" ]; do
            if [ "$grade" == "5" ]; then
                count=${C5[$i]}
            elif [ "$grade" == "4" ]; then
                count=${C4[$i]}
            else
                count=${C3[$i]}
            fi
            if [ "$count" -gt "$max" ]; then
                max=$count
                winner=$i
            fi
            i=$((i+1))
        done
        if [ "$winner" -lt 0 ]; then
            echo "Оценка $grade: записей нет"
        else
            if [ "$grade" == "5" ]; then
                details=${D5[$winner]}
            elif [ "$grade" == "4" ]; then
                details=${D4[$winner]}
            else
                details=${D3[$winner]}
            fi
            echo "Оценка $grade: ${NAMES[$winner]} — $max"
            echo "  Тесты:$details"
        fi
    done
}

run_tries() {
    check_group
    check_subject
    valid=0
    for number in 1 2 3 4; do
        if [ "$TEST" == "$number" ]; then
            valid=1
        fi
    done
    if [ "$valid" -eq 0 ]; then
        error "тест должен быть от 1 до 4" 1
    fi
    test_file="$DATA/$SUBJECT/tests/TEST-$TEST"
    if [ ! -f "$test_file" ]; then
        error "файл теста не найден" 2
    fi
    load_group
    COUNTS=()
    ORDER=()
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        COUNTS[$i]=0
        ORDER[$i]=$i
        i=$((i+1))
    done
    while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
        if [ "$row_group" == "$GROUP" ]; then
            find_name "$row_name"
            if [ "$INDEX" -ge 0 ]; then
                COUNTS[$INDEX]=$((COUNTS[INDEX]+1))
            fi
        fi
    done < "$test_file"
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        j=$((i+1))
        while [ "$j" -lt "$NAME_COUNT" ]; do
            a=${ORDER[$i]}; b=${ORDER[$j]}
            if [ "${COUNTS[$b]}" -gt "${COUNTS[$a]}" ]; then
                ORDER[$i]=$b; ORDER[$j]=$a
            fi
            j=$((j+1))
        done
        i=$((i+1))
    done
    echo "Группа $GROUP, $SUBJECT, TEST-$TEST: все попытки"
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        person=${ORDER[$i]}
        echo "${NAMES[$person]}: ${COUNTS[$person]}"
        i=$((i+1))
    done
}

run_dossier() {
    if [ -z "$PREFIX" ]; then
        error "укажите начало ФИО" 1
    fi
    if [ ! -d "$DATA/students/general/notes" ]; then
        error "заметки не найдены" 2
    fi
    found=0
    for note_file in "$DATA/students/general/notes"/*; do
        if [ -f "$note_file" ]; then
            state=0
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$state" -eq 0 ]; then
                    if [ "${line:0:1}" == "=" ]; then
                        state=1
                    fi
                elif [ "$state" -eq 1 ]; then
                    if [ "${line:0:${#PREFIX}}" == "$PREFIX" ]; then
                        echo "$line"
                        state=2
                        found=1
                    else
                        state=3
                    fi
                elif [ "$state" -eq 2 ]; then
                    echo "$line"
                    state=0
                else
                    state=0
                fi
            done < "$note_file"
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "Досье по началу '$PREFIX' не найдены"
    fi
}

run_best() {
    check_group
    check_subject
    load_group
    YEAR_COUNT=0
    YEARS=()
    PEOPLE=()
    TOTALS=()
    T1=()
    T2=()
    T3=()
    T4=()
    for test in 1 2 3 4; do
        test_file="$DATA/$SUBJECT/tests/TEST-$test"
        if [ -f "$test_file" ]; then
            while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
                if [ "$row_group" == "$GROUP" ]; then
                    grade=${row_grade:0:1}
                    if [ "$grade" == "3" ] || [ "$grade" == "4" ] || [ "$grade" == "5" ]; then
                        find_name "$row_name"
                        if [ "$INDEX" -ge 0 ]; then
                            year=${row_date:0:4}
                            pos=-1; i=0
                            while [ "$i" -lt "$YEAR_COUNT" ]; do
                                if [ "${YEARS[$i]}" == "$year" ] && [ "${PEOPLE[$i]}" -eq "$INDEX" ]; then
                                    pos=$i
                                fi
                                i=$((i+1))
                            done
                            if [ "$pos" -lt 0 ]; then
                                pos=$YEAR_COUNT
                                YEAR_COUNT=$((YEAR_COUNT+1))
                                YEARS[$pos]=$year
                                PEOPLE[$pos]=$INDEX
                                TOTALS[$pos]=0
                                T1[$pos]=0
                                T2[$pos]=0
                                T3[$pos]=0
                                T4[$pos]=0
                            fi
                            TOTALS[$pos]=$((TOTALS[pos]+row_correct))
                            if [ "$test" == "1" ]; then
                                T1[$pos]=$((T1[pos]+row_correct))
                            elif [ "$test" == "2" ]; then
                                T2[$pos]=$((T2[pos]+row_correct))
                            elif [ "$test" == "3" ]; then
                                T3[$pos]=$((T3[pos]+row_correct))
                            else
                                T4[$pos]=$((T4[pos]+row_correct))
                            fi
                        fi
                    fi
                fi
            done < "$test_file"
        fi
    done
    echo "Группа $GROUP, $SUBJECT: сумма правильных ответов успешных попыток"
    i=0
    while [ "$i" -lt "$YEAR_COUNT" ]; do
        year=${YEARS[$i]}
        already=0
        j=0
        while [ "$j" -lt "$i" ]; do
            if [ "${YEARS[$j]}" == "$year" ]; then
                already=1
            fi
            j=$((j+1))
        done
        if [ "$already" -eq 0 ]; then
            winner=$i
            max=${TOTALS[$i]}
            j=$((i+1))
            while [ "$j" -lt "$YEAR_COUNT" ]; do
                if [ "${YEARS[$j]}" == "$year" ] && [ "${TOTALS[$j]}" -gt "$max" ]; then
                    winner=$j; max=${TOTALS[$j]}
                fi
                j=$((j+1))
            done
            person=${PEOPLE[$winner]}
            echo "$year: ${NAMES[$person]} — $max"
            echo "  По тестам: TEST-1=${T1[$winner]}, TEST-2=${T2[$winner]}, TEST-3=${T3[$winner]}, TEST-4=${T4[$winner]}"
        fi
        i=$((i+1))
    done
    if [ "$YEAR_COUNT" -eq 0 ]; then
        echo "Успешных попыток нет"
    fi
}

run_attend() {
    check_group
    start_valid=0
    end_valid=0
    for number in {1..18}; do
        if [ "$START" == "$number" ]; then
            start_valid=1
        fi
        if [ "$END" == "$number" ]; then
            end_valid=1
        fi
    done
    if [ "$start_valid" -eq 0 ] || [ "$end_valid" -eq 0 ]; then
        error "интервал должен быть в пределах 1..18" 1
    fi
    if [ "$START" -gt "$END" ]; then
        error "начало интервала больше конца" 1
    fi
    load_group
    for subject in ${SUBJECTS[*]}; do
        file="$DATA/$subject/$GROUP-attendance"
        if [ ! -f "$file" ]; then
            error "файл посещаемости не найден: $subject/$GROUP" 2
        fi
        COUNTS=()
        ORDER=()
        i=0
        while [ "$i" -lt "$NAME_COUNT" ]; do
            COUNTS[$i]=0
            ORDER[$i]=$i
            i=$((i+1))
        done
        while IFS=' ' read -r name visits || [ -n "$name" ]; do
            find_name "$name"
            if [ "$INDEX" -ge 0 ]; then
                pair=$START
                while [ "$pair" -le "$END" ]; do
                    position=$((pair-1))
                    char=${visits:position:1}
                    if [ "$char" == "1" ]; then
                        COUNTS[$INDEX]=$((COUNTS[INDEX]+1))
                    fi
                    pair=$((pair+1))
                done
            fi
        done < "$file"
        i=0
        while [ "$i" -lt "$NAME_COUNT" ]; do
            j=$((i+1))
            while [ "$j" -lt "$NAME_COUNT" ]; do
                a=${ORDER[$i]}; b=${ORDER[$j]}
                if [ "${COUNTS[$b]}" -gt "${COUNTS[$a]}" ]; then
                    ORDER[$i]=$b
                    ORDER[$j]=$a
                fi
                j=$((j+1))
            done
            i=$((i+1))
        done
        echo "$subject, группа $GROUP, пары $START..$END:"
        length=$((END-START+1))
        i=0
        while [ "$i" -lt "$NAME_COUNT" ]; do
            person=${ORDER[$i]}
            percent=$((100*COUNTS[person]/length))
            echo "  ${NAMES[$person]}: ${COUNTS[$person]}/$length ($percent%)"
            i=$((i+1))
        done
    done
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi
MODE=$1
if [ "$MODE" == "help" ] || [ "$MODE" == "-h" ] || [ "$MODE" == "--help" ]; then
    usage
    exit 0
fi
if [ $# -lt 2 ]; then
    error "не указан каталог данных" 1
fi
DATA=$2
if [ ! -d "$DATA" ]; then
    error "каталог данных не найден: $DATA" 2
fi
for subject in ${SUBJECTS[*]}; do
    if [ ! -d "$DATA/$subject" ]; then
        error "нет предмета: $subject" 2
    fi
done

if [ "$MODE" == "menu" ]; then
    while true; do
        echo "Режимы: 1) top 2) tries 3) dossier 4) best 5) attend 0) выход"
        read -r -p "Выберите режим: " choice || exit 0
        if [ "$choice" == "1" ]; then
            MODE=top; read -r -p "Группа: " GROUP
        elif [ "$choice" == "2" ]; then
            MODE=tries; read -r -p "Группа: " GROUP
            read -r -p "Предмет (Цирковое_Дело/Пересдачеведение): " SUBJECT
            read -r -p "Тест (1..4): " TEST
        elif [ "$choice" == "3" ]; then
            MODE=dossier; read -r -p "Начало ФИО: " PREFIX
        elif [ "$choice" == "4" ]; then
            MODE=best; read -r -p "Группа: " GROUP
            read -r -p "Предмет (Цирковое_Дело/Пересдачеведение): " SUBJECT
        elif [ "$choice" == "5" ]; then
            MODE=attend; read -r -p "Группа: " GROUP
            read -r -p "Начальная пара: " START
            read -r -p "Конечная пара: " END
        elif [ "$choice" == "0" ]; then
            exit 0
        else
            echo "Неизвестный пункт"
        fi
        if [ "$choice" == "1" ]; then run_top; fi
        if [ "$choice" == "2" ]; then run_tries; fi
        if [ "$choice" == "3" ]; then run_dossier; fi
        if [ "$choice" == "4" ]; then run_best; fi
        if [ "$choice" == "5" ]; then run_attend; fi
    done
fi

if [ "$MODE" == "top" ]; then
    if [ $# -ne 3 ]; then error "для top нужна группа" 1; fi
    GROUP=$3
    run_top
elif [ "$MODE" == "tries" ]; then
    if [ $# -ne 5 ]; then error "для tries нужны группа, предмет и тест" 1; fi
    GROUP=$3
    SUBJECT=$4
    TEST=$5
    run_tries
elif [ "$MODE" == "dossier" ]; then
    if [ $# -ne 3 ]; then error "для dossier нужно начало ФИО" 1; fi
    PREFIX=$3
    run_dossier
elif [ "$MODE" == "best" ]; then
    if [ $# -ne 4 ]; then error "для best нужны группа и предмет" 1; fi
    GROUP=$3
    SUBJECT=$4
    run_best
elif [ "$MODE" == "attend" ]; then
    if [ $# -ne 5 ]; then error "для attend нужны группа, начало и конец интервала" 1; fi
    GROUP=$3
    START=$4
    END=$5
    run_attend
else
    error "неизвестный режим: $MODE" 1
fi
