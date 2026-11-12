#!/bin/bash
# Автор: soejnekdodks

# Имена каталогов совпадают с названиями двух предметов.
SUBJECTS=("Цирковое_Дело" "Пересдачеведение")

# Аргументы после пути зависят от режима.
usage() {
    echo "ЛР4: обработка данных преподавателя"
    echo "Запуск: ./lab4.sh <режим> <каталог_данных> [параметры]"
    echo "  top <группа>                       лидеры по оценкам 5, 4 и 3"
    echo "  tries <группа> <предмет> <тест>     количество попыток"
    echo "  dossier <начало_ФИО>               досье по началу ФИО"
    echo "  best <предмет>                     лучший результат по годам"
    echo "  attend <группа> <начало> <конец>   посещаемость по парам 1..18"
    echo "  menu                               интерактивное меню"
    echo "Предмет: 1 = ${SUBJECTS[0]}, 2 = ${SUBJECTS[1]} или полное название"
}

# Диагностика уходит в stderr, код получает вызывающая программа.
error() {
    echo "Ошибка: $1" >&2
    exit "$2"
}

# Номер группы должен обозначать один файл внутри students/groups.
check_group() {
    local position=0  # Позиция внутри номера группы.
    local symbol
    while [ "$position" -lt "${#GROUP}" ]; do
        # Берём по одному символу, чтобы исключить вложенный путь.
        symbol=${GROUP:position:1}
        if [ "$symbol" == "/" ]; then
            error "неверный номер группы" 1
        fi
        position=$((position+1))  # Следующий символ.
    done
    if [ ! -f "$DATA/students/groups/$GROUP" ]; then
        error "группа не найдена: $GROUP" 2
    fi
}

# top и best выдают сводный результат только для полного набора данных.
check_tests() {
    local subject number path
    for subject in ${SUBJECTS[*]}; do
        for number in 1 2 3 4; do
            # Для каждого предмета проверяем TEST-1, TEST-2, TEST-3 и TEST-4.
            path="$DATA/$subject/tests/TEST-$number"
            if [ ! -f "$path" ] || [ ! -r "$path" ]; then
                error "нужен доступный файл теста: $path" 2
            fi
        done
    done
}

# Оба способа ввода возвращают одно имя каталога.
subject_name() {
    if [ "$1" == "1" ] || [ "$1" == "${SUBJECTS[0]}" ]; then
        echo "${SUBJECTS[0]}"
    elif [ "$1" == "2" ] || [ "$1" == "${SUBJECTS[1]}" ]; then
        echo "${SUBJECTS[1]}"
    else
        error "неизвестный предмет: $1 (выберите 1 или 2)" 1
    fi
}

# Индекс студента совпадает с его позицией в файле группы.
load_group() {
    NAMES=()  # ФИО в порядке списка группы.
    NAME_COUNT=0  # Число заполненных элементов.
    # Обрабатываем и последнюю строку без перевода строки.
    while IFS= read -r name || [ -n "$name" ]; do
        if [ -n "$name" ]; then
            # Добавляем имя в конец списка, сохраняя порядок файла.
            NAMES[$NAME_COUNT]=$name
            NAME_COUNT=$((NAME_COUNT+1))
        fi
    done < "$DATA/students/groups/$GROUP"
}

# Возвращаем позицию через INDEX. Значение -1 означает отсутствие в группе.
find_name() {
    local lookup_i=0
    INDEX=-1
    while [ "$lookup_i" -lt "$NAME_COUNT" ]; do
        if [ "${NAMES[$lookup_i]}" == "$1" ]; then
            INDEX=$lookup_i  # Найденный индекс используется всеми счётчиками.
            return
        fi
        lookup_i=$((lookup_i+1))
    done
}

# Индексы сортируем отдельно, чтобы счётчики оставались привязаны к ФИО.
sort_counts() {
    local end pos next left right
    end=$((NAME_COUNT-1))  # Правая граница первого прохода.
    while [ "$end" -gt 0 ]; do
        pos=0
        while [ "$pos" -lt "$end" ]; do
            next=$((pos+1))
            left=${ORDER[$pos]}  # Индекс первого студента пары.
            right=${ORDER[$next]}  # Индекс его соседа.
            # Соседей с одинаковым результатом оставляем в порядке списка группы.
            if [ "${COUNTS[$right]}" -gt "${COUNTS[$left]}" ]; then
                ORDER[$pos]=$right
                ORDER[$next]=$left
            fi
            pos=$next
        done
        # Последний элемент прохода уже стоит на своём месте.
        end=$((end-1))
    done
}

