from hashlib import sha3_256

study_group = "211-331"  # Укажите номер учебной группы
fullname = "Скрыпник Василий Александрович"  # Указаны ФИО
# Для ЛР4, как в задании
suffix = "Высоконагруженные системы. Лабораторная работа 4"

string_for_hash = f"{study_group} {fullname} {suffix}"
var_total = 10
variant = int(sha3_256(string_for_hash.encode('utf-8')).hexdigest(), 16) % var_total + 1
print(f"Ваш вариант: {variant}")