# Лидер по каждой из трёх оценок, по обоим предметам сразу.
run_top() {
    check_group
    check_tests
    load_group
    # C хранит число оценок, D хранит список соответствующих тестов.
    C5=()
    C4=()
    C3=()
    D5=()
    D4=()
    D3=()
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        C5[$i]=0  # У студента пока нет учтённых оценок.
        C4[$i]=0
        C3[$i]=0
        D5[$i]=""  # Список источников тоже пуст.
        D4[$i]=""
        D3[$i]=""
        i=$((i+1))
    done
    for subject in ${SUBJECTS[*]}; do
        for test in 1 2 3 4; do
            test_file="$DATA/$subject/tests/TEST-$test"
            # Точка с запятой разделяет пять полей одной попытки.
            while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
                if [ "$row_group" == "$GROUP" ]; then
                    # Одинаковое ФИО может встречаться в двух группах.
                    find_name "$row_name"
                    if [ "$INDEX" -ge 0 ]; then
                        # Берём первую цифру оценки. Например, 5++ учитывается как 5.
                        grade=${row_grade:0:1}
                        if [ "$grade" == "5" ]; then  # Каждая попытка попадает в один счётчик.
                            C5[$INDEX]=$((C5[INDEX]+1))
                            D5[$INDEX]="${D5[$INDEX]} $subject/TEST-$test"  # Один тест может встретиться несколько раз.
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
        done
    done
    echo "Группа $GROUP: лидеры по всем предметам и тестам"
    # Для каждой оценки ищем свой максимум. При равенстве остаётся первый.
    for grade in 5 4 3; do
        max=0
        winner=-1  # Пока ни у кого нет нужной оценки.
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
                winner=$i  # Запоминаем студента вместе с максимумом.
            fi
            i=$((i+1))
        done
        # Значение -1 сохраняется, если у группы нет такой оценки.
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

# В выбранном тесте каждая строка группы считается попыткой.
run_tries() {
    check_group
    SUBJECT=$(subject_name "$SUBJECT") || exit 1
    # Допускаются только четыре номера из набора данных.
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
    if [ ! -f "$test_file" ] || [ ! -r "$test_file" ]; then
        error "файл теста не найден" 2
    fi
    load_group
    # Начинаем с нуля, чтобы в отчёт попали студенты без попыток.
    COUNTS=()
    ORDER=()
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        COUNTS[$i]=0
        ORDER[$i]=$i  # Начальный порядок берём из файла группы.
        i=$((i+1))
    done
    while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
        if [ "$row_group" == "$GROUP" ]; then
            find_name "$row_name"
            if [ "$INDEX" -ge 0 ]; then
                COUNTS[$INDEX]=$((COUNTS[INDEX]+1))  # Включая неудачную попытку.
            fi
        fi
    done < "$test_file"
    # Меняем порядок вывода только после подсчёта всех строк.
    sort_counts
    echo "Группа $GROUP, $SUBJECT, TEST-$TEST: все попытки"
    i=0
    while [ "$i" -lt "$NAME_COUNT" ]; do
        person=${ORDER[$i]}  # Позиция в отчёте указывает на исходное ФИО.
        echo "${NAMES[$person]}: ${COUNTS[$person]}"
        i=$((i+1))
    done
}

# Запись досье занимает три строки: разделитель, ФИО и заметка.
run_dossier() {
    if [ -z "$PREFIX" ]; then
        error "укажите начало ФИО" 1
    fi
    if [ ! -d "$DATA/students/general/notes" ]; then
        error "заметки не найдены" 2
    fi
    found=0  # Станет 1 после первого совпадения.
    for note_file in "$DATA/students/general/notes"/*.log; do
        if [ -f "$note_file" ]; then
            # 0: разделитель, 1: имя, 2: показать заметку, 3: пропустить.
            state=0
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$state" -eq 0 ]; then
                    if [ "${line:0:1}" == "=" ]; then
                        state=1
                    fi
                elif [ "$state" -eq 1 ]; then
                    # Сравниваем столько символов, сколько ввёл пользователь.
                    if [ "${line:0:${#PREFIX}}" == "$PREFIX" ]; then
                        echo "$line"
                        state=2  # Следующая строка содержит нужную заметку.
                        found=1
                    else
                        state=3  # Пропускаем заметку другого студента.
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

# Для каждого года сравниваем суммы правильных ответов по всем группам.
run_best() {
    SUBJECT=$(subject_name "$SUBJECT") || exit 1
    check_tests
    # Одна позиция массивов соответствует студенту своей группы в одном году.
    YEAR_COUNT=0
    YEARS=()  # Год каждой записи.
    PEOPLE=()  # ФИО студента.
    STUDENT_GROUPS=()  # Группа студента.
    TOTALS=()  # Сумма по всем четырём тестам.
    T1=()  # T1–T4 хранят слагаемые этой суммы.
    T2=()
    T3=()
    T4=()
    for test in 1 2 3 4; do
        test_file="$DATA/$SUBJECT/tests/TEST-$test"
        while IFS=';' read -r row_group row_name row_date row_correct row_grade || [ -n "$row_group" ]; do
            grade=${row_grade:0:1}
            # В сумму входят только успешные попытки с оценками 3–5.
            if [ "$grade" == "3" ] || [ "$grade" == "4" ] || [ "$grade" == "5" ]; then
                year=${row_date:0:4}
                # ФИО вместе с группой отличает студентов с одинаковыми именами.
                pos=-1
                i=0
                while [ "$i" -lt "$YEAR_COUNT" ]; do
                    if [ "${YEARS[$i]}" == "$year" ] && [ "${STUDENT_GROUPS[$i]}" == "$row_group" ] && [ "${PEOPLE[$i]}" == "$row_name" ]; then
                        pos=$i
                    fi
                    i=$((i+1))
                done
                if [ "$pos" -lt 0 ]; then
                    pos=$YEAR_COUNT
                    YEAR_COUNT=$((YEAR_COUNT+1))
                    YEARS[$pos]=$year
                    STUDENT_GROUPS[$pos]=$row_group
                    PEOPLE[$pos]=$row_name
                    TOTALS[$pos]=0
                    T1[$pos]=0
                    T2[$pos]=0
                    T3[$pos]=0
                    T4[$pos]=0
                fi
                # Сохраняем общую сумму и вклад каждого теста.
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
        done < "$test_file"
    done
    echo "$SUBJECT: сумма правильных ответов успешных попыток"
    i=0
    while [ "$i" -lt "$YEAR_COUNT" ]; do
        year=${YEARS[$i]}
        # Печатаем год при первом появлении в массиве результатов.
        already=0
        j=0
        while [ "$j" -lt "$i" ]; do
            if [ "${YEARS[$j]}" == "$year" ]; then
                already=1
            fi
            j=$((j+1))
        done
        # Сравниваем суммы только между студентами одного года.
        if [ "$already" -eq 0 ]; then
            winner=$i
            max=${TOTALS[$i]}
            j=$((i+1))
            while [ "$j" -lt "$YEAR_COUNT" ]; do
                if [ "${YEARS[$j]}" == "$year" ] && [ "${TOTALS[$j]}" -gt "$max" ]; then
                    winner=$j  # Меняем лидера только при большем результате.
                    max=${TOTALS[$j]}
                fi
                j=$((j+1))
            done
            echo "$year: ${PEOPLE[$winner]} (${STUDENT_GROUPS[$winner]}) — $max"
            echo "  По тестам: TEST-1=${T1[$winner]}, TEST-2=${T2[$winner]}, TEST-3=${T3[$winner]}, TEST-4=${T4[$winner]}"
        fi
        i=$((i+1))
    done
    if [ "$YEAR_COUNT" -eq 0 ]; then
        echo "Успешных попыток нет"
    fi
}

# Обе границы интервала включены. Для каждого предмета свой файл.
run_attend() {
    check_group
    start_valid=0  # Проверяем границы до арифметики.
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
        file="$DATA/$subject/$GROUP-attendance"  # Для группы свой файл по каждому предмету.
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
        # После ФИО в строке стоят 18 отметок посещения по порядку.
        while IFS=' ' read -r name visits || [ -n "$name" ]; do
            find_name "$name"
            if [ "$INDEX" -ge 0 ]; then
                pair=$START
                while [ "$pair" -le "$END" ]; do
                    # Первая пара записана в строке по индексу 0.
                    position=$((pair-1))
                    char=${visits:position:1}  # Одна отметка на одну пару.
                    if [ "$char" == "1" ]; then
                        COUNTS[$INDEX]=$((COUNTS[INDEX]+1))
                    fi
                    pair=$((pair+1))
                done
            fi
        done < "$file"
        sort_counts
        echo "$subject, группа $GROUP, пары $START..$END:"
        # Даже интервал с одинаковыми границами содержит одну пару.
        length=$((END-START+1))
        i=0
        while [ "$i" -lt "$NAME_COUNT" ]; do
            person=${ORDER[$i]}
            # Целочисленное деление отбрасывает дробную часть процента.
            percent=$((100*COUNTS[person]/length))
            echo "  ${NAMES[$person]}: ${COUNTS[$person]}/$length ($percent%)"
            i=$((i+1))
        done
    done
}

# Справка доступна до проверки пути к данным.
if [ $# -lt 1 ]; then
    usage
    exit 1
fi
MODE=$1  # Первый аргумент выбирает команду.
if [ "$MODE" == "help" ] || [ "$MODE" == "-h" ] || [ "$MODE" == "--help" ]; then
    usage
    exit 0
fi
if [ $# -lt 2 ]; then
    error "не указан каталог данных" 1
fi
DATA=$2  # Путь может содержать пробелы.
if [ ! -d "$DATA" ]; then
    error "каталог данных не найден: $DATA" 2
fi
for subject in ${SUBJECTS[*]}; do
    if [ ! -d "$DATA/$subject" ]; then
        error "нет предмета: $subject" 2
    fi
done

# Один запрос из меню. Ошибка возвращает пользователя к списку функций.
menu_request() {
    local subject_choice problem
    if [ "$choice" == "3" ]; then
        read -r -p "Начало ФИО: " PREFIX || exit 0
        bash "$0" dossier "$DATA" "$PREFIX"
        return
    fi

    if [ "$choice" != "4" ]; then
        read -r -p "Группа: " GROUP || exit 0
        # Проверяем группу до запроса предмета или границ интервала.
        if ! problem=$(check_group 2>&1); then
            echo "$problem" >&2
            return
        fi
    fi
    if [ "$choice" == "2" ] || [ "$choice" == "4" ]; then
        echo "1) ${SUBJECTS[0]}   2) ${SUBJECTS[1]}"
        read -r -p "Предмет: " subject_choice || exit 0
        SUBJECT=$(subject_name "$subject_choice") || return
    fi

    # Тот же командный режим обрабатывает и ввод из меню.
    if [ "$choice" == "1" ]; then
        bash "$0" top "$DATA" "$GROUP"
    elif [ "$choice" == "2" ]; then
        read -r -p "Тест (1..4): " TEST || exit 0
        bash "$0" tries "$DATA" "$GROUP" "$SUBJECT" "$TEST"
    elif [ "$choice" == "4" ]; then
        bash "$0" best "$DATA" "$SUBJECT"
    else
        read -r -p "Начальная пара: " START || exit 0
        read -r -p "Конечная пара: " END || exit 0
        bash "$0" attend "$DATA" "$GROUP" "$START" "$END"
    fi
}

if [ "$MODE" == "menu" ]; then
    if [ $# -ne 2 ]; then error "для menu нужен только каталог данных" 1; fi
    while true; do
        echo "Режимы: 1) top 2) tries 3) dossier 4) best 5) attend 0) выход"
        read -r -p "Выберите режим: " choice || exit 0
        if [ "$choice" == "0" ]; then
            exit 0
        elif [ "$choice" == "1" ] || [ "$choice" == "2" ] || [ "$choice" == "3" ] || [ "$choice" == "4" ] || [ "$choice" == "5" ]; then
            menu_request
        else
            echo "Неизвестный пункт"
        fi
    done
fi

# Аргументы каждой команды проверяем до запуска расчёта.
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
    if [ $# -ne 3 ]; then error "для best нужен предмет" 1; fi
    SUBJECT=$3
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
